import XCTest
@testable import StressMonitor

/// Guards the D3 privacy decision: HealthKit-derived raw readings (HRV ms,
/// heart rate bpm, baseline values) must never reach the /chat backend. Only
/// the app's own derived stress score/category may — that's the product's
/// own analytics output, not HealthKit data itself.
final class StressContextPayloadTests: XCTestCase {

    /// Every key the backend's derived-only allowlist accepts
    /// (stress-app-be `sanitizeStressContext`). Anything else on the wire is
    /// either raw health data or dead weight.
    private static let derivedKeys: Set<String> = [
        "stress_level", "stress_category", "confidence", "sleep_quality",
        "sleep_hours", "active_minutes", "recovery_score", "stress_trend",
        "stress_trend_delta", "hrv_trend", "sleep_trend", "factor_breakdown",
        "language", "coaching_style"
    ]

    private func encodedJSON(_ payload: StressContextPayload) throws -> (object: [String: Any], text: String) {
        let data = try JSONEncoder().encode(payload)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return (object, String(decoding: data, as: UTF8.self))
    }

    func testEncodedPayloadContainsOnlyDerivedKeysAndNoRawValues() throws {
        // Distinctive raw readings, so a leak shows up in the encoded text.
        let result = StressResult(
            level: 65, category: .severe, confidence: 0.9, hrv: 42.37, heartRate: 78.61,
            factorBreakdown: FactorBreakdown(hrvComponent: 0.72, hrComponent: 0.61, sleepComponent: nil,
                                             activityComponent: nil, recoveryComponent: nil,
                                             dataCompleteness: 0.4)
        )
        let baseline = PersonalBaseline(restingHeartRate: 59.13, baselineHRV: 51.29)
        let history = [
            StressMeasurement(timestamp: Date(), stressLevel: 65, hrv: 42.37, restingHeartRate: 59.13),
            StressMeasurement(timestamp: Date(timeIntervalSinceNow: -3600), stressLevel: 50,
                              hrv: 47.83, restingHeartRate: 59.13)
        ]

        let payload = StressContextPayload.build(stressResult: result, baseline: baseline, recentHistory: history)
        let (json, text) = try encodedJSON(payload)

        let unexpected = Set(json.keys).subtracting(Self.derivedKeys)
        XCTAssertTrue(unexpected.isEmpty, "Non-derived keys on the wire: \(unexpected.sorted())")
        for raw in ["42.37", "78.61", "59.13", "51.29", "47.83"] {
            XCTAssertFalse(text.contains(raw), "Raw reading \(raw) leaked into the /chat payload.")
        }
        // Derived values still go out.
        XCTAssertEqual(json["stress_level"] as? Int, 65)
        XCTAssertEqual(json["stress_category"] as? String, "severe")
        XCTAssertEqual(json["stress_trend"] as? String, "increasing")
        let factors = try XCTUnwrap(json["factor_breakdown"] as? [String: Any])
        XCTAssertEqual(Set(factors.keys), ["hrv", "heart_rate"])
        XCTAssertEqual((factors["hrv"] as? [String: Double])?["score"], 0.72)
    }

    func testBuildStillIncludesDerivedStressScore() {
        let result = StressResult(level: 65, category: .moderate, confidence: 0.9, hrv: 42.5, heartRate: 78)

        let payload = StressContextPayload.build(stressResult: result, baseline: nil)

        XCTAssertEqual(payload.stressLevel, 65, "The derived stress score is the coach's core input and is not HealthKit data.")
        XCTAssertEqual(payload.stressCategory, StressCategory.moderate.rawValue)
        XCTAssertEqual(payload.confidence, 0.9)
    }

    func testEncodedPayloadOmitsRawHealthKeysEntirely() throws {
        let result = StressResult(level: 65, category: .moderate, confidence: 0.9, hrv: 42.5, heartRate: 78)
        let baseline = PersonalBaseline(restingHeartRate: 60, baselineHRV: 50)
        let payload = StressContextPayload.build(stressResult: result, baseline: baseline)

        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Swift's Codable synthesis omits nil Optional keys entirely (does not
        // emit "key": null) — asserting absence here proves the wire format,
        // not just the in-memory struct.
        XCTAssertNil(json?["hrv"], "hrv key must be absent from the wire payload.")
        XCTAssertNil(json?["heart_rate"], "heart_rate key must be absent from the wire payload.")
        XCTAssertNil(json?["baseline_hrv"], "baseline_hrv key must be absent from the wire payload.")
        XCTAssertNil(json?["baseline_hr"], "baseline_hr key must be absent from the wire payload.")
        XCTAssertNotNil(json?["stress_level"], "Derived stress level must still be present.")
    }

