import ActivityKit
import AppIntents
import Foundation

// Shared by the app and the widget extension (the widget includes this file
// through a folder exception in the project). Keep it free of app-only types.

// MARK: - Attributes

/// Live Activity for a running box-breathing session.
struct BreathingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "Breathe in", "Hold", "Breathe out".
        var phaseLabel: String
        /// 1-based cycle in progress.
        var cycle: Int
        var totalCycles: Int
        /// When the session ends if it keeps running. The system counts
        /// down to it, so the app does not update every second.
        var endDate: Date
        /// Time left, shown as a still value while paused.
        var secondsLeft: Int
        var isPaused: Bool
    }

    /// Session length in seconds.
    var sessionDuration: Int
}

// MARK: - Commands from the Live Activity

/// What a Live Activity button asks the running session to do. The intents
/// run in the app process, which forwards the command to the session.
enum BreathingActivityCommand: String, Sendable {
    case togglePause
    case end

    static let notification = Notification.Name("BreathingActivityCommand")
    static let userInfoKey = "command"

    @MainActor
    func post() {
        NotificationCenter.default.post(
            name: Self.notification,
            object: nil,
            userInfo: [Self.userInfoKey: rawValue]
        )
    }
}

struct ToggleBreathingPauseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or Resume Breathing"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        BreathingActivityCommand.togglePause.post()
        return .result()
    }
}

struct EndBreathingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End Breathing"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        BreathingActivityCommand.end.post()
        return .result()
    }
}
