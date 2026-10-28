import Foundation

// MARK: - Chat Context Builder

/// Builds system prompts with current health/stress context for the AI Kitten persona.
/// Target: ~600 tokens system prompt (leaves ~3400 for conversation in 4K context).
struct ChatContextBuilder {

    /// Builds the AI Kitten system prompt with live health data
    /// - Parameters:
    ///   - stressResult: Current stress measurement result
    ///   - baseline: User's personal baseline
    ///   - recentHistory: Last N stress measurements for trend analysis
    /// - Returns: System prompt string (~600 tokens)
    static func buildSystemPrompt(
        stressResult: StressResult?,
        baseline: PersonalBaseline?,
        recentHistory: [StressMeasurement]
    ) -> String {
        var prompt = """
        You are Ripple, a friendly and supportive wellness companion \
        inside the StressMonitor app. You help users understand their stress levels \
        and suggest practical wellness activities.

        RULES:
        - Be warm, concise, and practical (2-3 sentences max unless asked for detail)
        - Never provide medical diagnosis or treatment advice
        - If asked about medical topics, suggest consulting a healthcare professional
        - Always include a disclaimer when discussing stress management
        - Suggest breathing exercises when stress is high (moderate or above)
        - Use the user's health data to personalize responses
        - Stay in character as a friendly kitten wellness coach

        """

        // Current stress state (~150 tokens)
        if let stress = stressResult {
            prompt += """

            CURRENT USER DATA:
            - Stress level: \(Int(stress.level))/100 (\(categoryName(stress.category)))
            - HRV: \(String(format: "%.1f", stress.hrv))ms
            - Confidence: \(String(format: "%.0f", stress.confidence * 100))%
            """

            if stress.heartRate > 0 {
                prompt += "\n- Heart rate: \(String(format: "%.0f", stress.heartRate)) bpm"
            }

            if let breakdown = stress.factorBreakdown {
                prompt += "\n- Data completeness: \(String(format: "%.0f", breakdown.dataCompleteness * 100))%"
            }
        }

        // Baseline context (~50 tokens)
        if let baseline {
            prompt += "\n\nBASELINE: Resting HR \(String(format: "%.0f", baseline.restingHeartRate)) bpm, Baseline HRV \(String(format: "%.1f", baseline.baselineHRV))ms"
        }

        // Trend summary (~100 tokens)
        if recentHistory.count >= 3 {
            let trend = analyzeTrend(recentHistory)
            prompt += "\n\nTREND: \(trend)"
        }

        return prompt
    }

    // MARK: - Trend Analysis

    /// Generates a brief trend description from recent measurements
    private static func analyzeTrend(_ measurements: [StressMeasurement]) -> String {
        let recent = measurements.suffix(min(5, measurements.count))
        let levels = recent.map(\.stressLevel)

        guard levels.count >= 2 else { return "Not enough data for trend analysis" }

        let avg = levels.reduce(0, +) / Double(levels.count)
        let first = levels.first!
        let last = levels.last!
        let diff = last - first

        let direction: String
        if abs(diff) < 5 {
            direction = "stable"
        } else if diff > 0 {
            direction = "trending up"
        } else {
            direction = "trending down"
        }

        return "Stress is \(direction) over last \(levels.count) readings (avg: \(Int(avg)))."
    }

    /// Human-readable category name for system prompt (avoids cross-layer Badge.swift dependency)
    private static func categoryName(_ category: StressCategory) -> String {
        switch category {
        case .relaxed: return "Relaxed"
        case .mild: return "Mild Stress"
        case .moderate: return "Moderate Stress"
        case .high: return "High Stress"
        case .severe: return "Severe Stress"
        }
    }
}
