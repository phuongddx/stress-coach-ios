import Foundation

/// Local rules engine for generating stress insights
enum InsightGenerator {

    /// Generate an insight from current stress and historical data.
    /// `baselineHRV` is the user's own HRV baseline; without it no HRV-versus-normal claim is made.
    static func generate(from stress: StressResult, history unorderedHistory: [StressMeasurement], baselineHRV: Double? = nil) -> AIInsight? {
        let history = unorderedHistory.sorted { $0.timestamp < $1.timestamp }

        // Check for high stress
        if stress.level > 75 {
            return AIInsight(
                title: "High Stress Detected",
                message: "Your stress level is elevated. Consider taking a short break or trying a breathing exercise.",
                actionTitle: "Start Breathing",
                trendData: extractTrendData(from: history)
            )
        }

        // Check for improving trend
        if let trend = calculateTrend(from: history), trend < -5 {
            return AIInsight(
                title: "Improving Trend",
                message: "Your stress levels have been decreasing. Keep up the good work with your wellness routine.",
                actionTitle: nil,
                trendData: extractTrendData(from: history)
            )
        }

        // Check for worsening trend
        if let trend = calculateTrend(from: history), trend > 5 {
            return AIInsight(
                title: "Rising Stress",
                message: "Your stress has been increasing over recent measurements. Consider stress-reduction techniques.",
                actionTitle: nil,
                trendData: extractTrendData(from: history)
            )
        }

        // Check for HRV well above the user's own baseline
        if let baselineHRV, baselineHRV > 0, stress.hrv > baselineHRV * hrvAboveBaselineRatio {
            return AIInsight(
                title: "Excellent Recovery",
                message: "Your HRV is well above your usual baseline today, indicating good recovery. This is a good time for challenging activities.",
                actionTitle: nil,
                trendData: extractTrendData(from: history)
            )
        }

        // Default insight for relaxed state
        if stress.level <= 25 {
            return AIInsight(
                title: "Feeling Calm",
                message: "You're in a relaxed state. Great time for focused work or creative activities.",
                actionTitle: nil,
                trendData: extractTrendData(from: history)
            )
        }

        // No specific insight
        return nil
    }

    // MARK: - Helpers

    private static let hrvAboveBaselineRatio = 1.15

    /// Calculate trend direction from history (negative = improving, positive = worsening)
    private static func calculateTrend(from history: [StressMeasurement]) -> Double? {
        guard history.count >= 3 else { return nil }

        let recent = Array(history.suffix(3))
        let older = Array(history.dropLast(3).suffix(3))

        guard !older.isEmpty else { return nil }

        let recentAvg = recent.map(\.stressLevel).reduce(0, +) / Double(recent.count)
        let olderAvg = older.map(\.stressLevel).reduce(0, +) / Double(older.count)

        return recentAvg - olderAvg
    }

    /// Extract trend data for sparkline chart
    private static func extractTrendData(from history: [StressMeasurement]) -> [Double] {
        Array(history.suffix(6).map(\.stressLevel))
    }
}
