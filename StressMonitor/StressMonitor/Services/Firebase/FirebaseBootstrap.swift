import FirebaseCore
import Foundation
import os

// MARK: - Firebase Bootstrap

/// Single entry point for `FirebaseApp.configure()`, exposing the outcome so
/// callers and tests can tell a configured build from a silently unconfigured
/// one. `GoogleService-Info.plist` is gitignored, so any build path that does
/// not recreate it produces a binary where anonymous auth, AI Chat, credits,
/// the IAP grant, and Google Sign-In are all dead with no visible signal.
enum FirebaseBootstrap {

    enum State: Equatable {
        case configured
        case missingConfiguration
    }

    private static let logger = Logger(subsystem: "com.stressmonitor.app", category: "FirebaseBootstrap")

    private(set) static var state: State = .missingConfiguration

    /// Configures Firebase when the bundled config is present. Missing config
    /// is recorded and logged, never fatal — a fresh checkout without the
    /// gitignored plist must still build and launch.
    @discardableResult
    static func bootstrap() -> State {
        // `FirebaseApp.configure()` traps on a second invocation.
        if FirebaseApp.app() != nil {
            state = .configured
            return state
        }

        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            state = .missingConfiguration
            logger.fault(
                """
                GoogleService-Info.plist is missing from the app bundle — Firebase is unconfigured, \
                so sign-in, AI Chat, credits, and purchases are all inert. \
                Restore the file by copying the per-app GoogleService-Info.plist into \
                StressMonitor/StressMonitor/ (gitignored by design).
                """
            )
            return state
        }

        FirebaseApp.configure()
        state = .configured
        return state
    }
}
