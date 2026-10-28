import Foundation

extension StressMeasurement {
    /// Chat/context representation of a stored reading. Nil when the reading
    /// carries no confidence value, since confidence cannot be reconstructed.
    /// `heartRate` is 0 when the reading had no heart-rate sample.
    var stressResult: StressResult? {
        guard let confidences, !confidences.isEmpty else { return nil }
        let breakdown = dataCompleteness.map {
            FactorBreakdown(
                hrvComponent: hrvComponent,
                hrComponent: hrComponent,
                sleepComponent: sleepComponent,
                activityComponent: activityComponent,
                recoveryComponent: recoveryComponent,
                dataCompleteness: $0
            )
        }
        return StressResult(
            level: stressLevel,
            category: category,
            confidence: confidences.reduce(0, +) / Double(confidences.count),
            hrv: hrv,
            heartRate: restingHeartRate,
            timestamp: timestamp,
            factorBreakdown: breakdown
        )
    }
}
