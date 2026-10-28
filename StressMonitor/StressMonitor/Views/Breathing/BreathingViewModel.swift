import SwiftUI
import SwiftData

@Observable
@MainActor
class BreathingSessionViewModel {
    nonisolated static let defaultSessionDuration: TimeInterval = 120
    /// One box cycle: four 4-second phases.
    nonisolated static let cycleDuration: TimeInterval = 16

    /// Whole cycles that fit in a session of the given length.
    nonisolated static func cycleCount(forDuration duration: TimeInterval) -> Int {
        max(1, Int(duration / cycleDuration))
    }

    var sessionDuration: TimeInterval = BreathingSessionViewModel.defaultSessionDuration
    var remainingTime: TimeInterval = BreathingSessionViewModel.defaultSessionDuration
    var isActive = false
    var sessionResult: BreathingSessionResult?

    /// Single source of truth for the 4-4-4-4 box-breathing phase.
    var boxPhase: BoxBreathingPhase = .inhale
    /// Seconds remaining in the current 4-second box phase.
    var secondsRemaining: Int = 4
    /// Number of completed cycles (each cycle = 4 phases × 4s = `cycleDuration`).
    var cyclesCompleted: Int = 0
    /// Total cycles planned for the session.
    var totalCycles: Int { Self.cycleCount(forDuration: sessionDuration) }

    /// Whether the animated circle guide runs (D-11). Defaults from the
    /// app-wide motion decision — Reduce Motion on → animated guide off —
    /// and the user may flip it in-session. Nothing persists past the session.
    var isAnimationEnabled = true
    private var userAnimationChoice: Bool?

    // Session config
    var hapticFeedback: Bool = true

    private let healthKit: HealthKitServiceProtocol
    private var timer: Timer?
    private var phaseTickTimer: Timer?
    private var preSessionHRV: Double?
    private var postSessionHRV: Double?

    enum BreathingPhase {
        case inhale
        case hold
        case exhale
    }

    init(healthKit: HealthKitServiceProtocol) {
        self.healthKit = healthKit
    }

    convenience init() {
        self.init(healthKit: HealthKitManager())
    }

    /// Pure D-11 default: with Reduce Motion on the animated guide starts
    /// off unless the user already chose otherwise in-session.
    static func resolvedAnimationEnabled(motionReduced: Bool, userChoice: Bool? = nil) -> Bool {
        userChoice ?? !motionReduced
    }

    /// Captures the app-wide motion decision (delivered by the helper's
    /// `onMotionDecision`) as this session's animation default.
    func configureAnimation(motionReduced: Bool) {
        isAnimationEnabled = Self.resolvedAnimationEnabled(
            motionReduced: motionReduced,
            userChoice: userAnimationChoice
        )
    }

    func setAnimationEnabled(_ enabled: Bool) {
        userAnimationChoice = enabled
        isAnimationEnabled = enabled
    }

    func startSession() {
        isActive = true
        remainingTime = sessionDuration
        boxPhase = .inhale
        secondsRemaining = BoxBreathingPhase.inhale.durationSeconds
        cyclesCompleted = 0

        Task {
            if let hrv = try? await healthKit.fetchLatestHRV() {
                preSessionHRV = hrv.value
            }
        }

        startBoxPhaseTicks()
        startCountdown()
    }

    func endSession() {
        isActive = false
        timer?.invalidate()
        phaseTickTimer?.invalidate()
        phaseTickTimer = nil

        Task {
            if let hrv = try? await healthKit.fetchLatestHRV() {
                postSessionHRV = hrv.value
            }

            sessionResult = BreathingSessionResult(
                preSessionHRV: preSessionHRV,
                postSessionHRV: postSessionHRV,
                duration: sessionDuration - remainingTime,
                cyclesCompleted: cyclesCompleted
            )
        }
    }

    /// Steps the 4-4-4-4 box-breathing phase every second, advancing through
    /// inhale → holdIn → exhale → holdOut → inhale.
    private func startBoxPhaseTicks() {
        guard isActive else { return }
        phaseTickTimer?.invalidate()
        phaseTickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isActive else { return }
                if self.secondsRemaining > 1 {
                    self.secondsRemaining -= 1
                } else {
                    self.advanceBoxPhase()
                }
            }
        }
    }

    private func advanceBoxPhase() {
        // Count a completed cycle when we wrap from holdOut back to inhale
        if boxPhase == .holdOut {
            cyclesCompleted += 1
        }
        switch boxPhase {
        case .inhale:  boxPhase = .holdIn
        case .holdIn:  boxPhase = .exhale
        case .exhale:  boxPhase = .holdOut
        case .holdOut: boxPhase = .inhale
        }
        secondsRemaining = boxPhase.durationSeconds
        pulsePhaseTransition()
    }

    /// D-11 fallback channel: a haptic pulse at every phase transition keeps
    /// the session operable without the animated guide.
    private func pulsePhaseTransition() {
        guard hapticFeedback else { return }
        HapticManager.shared.breathingCue()
    }

    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.remainingTime <= 0 { return }

                self.remainingTime -= 1

                if self.remainingTime <= 0 {
                    self.endSession()
                    NotificationCenter.default.post(name: .breathingSessionComplete, object: self.sessionResult)
                }
            }
        }
    }

    /// Skips the current cycle by fast-forwarding remaining time to the next cycle boundary.
    func skipCycle() {
        guard isActive else { return }
        let phaseIndex: Int
        switch boxPhase {
        case .inhale:  phaseIndex = 0
        case .holdIn:  phaseIndex = 1
        case .exhale:  phaseIndex = 2
        case .holdOut: phaseIndex = 3
        }
        let phasesIntoCycle = phaseIndex + 1
        let totalPhasesElapsed = cyclesCompleted * 4 + phasesIntoCycle
        let phasesToSkip = 4 - phaseIndex
        let secondsToSkip = phasesToSkip * 4 + (secondsRemaining - 1)

        // Advance through remaining phases in this cycle
        for _ in 0..<phasesToSkip {
            advanceBoxPhase()
        }

        // Reduce remaining time accordingly
        remainingTime = max(0, remainingTime - Double(secondsToSkip))

        if remainingTime <= 0 {
            endSession()
            NotificationCenter.default.post(name: .breathingSessionComplete, object: sessionResult)
        }
    }
}

struct BreathingSessionResult: Hashable, Codable {
    /// `nil` when HealthKit had no HRV sample for that side of the session.
    let preSessionHRV: Double?
    let postSessionHRV: Double?
    let duration: TimeInterval
    let cyclesCompleted: Int

    var improvement: Double? {
        guard let preSessionHRV, let postSessionHRV else { return nil }
        return postSessionHRV - preSessionHRV
    }

    var percentageImprovement: Double? {
        guard let improvement, let preSessionHRV, preSessionHRV > 0 else { return nil }
        return (improvement / preSessionHRV) * 100
    }
}

extension Notification.Name {
    static let breathingSessionComplete = Notification.Name("breathingSessionComplete")
}
