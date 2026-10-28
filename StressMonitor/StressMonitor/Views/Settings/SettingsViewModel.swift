import SwiftUI
import SwiftData

@MainActor
@Observable
final class SettingsViewModel {
    var userProfile: UserProfile
    var notificationSettings: NotificationSettings
    var exportSettings: ExportSettings
    var isDeletingAllData = false
    var latestStressLevel: Double?
    var bioAge: Int? = nil
    var streakDays: Int = 0
    private(set) var chatStressResult: StressResult?
    private(set) var chatBaseline: PersonalBaseline?
    /// Oldest first, as `ChatContextBuilder` expects for trend analysis.
    private(set) var chatHistory: [StressMeasurement] = []

    private let repository: StressRepositoryProtocol
    private let healthKit: HealthKitServiceProtocol
    private let bioAgeCalculator = BioAgeCalculator()

    private static let chatContextFreshness: TimeInterval = 24 * 60 * 60

    init(
        modelContext: ModelContext,
        baselineCalculator: BaselineCalculator? = nil,
        healthKit: HealthKitServiceProtocol? = nil
    ) {
        self.repository = StressRepository(modelContext: modelContext, baselineCalculator: baselineCalculator)
        self.healthKit = healthKit ?? HealthKitManager()
        self.userProfile = UserProfile(name: UserDefaults.standard.string(forKey: "profile.name") ?? "",
                                        age: nil,
                                        restingHeartRate: 60,
                                        baselineHRV: 50)
        self.notificationSettings = NotificationSettings.load()
        self.exportSettings = ExportSettings()
    }

    func loadUserProfile() async {
        let baseline = try? await repository.getBaseline()
        if let baseline {
            userProfile = UserProfile(
                name: userProfile.name,
                age: userProfile.age,
                restingHeartRate: baseline.restingHeartRate,
                baselineHRV: baseline.baselineHRV
            )
        }

        let calendar = Calendar.current
        let now = Date()
        let lookbackStart = calendar.date(byAdding: .day, value: -MeasurementStreak.lookbackDays, to: now) ?? now
        // Newest first.
        let measurements = (try? await repository.fetchMeasurements(from: lookbackStart, to: now)) ?? []

        latestStressLevel = measurements.first?.stressLevel
        streakDays = MeasurementStreak.days(from: measurements.map(\.timestamp))

        let windowStart = calendar.date(byAdding: .day, value: -BioAgeCalculator.minimumDataDays, to: now) ?? now
        let window = measurements.filter { $0.timestamp >= windowStart }
        userProfile.age = healthKit.chronologicalAge()
        bioAge = computeBioAge(window: window)

        updateChatContext(measurements: measurements, window: window, baseline: baseline, now: now)

        notificationSettings.persist()
    }

    var displayName: String {
        let raw = userProfile.name.trimmingCharacters(in: .whitespaces)
        return raw.isEmpty ? "You" : raw
    }

    var displayEmail: String? {
        let raw = userProfile.name.trimmingCharacters(in: .whitespaces)
        return raw.isEmpty ? nil : UserDefaults.standard.string(forKey: "profile.email")
    }

    func updateProfile(_ profile: UserProfile) async throws {
        let baseline = PersonalBaseline(
            restingHeartRate: profile.restingHeartRate,
            baselineHRV: profile.baselineHRV,
            lastUpdated: Date()
        )
        try await repository.updateBaseline(baseline)
        userProfile = profile
        UserDefaults.standard.set(profile.name, forKey: "profile.name")
    }

    func deleteAllMeasurements() async throws {
        isDeletingAllData = true
        defer { isDeletingAllData = false }
        try await repository.deleteAllMeasurements()
    }

    private func computeBioAge(window: [StressMeasurement]) -> Int? {
        guard let chronologicalAge = userProfile.age,
              bioAgeCalculator.hasEnoughData(measurements: window) else { return nil }
        return bioAgeCalculator.calculate(
            chronologicalAge: chronologicalAge,
            hrv: Self.average(of: window.map(\.hrv)),
            restingHeartRate: Self.average(of: window.map(\.restingHeartRate)),
            sleepEfficiency: nil
        )?.estimatedAge
    }

    /// Only a recent reading is offered as "current" chat context, and the
    /// baseline only once real readings exist (an empty store yields defaults).
    private func updateChatContext(
        measurements: [StressMeasurement],
        window: [StressMeasurement],
        baseline: PersonalBaseline?,
        now: Date
    ) {
        if let latest = measurements.first, now.timeIntervalSince(latest.timestamp) <= Self.chatContextFreshness {
            chatStressResult = latest.stressResult
        } else {
            chatStressResult = nil
        }
        chatBaseline = measurements.isEmpty ? nil : baseline
        chatHistory = Array(window.reversed())
    }

    private static func average(of values: [Double]) -> Double? {
        let present = values.filter { $0 > 0 }
        guard !present.isEmpty else { return nil }
        return present.reduce(0, +) / Double(present.count)
    }
}

struct UserProfile: Codable {
    var name: String
    var age: Int?
    var restingHeartRate: Double
    var baselineHRV: Double
}

struct NotificationSettings: Codable {
    var stressAlertsEnabled: Bool = true
    var waterReminderEnabled: Bool = true
    var dailySummaryEnabled: Bool = false

    private static let storageKey = "settings.notifications"

    static func load() -> NotificationSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(NotificationSettings.self, from: data) else {
            return NotificationSettings()
        }
        return decoded
    }

    func persist() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

struct ExportSettings: Codable {
    var includeHRV: Bool = true
    var includeHeartRate: Bool = true
    var includeStressLevel: Bool = true
    var dateRange: ExportDateRange = .week
    var format: ExportFormat = .csv
}

enum ExportDateRange: String, CaseIterable, Codable {
    case day = "Last 24 Hours"
    case week = "Last 7 Days"
    case month = "Last 4 Weeks"
    case threeMonths = "Last 3 Months"
    case all = "All Time"
    case custom = "Custom"
}

enum ExportFormat: String, CaseIterable, Codable {
    case csv = "CSV"
    case json = "JSON"
}
