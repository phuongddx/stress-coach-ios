import Foundation

/// Manages data access for widgets using App Groups UserDefaults
/// This allows sharing data between the main app and widget extension
@available(iOS 17.0, *)
public final class WidgetDataProvider {

    // MARK: - Constants

    static let appGroupID = "group.stress.ai.com"

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let latestStressLevel = "latest_stress_level"
        static let latestStressCategory = "latest_stress_category"
        static let latestHRV = "latest_hrv"
        static let latestHeartRate = "latest_heart_rate"
        static let latestTimestamp = "latest_timestamp"
        static let latestConfidence = "latest_confidence"
        static let historyData = "stress_history_data"
        static let personalBaseline = "personal_baseline"

        static var allCases: [String] {
            [
                latestStressLevel,
                latestStressCategory,
                latestHRV,
                latestHeartRate,
                latestTimestamp,
                latestConfidence,
                historyData,
                personalBaseline
            ]
        }
    }

    // MARK: - Shared Instance

    public static let shared = WidgetDataProvider()

    private let userDefaults: UserDefaults

    private init() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID) else {
            fatalError("Unable to create UserDefaults with app group: \(Self.appGroupID)")
        }
        self.userDefaults = defaults
    }

    // MARK: - Latest Stress Data

    /// Saves the latest stress measurement for widget access
    public func saveLatestStress(level: Double, category: String, hrv: Double, heartRate: Double, confidence: Double, timestamp: Date) {
        userDefaults.set(level, forKey: Keys.latestStressLevel)
        userDefaults.set(category, forKey: Keys.latestStressCategory)
        userDefaults.set(hrv, forKey: Keys.latestHRV)
        userDefaults.set(heartRate, forKey: Keys.latestHeartRate)
        userDefaults.set(confidence, forKey: Keys.latestConfidence)
        userDefaults.set(timestamp.timeIntervalSince1970, forKey: Keys.latestTimestamp)
        userDefaults.synchronize()
    }

    /// Retrieves the latest stress measurement
    public func getLatestStress() -> StressData? {
        guard let timestampInterval = userDefaults.object(forKey: Keys.latestTimestamp) as? TimeInterval else {
            return nil
        }

        let timestamp = Date(timeIntervalSince1970: timestampInterval)
        let level = userDefaults.double(forKey: Keys.latestStressLevel)
        let category = userDefaults.string(forKey: Keys.latestStressCategory) ?? "mild"
        let hrv = userDefaults.double(forKey: Keys.latestHRV)
        let heartRate = userDefaults.double(forKey: Keys.latestHeartRate)
        let confidence = userDefaults.double(forKey: Keys.latestConfidence)

        // Validate we have actual data (level defaults to 0 if not set)
        if level == 0 && hrv == 0 && heartRate == 0 {
            return nil
        }

        return StressData(
            level: level,
            category: category,
            hrv: hrv,
            heartRate: heartRate,
            confidence: confidence,
            timestamp: timestamp
        )
    }

    // MARK: - History Data

    /// Saves stress history for the widget timeline
    public func saveHistory(_ history: [StressData]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(history)
            userDefaults.set(data, forKey: Keys.historyData)
            userDefaults.synchronize()
        } catch {
            print("Failed to encode history: \(error)")
        }
    }

    /// Retrieves stress history for widget display
    public func getHistory(limit: Int = 20) -> [StressData] {
        guard let data = userDefaults.data(forKey: Keys.historyData) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let history = try decoder.decode([StressData].self, from: data)
            return Array(history.prefix(limit))
        } catch {
            print("Failed to decode history: \(error)")
            return []
        }
    }

    // MARK: - Personal Baseline

    /// Saves the user's personal baseline values
    public func saveBaseline(hrv: Double, restingHeartRate: Double) {
        userDefaults.set(hrv, forKey: "baseline_hrv")
        userDefaults.set(restingHeartRate, forKey: "baseline_hr")
        userDefaults.synchronize()
    }

    /// Retrieves the user's personal baseline
    public func getBaseline() -> (hrv: Double, restingHeartRate: Double)? {
        let hrv = userDefaults.double(forKey: "baseline_hrv")
        let hr = userDefaults.double(forKey: "baseline_hr")

        if hrv > 0 && hr > 0 {
            return (hrv: hrv, restingHeartRate: hr)
        }
        return nil
    }

    // MARK: - Clear Data

    /// Clears all widget data
    public func clearAllData() {
        Keys.allCases.forEach { key in
            userDefaults.removeObject(forKey: key)
        }
        userDefaults.removeObject(forKey: "baseline_hrv")
        userDefaults.removeObject(forKey: "baseline_hr")
        userDefaults.synchronize()
    }
}

// MARK: - Stress Data Model

/// Simple stress data model for widget transmission
public struct StressData: Codable, Sendable, Identifiable {
    public var id: Date { timestamp }
    public let level: Double
    public let category: String
    public let hrv: Double
    public let heartRate: Double
    public let confidence: Double
    public let timestamp: Date

    public init(level: Double, category: String, hrv: Double, heartRate: Double, confidence: Double, timestamp: Date) {
        self.level = level
        self.category = category
        self.hrv = hrv
        self.heartRate = heartRate
        self.confidence = confidence
        self.timestamp = timestamp
    }

    /// Converts category string to StressCategory enum
    public var stressCategory: StressCategory {
        switch category.lowercased() {
        case "relaxed": return .relaxed
        case "mild": return .mild
        case "moderate": return .moderate
        case "high": return .high
        case "severe": return .severe
        default: return .mild
        }
    }
}

// MARK: - StressCategory Enum for Widget

public enum StressCategory: String, Codable, Sendable {
    case relaxed
    case mild
    case moderate
    case high
    case severe

    // Tier colours (`color` for text, `fillColor` for shapes) live in the
    // token layer: Theme/WidgetV2Tokens.swift.

    public var icon: String {
        switch self {
        case .relaxed: return "leaf.fill"
        case .mild: return "circle.fill"
        case .moderate: return "triangle.fill"
        case .high: return "square.fill"
        case .severe: return "octagon.fill"
        }
    }

    public var displayName: String {
        switch self {
        case .relaxed: return "Relaxed"
        case .mild: return "Mild"
        case .moderate: return "Elevated"
        case .high: return "High"
        case .severe: return "Severe"
        }
    }
}
