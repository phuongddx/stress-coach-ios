import Foundation
import WidgetKit

/// Lightweight, App-Group-backed store for the latest reading and a rolling
/// 7-day history.
///
/// Uses the shared App Group `group.stress.ai.com` so the same data is visible
/// to the watch app, the watch complications and (via the companion iOS store)
/// the iPhone widgets. Everything is encoded with `JSONEncoder`/`JSONDecoder`
/// so it round-trips cleanly across processes.
final class WatchSharedDataStore {

    static let shared = WatchSharedDataStore()

    /// Shared App Group identifier — see entitlements.
    static let appGroupID = "group.stress.ai.com"

    private let defaults: UserDefaults?

    private init() {
        self.defaults = UserDefaults(suiteName: Self.appGroupID)
    }

    // MARK: - Keys

    private enum Keys {
        static let latest = "watch.latestStress"
        static let history = "watch.stressHistory"
    }

    // MARK: - Latest

    /// The most recent measurement, if any has been written.
    var latest: SharedReading? {
        guard let data = defaults?.data(forKey: Keys.latest) else { return nil }
        return try? decoder.decode(SharedReading.self, from: data)
    }

    /// Persist a new reading and append it to the 7-day history.
    func save(_ reading: SharedReading) {
        let enc = encoder
        if let data = try? enc.encode(reading) {
            defaults?.set(data, forKey: Keys.latest)
        }

        var history = historyReadings
        history.removeAll { Calendar.current.isDate($0.timestamp, inSameDayAs: reading.timestamp) == false
            && $0.timestamp < reading.timestamp.addingTimeInterval(-7 * 24 * 3600) }
        history.insert(reading, at: 0)
        // Keep at most ~60 readings (comfortable for a 7-day list).
        if history.count > 60 { history = Array(history.prefix(60)) }
        if let data = try? enc.encode(history) {
            defaults?.set(data, forKey: Keys.history)
        }
        defaults?.synchronize()

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - History (last 7 days)

    /// All stored readings from the last 7 days, newest first.
    var history7Days: [SharedReading] {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        return historyReadings.filter { $0.timestamp >= cutoff }
    }

    private var historyReadings: [SharedReading] {
        guard let data = defaults?.data(forKey: Keys.history) else { return [] }
        return (try? decoder.decode([SharedReading].self, from: data)) ?? []
    }

    func clear() {
        defaults?.removeObject(forKey: Keys.latest)
        defaults?.removeObject(forKey: Keys.history)
        defaults?.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Codec

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

// MARK: - SharedReading

/// Transport model for a single stress reading shared across surfaces.
/// Only the level (0–100) and timestamp are required; the tier is derived
/// from the level via `StressCategory` on demand.
struct SharedReading: Codable, Sendable, Identifiable {
    let id: UUID
    let level: Double
    let timestamp: Date

    init(level: Double, timestamp: Date = Date()) {
        self.id = UUID()
        self.level = min(150, max(0, level))
        self.timestamp = timestamp
    }

    /// Resolved 5-tier category (iOS-aligned).
    var category: StressCategory { StressCategory.category(for: level) }
}
