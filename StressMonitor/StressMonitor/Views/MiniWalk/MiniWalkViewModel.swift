import Foundation
import SwiftUI
import CoreMotion
import HealthKit

@Observable
@MainActor
final class MiniWalkViewModel {

    // MARK: - State

    var remainingSeconds: Int
    var isRunning = false
    var isFinished = false
    var isPaused = false

    // Walk stats (live)
    var stepCount: Int = 0
    var heartRateBPM: Int = 0
    var caloriesBurned: Double = 0
    var hasBPM: Bool = false

    // Completion state
    var showComplete: Bool = false

    // MARK: - Config

    nonisolated static let defaultDurationSeconds = 600
    private nonisolated static let targetStepsPerMinute = 100

    /// Step goal for a walk of the given length (a steady ~100 steps per minute).
    nonisolated static func targetSteps(forDurationSeconds seconds: Int) -> Int {
        seconds / 60 * targetStepsPerMinute
    }

    var durationSeconds: Int = MiniWalkViewModel.defaultDurationSeconds

    var targetSteps: Int {
        Self.targetSteps(forDurationSeconds: durationSeconds)
    }

    // MARK: - Computed

    var progress: Double {
        guard durationSeconds > 0 else { return 0 }
        return 1.0 - Double(remainingSeconds) / Double(durationSeconds)
    }

    var timeDisplay: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Total elapsed time in seconds.
    var elapsedSeconds: Int {
        durationSeconds - remainingSeconds
    }

    /// Elapsed minutes (for completion screen).
    var elapsedMinutes: Int {
        max(1, elapsedSeconds / 60)
    }

    /// Formatted step count with thousands separator.
    var stepDisplay: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: stepCount)) ?? "\(stepCount)"
    }

    /// Formatted BPM or dash if unavailable.
    var bpmDisplay: String {
        hasBPM ? "\(heartRateBPM)" : "—"
    }

    /// Formatted calories (a step-based estimate, not a measurement).
    var calorieDisplay: String {
        if caloriesBurned >= 100 {
            return String(format: "%.0f", caloriesBurned)
        }
        return String(format: "%.1f", caloriesBurned)
    }

    // MARK: - Private

    private var timer: Timer?
    private let pedometer = CMPedometer()
    private var walkStartDate: Date?

    init(durationSeconds: Int = MiniWalkViewModel.defaultDurationSeconds) {
        self.durationSeconds = durationSeconds
        self.remainingSeconds = durationSeconds
    }

    // MARK: - Actions

    func start() {
        guard !isRunning else { return }

        if isPaused {
            // Resume from pause
            isPaused = false
            isRunning = true
            startTimer()
            return
        }

        // Fresh start
        isRunning = true
        isFinished = false
        walkStartDate = Date()
        stepCount = 0
        caloriesBurned = 0
        heartRateBPM = 0
        hasBPM = false

        startTimer()
        startPedometer()
        fetchHeartRate()
    }

    func pause() {
        guard isRunning else { return }
        isPaused = true
        isRunning = false
        timer?.invalidate()
        timer = nil
        pedometer.stopUpdates()
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        pedometer.stopUpdates()
        isRunning = false
        isFinished = false
        isPaused = false
        remainingSeconds = durationSeconds
        stepCount = 0
        heartRateBPM = 0
        caloriesBurned = 0
        hasBPM = false
        walkStartDate = nil
    }

    func cleanup() {
        timer?.invalidate()
        timer = nil
        pedometer.stopUpdates()
    }

    /// Called when the walk completes — shows the completion screen.
    func complete() {
        showComplete = true
        HapticManager.shared.success()
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.remainingSeconds -= 1

                if self.remainingSeconds <= 0 {
                    self.remainingSeconds = 0
                    self.isRunning = false
                    self.isFinished = true
                    self.timer?.invalidate()
                    self.timer = nil
                    self.pedometer.stopUpdates()
                    self.complete()
                }

                // Update calories estimate based on elapsed time + steps.
                // Rough: ~0.04 kcal per step.
                self.caloriesBurned = Double(self.stepCount) * 0.04
            }
        }
    }

    // MARK: - Pedometer (live steps)

    private func startPedometer() {
        guard CMPedometer.isStepCountingAvailable(),
              let startDate = walkStartDate else { return }

        pedometer.startUpdates(from: startDate) { [weak self] data, _ in
            guard let data, let self else { return }
            Task { @MainActor in
                self.stepCount = data.numberOfSteps.intValue
            }
        }
    }

    // MARK: - Heart Rate (HealthKit)

    private func fetchHeartRate() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        Task { @MainActor in
            do {
                let manager = HealthKitManager()
                try await manager.requestAuthorization()
                let samples = try await manager.fetchHeartRate(samples: 1)
                if let latest = samples.first {
                    self.heartRateBPM = Int(latest.value)
                    self.hasBPM = true
                }
            } catch {
                // HealthKit unavailable or no data — stats row shows "—"
                self.hasBPM = false
            }
        }
    }
}
