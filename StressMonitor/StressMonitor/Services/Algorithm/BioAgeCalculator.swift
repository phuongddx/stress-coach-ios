import Foundation

// MARK: - BioAgeCalculator

/// Estimates biological age from HRV (SDNN), resting heart rate, and sleep quality.
///
/// Uses age-group norm tables for HRV and RHR deviations. Each factor contributes
/// a delta (±years) to the chronological age. Sleep quality adjusts the composite.
/// Matches the pattern of `MultiFactorStressCalculator` — struct-based, Sendable,
/// operates on `StressContext` + `PersonalBaseline`.
struct BioAgeCalculator: Sendable {

    // MARK: - Age-Group Norm Tables

    /// Expected SDNN HRV (ms) by age range. Higher HRV = younger biological age.
    ///
    /// Source: Umetani K, Singer DH, McCraty R, Atkinson M. Twenty-Four Hour Time
    /// Domain Heart Rate Variability and Heart Rate: Relations to Age and Gender
    /// Over Nine Decades. J Am Coll Cardiol. 1998;31(3):593-601.
    ///
    /// Those norms come from 24-hour ECG; HealthKit supplies short-window SDNN,
    /// and the two are not interchangeable (Shaffer & Ginsberg 2017). The user-facing
    /// caveat lives in `ScienceTopic.biologicalAge.limitation` — keep both in step.
    private static let hrvAgeNorms: [(maxAge: Int, expectedHRV: Double)] = [
        (maxAge: 25, expectedHRV: 65),
        (maxAge: 30, expectedHRV: 58),
        (maxAge: 35, expectedHRV: 52),
        (maxAge: 40, expectedHRV: 47),
        (maxAge: 45, expectedHRV: 43),
        (maxAge: 50, expectedHRV: 40),
        (maxAge: 55, expectedHRV: 37),
        (maxAge: 60, expectedHRV: 34),
        (maxAge: 65, expectedHRV: 31),
        (maxAge: 70, expectedHRV: 29),
        (maxAge: 200, expectedHRV: 27)
    ]

    /// Expected resting heart rate (bpm) by age range.
    /// Lower RHR = younger biological age (stronger vagal tone).
    ///
    /// Source: Quer G, Gouda P, Galarnyk M, Topol EJ, Steinhubl SR. Inter- and
    /// intraindividual variability in daily resting heart rate... PLOS ONE.
    /// 2020;15(2):e0227709 — 92,457 adults, ~33M daily RHR values.
    ///
    /// That cohort found age, sex, BMI and sleep together explain no more than 10%
    /// of between-person variation in RHR, which is why `BaselineCalculator`'s
    /// personal baseline outranks these population figures wherever it exists.
    private static let rhrAgeNorms: [(maxAge: Int, expectedRHR: Double)] = [
        (maxAge: 25, expectedRHR: 63),
        (maxAge: 30, expectedRHR: 64),
        (maxAge: 35, expectedRHR: 65),
        (maxAge: 40, expectedRHR: 66),
        (maxAge: 45, expectedRHR: 67),
        (maxAge: 50, expectedRHR: 68),
        (maxAge: 55, expectedRHR: 69),
        (maxAge: 60, expectedRHR: 70),
        (maxAge: 65, expectedRHR: 71),
        (maxAge: 70, expectedRHR: 72),
        (maxAge: 200, expectedRHR: 73)
    ]

    // MARK: - Configuration

    /// Minimum days of measurement history required for a reliable estimate
    static let minimumDataDays = 7

    /// How many years of bio-age delta per unit HRV deviation
    private let hrvSensitivity: Double

    /// How many years of bio-age delta per bpm RHR deviation
    private let rhrSensitivity: Double

    init(hrvSensitivity: Double = 0.3, rhrSensitivity: Double = 0.25) {
        self.hrvSensitivity = hrvSensitivity
        self.rhrSensitivity = rhrSensitivity
    }

    // MARK: - Public API

