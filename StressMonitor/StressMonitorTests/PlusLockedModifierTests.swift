import Foundation
import Testing
@testable import StressMonitor

// MARK: - PlusLockedModifierTests

struct PlusLockedModifierTests {

    @Test("An unlocked chart gets no overlay copy")
    func unlockedHasNoPresentation() {
        for chart in PlusChartID.allCases {
            #expect(PlusLockPresentation.make(isLocked: false, trialEligible: true, chart: chart) == nil)
        }
    }

    @Test("A locked chart offers the free trial when eligible")
    func lockedWithTrial() throws {
        let presentation = try #require(
            PlusLockPresentation.make(isLocked: true, trialEligible: true, chart: .trendsHRV)
        )
        #expect(presentation.buttonTitle == "Try Plus free")
        #expect(presentation.message == "See your full chart with Plus")
        #expect(presentation.accessibilityLabel == "HRV trend chart locked")
        #expect(presentation.accessibilityHint == "Double-tap to unlock Plus")
    }

    @Test("A locked chart says Unlock Plus when the trial is used")
    func lockedWithoutTrial() throws {
        let presentation = try #require(
            PlusLockPresentation.make(isLocked: true, trialEligible: false, chart: .bioAgeDaily)
        )
        #expect(presentation.buttonTitle == "Unlock Plus")
        #expect(presentation.accessibilityLabel == "Biological age chart locked")
    }

    @Test("All seven iPhone charts are covered with distinct names")
    func sevenCharts() {
        #expect(PlusChartID.allCases.count == 7)
        #expect(Set(PlusChartID.allCases.map(\.displayName)).count == 7)
    }

    @Test("Every Plus chart is locked at exactly one call site")
    func eachChartAttachedOnce() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("StressMonitor", isDirectory: true)
        let enumerator = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        var callSites: [String: Int] = [:]
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            guard url.lastPathComponent != "PlusLockedModifier.swift" else { continue }
            let contents = try String(contentsOf: url, encoding: .utf8)
            for chart in PlusChartID.allCases {
                let needle = ".plusLocked(.\(chart.rawValue))"
                callSites[chart.rawValue, default: 0] += contents.components(separatedBy: needle).count - 1
            }
        }
        for chart in PlusChartID.allCases {
            #expect(callSites[chart.rawValue] == 1, "\(chart.rawValue) has \(callSites[chart.rawValue] ?? 0) call sites")
        }
    }

    @Test("The chart paywall has its own heading")
    func chartHeadline() {
        #expect(PaywallReason.chart(.trendsCalendar).headline == "See all your charts")
        #expect(PaywallReason.general.headline == nil)
        #expect(PaywallReason.onboarding.headline == nil)
        #expect(PaywallReason.outOfCredits.headline?.contains("20 free messages") == true)
    }
}
