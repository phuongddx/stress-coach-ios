import Foundation
import Testing
@testable import StressMonitor

@Suite("Haptics setting")
struct HapticPreferenceTests {

    private func makeDefaults() throws -> UserDefaults {
        let name = "HapticPreferenceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("haptics are on for a fresh install")
    func testFreshInstall_HapticsEnabled() throws {
        let defaults = try makeDefaults()
        #expect(HapticPreference.isEnabled(in: defaults))
        #expect(HapticManager.shouldPlay(hardwareSupportsHaptics: true, defaults: defaults))
    }

    @Test("turning haptics off is saved and stops feedback")
    func testTurningOff_IsPersistedAndRespected() throws {
        let defaults = try makeDefaults()

        HapticPreference.setEnabled(false, in: defaults)

        #expect(defaults.bool(forKey: HapticPreference.disabledKey))
        #expect(HapticPreference.isEnabled(in: defaults) == false)
        #expect(HapticManager.shouldPlay(hardwareSupportsHaptics: true, defaults: defaults) == false)
    }

    @Test("turning haptics back on restores feedback")
    func testTurningBackOn_RestoresFeedback() throws {
        let defaults = try makeDefaults()
        HapticPreference.setEnabled(false, in: defaults)

        HapticPreference.setEnabled(true, in: defaults)

        #expect(HapticPreference.isEnabled(in: defaults))
        #expect(HapticManager.shouldPlay(hardwareSupportsHaptics: true, defaults: defaults))
    }

    @Test("no feedback on hardware without haptics, whatever the setting")
    func testNoHardware_NeverPlays() throws {
        let defaults = try makeDefaults()
        #expect(HapticManager.shouldPlay(hardwareSupportsHaptics: false, defaults: defaults) == false)
    }
}