    /// Calculate biological age from recent measurements and personal baseline.
    ///
    /// - Parameters:
    ///   - chronologicalAge: User's actual age in years
    ///   - hrv: Latest HRV reading (SDNN in ms) — averaged from recent data
    ///   - restingHeartRate: Resting HR (bpm)
    ///   - sleepEfficiency: Sleep efficiency 0–1 (optional, adjusts composite)
    ///   - previousResult: Prior calculation for trend detection (optional)
    /// - Returns: BioAgeResult or nil if inputs are insufficient
    func calculate(
        chronologicalAge: Int,
        hrv: Double?,
        restingHeartRate: Double?,
        sleepEfficiency: Double?,
        previousResult: BioAgeResult? = nil
    ) -> BioAgeResult? {
        guard chronologicalAge > 0 else { return nil }

        var totalDelta = 0.0
        var factorCount = 0
        var confidence = 0.0

        // MARK: HRV Component
        if let hrv, hrv > 0 {
            let expectedHRV = expectedHRVNorm(for: chronologicalAge)
            // Positive deviation = higher HRV = younger
            let deviation = (hrv - expectedHRV) / expectedHRV
            let hrvDelta = -deviation / hrvSensitivity
            totalDelta += hrvDelta
            factorCount += 1
            confidence += 0.4
        }

        // MARK: RHR Component
        if let rhr = restingHeartRate, rhr > 0 {
            let expectedRHR = expectedRHRNorm(for: chronologicalAge)
            // Positive deviation = higher RHR = older
            let deviation = (rhr - expectedRHR) / expectedRHR
            let rhrDelta = deviation / rhrSensitivity
            totalDelta += rhrDelta
            factorCount += 1
            confidence += 0.35
        }

        // MARK: Sleep Quality Component
        if let efficiency = sleepEfficiency, efficiency > 0 {
            // 85%+ sleep efficiency = no penalty; below that adds years
            let sleepDeviation = 0.85 - efficiency
            let sleepDelta = sleepDeviation * 10  // up to ~8.5 years
            totalDelta += sleepDelta
            factorCount += 1
            confidence += 0.25
        }

        guard factorCount > 0 else { return nil }

        let estimatedAge = max(18, chronologicalAge + Int(totalDelta.rounded()))
        let trend = determineTrend(currentEstimate: estimatedAge, previous: previousResult)

        return BioAgeResult(
            estimatedAge: estimatedAge,
            chronologicalAge: chronologicalAge,
            trend: trend,
            confidence: min(1.0, confidence)
        )
    }

    /// Convenience: calculate from StressContext + baseline (matches MultiFactor pattern)
    func calculate(
        from context: StressContext,
        chronologicalAge: Int,
        previousResult: BioAgeResult? = nil
    ) -> BioAgeResult? {
        let sleepEfficiency = context.sleepData?.sleepEfficiency
        return calculate(
            chronologicalAge: chronologicalAge,
            hrv: context.hrv,
            restingHeartRate: context.heartRate,
            sleepEfficiency: sleepEfficiency,
            previousResult: previousResult
        )
    }

    /// Check if there's enough measurement history for a reliable estimate.
    func hasEnoughData(measurements: [StressMeasurement]) -> Bool {
        guard measurements.count >= Self.minimumDataDays else { return false }

        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -Self.minimumDataDays, to: Date())!
        let recentCount = measurements.filter { $0.timestamp >= sevenDaysAgo }.count
        return recentCount >= Self.minimumDataDays
    }

    // MARK: - Private Helpers

    private func expectedHRVNorm(for age: Int) -> Double {
        for norm in Self.hrvAgeNorms where age <= norm.maxAge {
            return norm.expectedHRV
        }
        return Self.hrvAgeNorms.last?.expectedHRV ?? 40.0
    }

    private func expectedRHRNorm(for age: Int) -> Double {
        for norm in Self.rhrAgeNorms where age <= norm.maxAge {
            return norm.expectedRHR
        }
        return Self.rhrAgeNorms.last?.expectedRHR ?? 68.0
    }

    private func determineTrend(currentEstimate: Int, previous: BioAgeResult?) -> BioAgeTrend {
        guard let previous else { return .stable }
        let change = currentEstimate - previous.estimatedAge
        if change <= -2 { return .improving }
        if change >= 2 { return .declining }
        return .stable
    }
}
