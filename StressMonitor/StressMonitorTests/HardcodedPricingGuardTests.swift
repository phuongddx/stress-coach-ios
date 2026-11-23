import Foundation
import Testing

/// SPEC AC-8: no invented prices, ratings or trial lengths in app source.
/// Prices and trial length must come from StoreKit products at runtime.
///
/// Reads the app sources from the host checkout via `#filePath`; the
/// simulator test host can read host paths, so this also runs in CI.
struct HardcodedPricingGuardTests {

    /// Banned anywhere in the iPhone app target.
    private static let bannedEverywhere = [
        "$4.99",
        "7 days free",
        "4.8\u{2605}",
        "4.8\\u{2605}",
        "12K",
        "4-hour stress forecast",
        "Family Sharing enabled"
    ]

    /// "7-day" is a legitimate chart range elsewhere ("7-day avg"), so it is
    /// banned only on the surfaces that sell or describe the subscription.
    private static let bannedOnSubscriptionSurfaces = ["7-day"]

    private static let subscriptionSurfaces = [
        "Views/Premium/",
        "Views/Dashboard/Components/PremiumBanner.swift",
        "Views/Onboarding/OnboardingSuccessView.swift",
        "Models/SubscriptionPlan.swift",
        "Services/StoreKit/"
    ]

    private static var appSourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // StressMonitorTests/
            .deletingLastPathComponent()      // StressMonitor/ (project dir)
            .appendingPathComponent("StressMonitor", isDirectory: true)
    }

    private static func swiftSources() throws -> [(relativePath: String, contents: String)] {
        let root = appSourceRoot
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        var files: [(String, String)] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let relative = String(url.path.dropFirst(root.path.count + 1))
            files.append((relative, try String(contentsOf: url, encoding: .utf8)))
        }
        return files
    }

    @Test("App sources are readable (guards would pass vacuously otherwise)")
    func sourcesAreReadable() throws {
        let files = try Self.swiftSources()
        #expect(files.count > 100, "Found only \(files.count) Swift files under \(Self.appSourceRoot.path)")
        #expect(files.contains { $0.relativePath == "Views/Premium/IAPPremiumView.swift" })
    }

    @Test("No hardcoded price, rating, user count or fake feature in the app")
    func noBannedStringsAnywhere() throws {
        let hits = try Self.swiftSources().flatMap { file in
            Self.bannedEverywhere
                .filter { file.contents.contains($0) }
                .map { "\(file.relativePath): \($0)" }
        }
        #expect(hits.isEmpty, "Hardcoded marketing/pricing strings: \(hits)")
    }

    @Test("No hardcoded trial length on subscription surfaces")
    func noHardcodedTrialLength() throws {
        let surfaceFiles = try Self.swiftSources().filter { file in
            Self.subscriptionSurfaces.contains { file.relativePath.hasPrefix($0) }
        }
        #expect(surfaceFiles.count >= 8, "Subscription surfaces not found: \(surfaceFiles.map(\.relativePath))")
        let hits = surfaceFiles.flatMap { file in
            Self.bannedOnSubscriptionSurfaces
                .filter { file.contents.contains($0) }
                .map { "\(file.relativePath): \($0)" }
        }
        #expect(hits.isEmpty, "Hardcoded trial length: \(hits)")
    }
}