    // MARK: - CR-02 trend direction (repository delivers newest-first)

    /// `StressRepository.fetchRecent` hands `build` a newest-first history
    /// (SortDescriptor reverse), so the trend must be computed after
    /// restoring chronological order. These cases pin that contract (CR-02).
    private func measurement(level: Double, minutesAgo: Int) -> StressMeasurement {
        StressMeasurement(
            timestamp: Date(timeIntervalSinceNow: -TimeInterval(minutesAgo * 60)),
            stressLevel: level,
            hrv: 40,
            restingHeartRate: 60
        )
    }

    func testTrendIncreasingWhenStressRoseOverTime() {
        // Newest-first [70, 40]: chronologically the user went 40 → 70.
        let history = [
            measurement(level: 70, minutesAgo: 0),
            measurement(level: 40, minutesAgo: 60)
        ]

        let payload = StressContextPayload.build(stressResult: nil, baseline: nil, recentHistory: history)

        XCTAssertEqual(payload.stressTrend, "increasing", "A newest-first [70, 40] history rose over time.")
        XCTAssertEqual(payload.stressTrendDelta, "+30%")
    }

    func testTrendDecreasingWhenStressFellOverTime() {
        // Newest-first [40, 70]: chronologically the user went 70 → 40.
        let history = [
            measurement(level: 40, minutesAgo: 0),
            measurement(level: 70, minutesAgo: 60)
        ]

        let payload = StressContextPayload.build(stressResult: nil, baseline: nil, recentHistory: history)

        XCTAssertEqual(payload.stressTrend, "decreasing", "A newest-first [40, 70] history fell over time.")
        XCTAssertEqual(payload.stressTrendDelta, "-30%")
    }

    func testTrendStableWhenFluctuationWithinThreshold() {
        // ±5 either order is stable — direction is irrelevant at this delta.
        let history = [
            measurement(level: 52, minutesAgo: 0),
            measurement(level: 50, minutesAgo: 60)
        ]

        let payload = StressContextPayload.build(stressResult: nil, baseline: nil, recentHistory: history)

        XCTAssertEqual(payload.stressTrend, "stable")
    }

    func testTrendNilForSingleMeasurement() {
        let history = [measurement(level: 55, minutesAgo: 0)]

        let payload = StressContextPayload.build(stressResult: nil, baseline: nil, recentHistory: history)

        XCTAssertNil(payload.stressTrend, "One measurement has no direction.")
        XCTAssertNil(payload.stressTrendDelta)
    }

    // MARK: - WR-01 window selection (>5 newest-first measurements)

    func testTrendUsesTheNewestWindowBeyondFiveMeasurements() {
        // Newest-first [80, 20, 20, 20, 20, 20]: the five newest rows are
        // [80, 20, 20, 20, 20] → chronologically 20 → 80 = increasing.
        // `suffix(5)` on this newest-first array would keep [20, 20, 20,
        // 20, 20] and report "stable" — wrong window, wrong delta (WR-01).
        let history = [
            measurement(level: 80, minutesAgo: 0),
            measurement(level: 20, minutesAgo: 30),
            measurement(level: 20, minutesAgo: 60),
            measurement(level: 20, minutesAgo: 90),
            measurement(level: 20, minutesAgo: 120),
            measurement(level: 20, minutesAgo: 150)
        ]

        let payload = StressContextPayload.build(stressResult: nil, baseline: nil, recentHistory: history)

        XCTAssertEqual(payload.stressTrend, "increasing", "The trend window must be the NEWEST five measurements, not the oldest.")
        XCTAssertEqual(payload.stressTrendDelta, "+60%")
    }

    func testTrendIgnoresRowsOlderThanTheWindow() {
        // Newest-first [20, 20, 20, 20, 20, 80]: the oldest row (80) sits
        // outside the five-newest window, and within it the level never
        // moved — stable. `suffix(5)` would include the 80 and report a
        // fall (WR-01).
        let history = [
            measurement(level: 20, minutesAgo: 0),
            measurement(level: 20, minutesAgo: 30),
            measurement(level: 20, minutesAgo: 60),
            measurement(level: 20, minutesAgo: 90),
            measurement(level: 20, minutesAgo: 120),
            measurement(level: 80, minutesAgo: 150)
        ]

        let payload = StressContextPayload.build(stressResult: nil, baseline: nil, recentHistory: history)

        XCTAssertEqual(payload.stressTrend, "stable", "Rows older than the five-newest window must not drive the trend.")
        XCTAssertEqual(payload.stressTrendDelta, "+0%")
    }
}
