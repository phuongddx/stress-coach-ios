import WidgetKit
import Foundation

/// Timeline provider for stress monitoring widgets
/// Handles refresh logic and provides timeline entries for different widget sizes
@available(iOS 17.0, *)
public struct StressWidgetProvider: TimelineProvider {

    public typealias Entry = StressEntry

    // MARK: - Placeholder Entry

    public func placeholder(in context: Context) -> StressEntry {
        StressEntry(
            date: Date(),
            latestStress: createPlaceholderStress(),
            history: createPlaceholderHistory(),
            baseline: (50.0, 60.0),
            isPlaceholder: true
        )
    }

    // MARK: - Snapshot Entry

    /// Sample data only for the widget gallery; a snapshot of an installed
    /// widget shows the user's real data like the timeline does.
    public func getSnapshot(in context: Context, completion: @escaping (StressEntry) -> Void) {
        guard context.isPreview else {
            completion(currentEntry(at: Date()))
            return
        }
        let entry = StressEntry(
            date: Date(),
            latestStress: createSampleStress(),
            history: createSampleHistory(),
            baseline: (50.0, 60.0),
            isPlaceholder: false
        )
        completion(entry)
    }

    // MARK: - Timeline Entry

    /// Provides the actual timeline entries for widget updates
    public func getTimeline(in context: Context, completion: @escaping (Timeline<StressEntry>) -> Void) {
        let currentDate = Date()
        let entry = currentEntry(at: currentDate)

        // Calculate next update time (every 15 minutes)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate

        // Create timeline with policy to update at next scheduled time
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }

    private func currentEntry(at date: Date) -> StressEntry {
        let dataProvider = WidgetDataProvider.shared
        let latestStress = dataProvider.getLatestStress()
        return StressEntry(
            date: date,
            latestStress: latestStress,
            history: dataProvider.getHistory(limit: 20),
            baseline: dataProvider.getBaseline(),
            isPlaceholder: false,
            dataState: WidgetDataState.resolve(latestTimestamp: latestStress?.timestamp, now: date)
        )
    }

    // MARK: - Placeholder Data

    private func createPlaceholderStress() -> StressData {
        StressData(
            level: 45,
            category: "mild",
            hrv: 50,
            heartRate: 70,
            confidence: 0.8,
            timestamp: Date()
        )
    }

    private func createPlaceholderHistory() -> [StressData] {
        (0..<8).map { i in
            StressData(
                level: Double.random(in: 20...70),
                category: "mild",
                hrv: Double.random(in: 30...70),
                heartRate: Double.random(in: 55...85),
                confidence: 0.8,
                timestamp: Date().addingTimeInterval(-Double(i * 3600))
            )
        }
    }

    // MARK: - Sample Data

    private func createSampleStress() -> StressData {
        StressData(
            level: 35,
            category: "mild",
            hrv: 55,
            heartRate: 68,
            confidence: 0.85,
            timestamp: Date()
        )
    }

    private func createSampleHistory() -> [StressData] {
        [
            StressData(level: 25, category: "relaxed", hrv: 65, heartRate: 62, confidence: 0.9, timestamp: Date().addingTimeInterval(-8 * 3600)),
            StressData(level: 40, category: "mild", hrv: 52, heartRate: 70, confidence: 0.85, timestamp: Date().addingTimeInterval(-6 * 3600)),
            StressData(level: 55, category: "moderate", hrv: 42, heartRate: 78, confidence: 0.8, timestamp: Date().addingTimeInterval(-4 * 3600)),
            StressData(level: 35, category: "mild", hrv: 58, heartRate: 65, confidence: 0.85, timestamp: Date().addingTimeInterval(-2 * 3600)),
            StressData(level: 30, category: "relaxed", hrv: 62, heartRate: 64, confidence: 0.88, timestamp: Date()),
        ]
    }
}

// MARK: - Timeline Entry

/// Represents a single timeline entry for the widget
public struct StressEntry: TimelineEntry {
    public let date: Date
    public let latestStress: StressData?
    public let history: [StressData]
    public let baseline: (hrv: Double, restingHeartRate: Double)?
    public let isPlaceholder: Bool
    public let dataState: WidgetDataState

    public init(
        date: Date,
        latestStress: StressData?,
        history: [StressData],
        baseline: (hrv: Double, restingHeartRate: Double)?,
        isPlaceholder: Bool,
        dataState: WidgetDataState = .fresh
    ) {
        self.date = date
        self.latestStress = latestStress
        self.history = history
        self.baseline = baseline
        self.isPlaceholder = isPlaceholder
        self.dataState = dataState
    }

    /// Returns true if we have valid stress data to display
    public var hasValidData: Bool {
        latestStress != nil && !history.isEmpty
    }

    /// Average stress level from history
    public var averageStress: Double {
        guard !history.isEmpty else { return 0 }
        return history.reduce(0) { $0 + $1.level } / Double(history.count)
    }

    /// Trend direction compared to previous readings
    public var trend: TrendDirection {
        guard history.count >= 2 else { return .stable }

        let recent = history.prefix(3).reduce(0) { $0 + $1.level } / Double(min(3, history.count))
        let older = history.dropFirst(3).prefix(3).reduce(0) { $0 + $1.level } / Double(max(1, min(3, history.count - 3)))

        let diff = recent - older
        if diff > 10 { return .increasing }
        if diff < -10 { return .decreasing }
        return .stable
    }
}

// MARK: - Widget Data State

/// Resolves whether the widget's latest measurement is fresh, stale, or absent.
///
/// Must stay byte-identical to its copy in WidgetSharedData.swift (app target) —
/// the two live in separate compile targets and can't share a type (no shared
/// module in this project), so they're duplicated by convention, same as
/// WidgetPublisher/WidgetDataProvider.Keys.
public enum WidgetDataState: Equatable, Sendable {
    case fresh, stale, empty

    public static func resolve(latestTimestamp: Date?, now: Date, stalenessThreshold: TimeInterval = 24 * 3600) -> WidgetDataState {
        guard let latestTimestamp else { return .empty }
        return now.timeIntervalSince(latestTimestamp) > stalenessThreshold ? .stale : .fresh
    }
}

// MARK: - Trend Direction

public enum TrendDirection: String, Codable {
    case increasing
    case stable
    case decreasing

    public var icon: String {
        switch self {
        case .increasing: return "arrow.up"
        case .stable: return "minus"
        case .decreasing: return "arrow.down"
        }
    }

    public var color: String {
        switch self {
        case .increasing: return "#FF9500"
        case .stable: return "#8E8E93"
        case .decreasing: return "#34C759"
        }
    }
}
