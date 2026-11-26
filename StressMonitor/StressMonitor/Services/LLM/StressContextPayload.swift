import Foundation

// MARK: - Stress Context Payload

/// Structured health context sent to the stress-api backend `/chat` endpoint.
/// The backend builds the system prompt from this data — the iOS app no longer
/// builds the prompt locally.
///
/// Privacy: this type carries only the app's own derived values (stress
/// score, category, trends, factor scores). Raw HealthKit readings (HRV,
/// heart rate, baselines) have no field here, so they cannot be encoded.
/// The backend also drops them if an older build sends them.
struct StressContextPayload: Codable, Sendable {
    let stressLevel: Int?
    let stressCategory: String?
    let confidence: Double?
    let sleepQuality: Int?
    let sleepHours: Double?
    let activeMinutes: Int?
    let recoveryScore: Int?
    let stressTrend: String?
    let stressTrendDelta: String?
    let hrvTrend: String?
    let sleepTrend: String?
    let factorBreakdown: FactorBreakdownPayload?
    let language: String
    let coachingStyle: String

    // MARK: - Nested Types

    struct FactorBreakdownPayload: Codable, Sendable {
        let hrv: FactorPayload?
        let heartRate: FactorPayload?
        let sleep: FactorPayload?
        let activity: FactorPayload?
        let recovery: FactorPayload?

        enum CodingKeys: String, CodingKey {
            case hrv
            case heartRate = "heart_rate"
            case sleep
            case activity
            case recovery
        }
    }

    struct FactorPayload: Codable, Sendable {
        let score: Double
        let weight: Double
    }

    // MARK: - Coding Keys (snake_case for JSON)

    enum CodingKeys: String, CodingKey {
        case stressLevel = "stress_level"
        case stressCategory = "stress_category"
        case confidence
        case sleepQuality = "sleep_quality"
        case sleepHours = "sleep_hours"
        case activeMinutes = "active_minutes"
        case recoveryScore = "recovery_score"
        case stressTrend = "stress_trend"
        case stressTrendDelta = "stress_trend_delta"
        case hrvTrend = "hrv_trend"
        case sleepTrend = "sleep_trend"
        case factorBreakdown = "factor_breakdown"
        case language
        case coachingStyle = "coaching_style"
    }

    // MARK: - Builder

    /// Build a stress context payload from the current health data available in ChatViewModel.
    /// `baseline` is accepted for call-site stability but never encoded —
    /// raw baseline readings stay on the device.
    static func build(
        stressResult: StressResult?,
        baseline: PersonalBaseline?,
        recentHistory: [StressMeasurement] = [],
        language: String = "en",
        coachingStyle: String = "supportive"
    ) -> StressContextPayload {
        // Trend analysis
        var trend: String? = nil
        var trendDelta: String? = nil
        // The repository delivers newest-first, so `prefix` selects the
        // most-recent window — `suffix` would silently keep the OLDEST rows
        // and drop the newest ones (WR-01).
        let recent = recentHistory.prefix(min(5, max(2, recentHistory.count)))
        if recent.count >= 2 {
            // CR-02: restore chronological order before the delta —
            // `last - first` must be newest − oldest for the direction (and
            // sign of trendDelta) to match what the user actually
            // experienced.
            let chronological = Array(recent.reversed())
            let levels = chronological.map(\.stressLevel)
            let first = levels.first!
            let last = levels.last!
            let diff = last - first
            if abs(diff) < 5 {
                trend = "stable"
            } else if diff > 0 {
                trend = "increasing"
            } else {
                trend = "decreasing"
            }
            trendDelta = String(format: "%+.0f%%", diff)
        }

        // Factor breakdown
        var factorPayload: FactorBreakdownPayload? = nil
        if let fb = stressResult?.factorBreakdown {
            let defaults = FactorWeights.defaults
            factorPayload = FactorBreakdownPayload(
                hrv: fb.hrvComponent.map { FactorPayload(score: $0, weight: defaults.hrv) },
                heartRate: fb.hrComponent.map { FactorPayload(score: $0, weight: defaults.heartRate) },
                sleep: fb.sleepComponent.map { FactorPayload(score: $0, weight: defaults.sleep) },
                activity: fb.activityComponent.map { FactorPayload(score: $0, weight: defaults.activity) },
                recovery: fb.recoveryComponent.map { FactorPayload(score: $0, weight: defaults.recovery) }
            )
        }

        return StressContextPayload(
            stressLevel: stressResult.map { Int($0.level) },
            stressCategory: stressResult?.category.rawValue,
            confidence: stressResult?.confidence,
            sleepQuality: nil,  // Not directly available from StressResult
            sleepHours: nil,
            activeMinutes: nil,
            recoveryScore: nil,
            stressTrend: trend,
            stressTrendDelta: trendDelta,
            hrvTrend: nil,
            sleepTrend: nil,
            factorBreakdown: factorPayload,
            language: language,
            coachingStyle: coachingStyle
        )
    }
}
