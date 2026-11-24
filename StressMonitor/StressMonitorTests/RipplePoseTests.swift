import Testing
import UIKit
@testable import StressMonitor

struct RipplePoseTests {
    @Test("Every stress category maps to its level pose", arguments: [
        (StressCategory.relaxed, RipplePose.relaxed),
        (.mild, .mild),
        (.moderate, .elevated),
        (.high, .high),
        (.severe, .severe),
    ])
    func categoryMapsToPose(category: StressCategory, expected: RipplePose) {
        #expect(RipplePose.from(category: category) == expected)
    }

    @Test("No data maps to the base pose")
    func noDataIsBase() {
        let none: StressCategory? = nil
        #expect(RipplePose.from(category: none) == .base)
    }

    @Test("Every mood maps to its pose", arguments: [
        (RippleMood.serene, RipplePose.base),
        (.relaxed, .relaxed),
        (.focused, .mild),
        (.happy, .mild),
        (.celebrating, .celebrating),
        (.worried, .elevated),
        (.determined, .high),
        (.tired, .sleeping),
    ])
    func moodMapsToPose(mood: RippleMood, expected: RipplePose) {
        #expect(mood.pose == expected)
    }

    @Test("Every mood is covered by the pose table")
    func allMoodsCovered() {
        #expect(RippleMood.allCases.count == 8)
    }

    @Test("Asset names follow the ripple-v2 pattern")
    func assetNames() {
        #expect(RipplePose.elevated.assetName == "ripple-v2-elevated")
        #expect(RipplePose.elevated.headAssetName == "ripple-v2-elevated-head")
        #expect(RipplePose.allCases.count == 11)
    }

    @Test("Every pose's full and head assets load from the app bundle", arguments: RipplePose.allCases)
    func assetsLoad(pose: RipplePose) {
        #expect(UIImage(named: pose.assetName) != nil, "missing \(pose.assetName)")
        #expect(UIImage(named: pose.headAssetName) != nil, "missing \(pose.headAssetName)")
    }

    @Test("Every pose has a non-empty accessibility label", arguments: RipplePose.allCases)
    func accessibilityLabels(pose: RipplePose) {
        #expect(pose.accessibilityLabel.hasPrefix("Ripple"))
    }

    @Test("Catalog maps ripple and ripple-hero to the v2 base pose")
    func catalogMapsRipple() {
        #expect(CharacterAssetCatalog.assetName(for: "ripple") == "ripple-v2-base")
        #expect(CharacterAssetCatalog.assetName(for: "Ripple") == "ripple-v2-base")
        #expect(CharacterAssetCatalog.assetName(for: "ripple-hero") == "ripple-v2-base")
        #expect(CharacterAssetCatalog.heroAssetName(for: "ripple") == "ripple-v2-base")
        #expect(CharacterAssetCatalog.assetName(for: "blossom") == "blossom")
    }

    @Test("Explicit pose wins over the mood's pose")
    func explicitPoseWins() {
        let view = StressBuddyIllustration(mood: .happy, size: 40, pose: .thinking, crop: .head)
        #expect(view.resolvedPose == .thinking)
        #expect(StressBuddyIllustration(mood: .tired, size: 40).resolvedPose == .sleeping)
    }

    @Test("Character detail tier cells preview their level pose")
    func moodCellPreviewsLevelPose() {
        #expect(StressMoodCell.severe.ripplePose == .severe)
        #expect(StressMoodCell.moderate.ripplePose == .elevated)
        #expect(StressMoodCell.ripplePose(for: StressMoodCell.severe.mood) == .severe)
        #expect(StressMoodCell.ripplePose(for: StressMoodCell.mild.mood) == .mild)
        #expect(StressMoodCell.ripplePose(for: .celebrating) == .celebrating)
    }
}
