import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

// MARK: - Auth Service Protocol

/// Abstraction over the Firebase authentication surface so the API client
/// and tests can substitute a non-Firebase double.
protocol AuthServiceProtocol: Sendable {
    var currentAccountEmail: String? { get }
    func signInAnonymously() async throws
    func getIDToken() async throws -> String
    func signOut() throws
    func signInWithGoogle(presenting viewController: UIViewController) async throws
    func signInWithApple(presenting viewController: UIViewController) async throws
}

// MARK: - Firebase Auth Service

/// Firebase Anonymous auth implementation. Anonymous sign-in is the default,
/// frictionless path (no UI); Google Sign-In is an upgrade path that links the
/// anonymous account to a persistent Google identity. `init` is deliberately
/// lazy — it does not touch `Auth.auth()` so the test host can construct this
/// type without a configured Firebase app.
@MainActor
final class FirebaseAuthService: AuthServiceProtocol, @unchecked Sendable {

    private let tokenRefreshMargin: TimeInterval = 60

    /// Apple's authorization code, kept so account deletion can revoke the
    /// Sign in with Apple token.
    fileprivate static let appleAuthorizationCodeKey = "appleAuthorizationCode"

    /// `ASAuthorizationController` holds its delegate weakly — retain the
    /// coordinator for the duration of one sign-in request.
    private var appleSignInCoordinator: AppleSignInCoordinator?

    nonisolated init() {}

    /// `Auth.auth()` traps with a fatal error when no FIRApp is configured —
    /// the state of any fresh checkout missing the gitignored
    /// GoogleService-Info.plist (CI runners). Every Auth access funnels
    /// through this check; unconfigured reads degrade exactly like a
    /// signed-out user instead of crashing the host.
    private var isFirebaseConfigured: Bool {
        FirebaseApp.app() != nil
    }

    // MARK: - AuthServiceProtocol

    var currentAccountEmail: String? {
        guard isFirebaseConfigured else { return nil }
        return Auth.auth().currentUser?.email
    }

    func signInAnonymously() async throws {
        guard isFirebaseConfigured else {
            throw AuthServiceError.notConfigured
        }
        if Auth.auth().currentUser != nil { return }
        let result = try await Auth.auth().signInAnonymously()
        _ = result.user
    }

    /// Returns a valid Firebase ID token, forcing a refresh when the cached
    /// token is within `tokenRefreshMargin` of expiry.
    func getIDToken() async throws -> String {
        guard isFirebaseConfigured, let user = Auth.auth().currentUser else {
            throw AuthServiceError.notSignedIn
        }

        let result = try await user.getIDTokenResult(forcingRefresh: false)
        if result.expirationDate > Date().addingTimeInterval(tokenRefreshMargin) {
            return result.token
        }
        return try await user.getIDToken(forcingRefresh: true)
    }

    func signOut() throws {
        guard isFirebaseConfigured else { return }
        try Auth.auth().signOut()
    }

    /// Google Sign-In upgrade path. Runs the Google OAuth flow, then links the
    /// returned credential to the current anonymous user so its credit balance
    /// and chat history are preserved across the upgrade. If the Google
    /// credential is already linked to another account (the user signed in on a
    /// different device), falls back to a plain `signIn(with:)` instead of
    /// discarding the existing anonymous data.
    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthServiceError.notConfigured
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        let result: GIDSignInResult = try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthServiceError.googleSignInFailed(underlying: nil))
                }
            }
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthServiceError.googleSignInFailed(underlying: nil)
        }
        let accessToken = result.user.accessToken.tokenString
        let credential = OAuthProvider.credential(
            withProviderID: "google.com",
            idToken: idToken,
            accessToken: accessToken
        )

        if let currentUser = Auth.auth().currentUser {
            do {
                _ = try await currentUser.link(with: credential)
                return
            } catch {
                guard (error as NSError).code == AuthErrorCode.credentialAlreadyInUse.rawValue else { throw error }
                _ = try await Auth.auth().signIn(with: credential)
                return
            }
        }
        _ = try await Auth.auth().signIn(with: credential)
    }

    // MARK: - Sign in with Apple

    /// Native Sign in with Apple. Same link-then-fallback shape as
    /// `signInWithGoogle`: link to the current (usually anonymous) user so
    /// credits and chat history survive the upgrade, and fall back to a plain
    /// sign-in when the Apple credential already belongs to another account.
    ///
    /// The authorization code is stored because Apple requires the token to be
    /// revoked when the account is deleted; it is cleared on deletion and on
    /// credential clearing.
    func signInWithApple(presenting viewController: UIViewController) async throws {
        guard isFirebaseConfigured else {
            throw AuthServiceError.notConfigured
        }

        let coordinator = AppleSignInCoordinator()
        appleSignInCoordinator = coordinator
        defer { appleSignInCoordinator = nil }

        let payload = try await coordinator.signIn(presenting: viewController)

        if let code = payload.authorizationCode {
            UserDefaults.standard.set(code, forKey: Self.appleAuthorizationCodeKey)
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: payload.identityToken,
            rawNonce: payload.rawNonce,
            fullName: nil
        )

        if let currentUser = Auth.auth().currentUser {
            do {
                _ = try await currentUser.link(with: credential)
                return
            } catch {
                guard (error as NSError).code == AuthErrorCode.credentialAlreadyInUse.rawValue else { throw error }
                _ = try await Auth.auth().signIn(with: credential)
                return
            }
        }
        _ = try await Auth.auth().signIn(with: credential)
    }

    // MARK: - Credential Clearing

    /// Signs out the current Firebase user and wipes the legacy Keychain
    /// accounts + UserDefaults keys left by the previous LLM stack so a
    /// returning user does not carry dead tokens across the migration. Called
    /// by data-deletion flows (factory reset, full account wipe).
    static func clearStoredCredentials() {
        if FirebaseApp.app() != nil { try? Auth.auth().signOut() }
        let service = "com.stressmonitor.app"
        for account in ["supabaseAccessToken", "supabaseRefreshToken"] {
            try? KeychainService.delete(service: service, account: account)
        }
        for key in ["supabaseSessionExpiresAt", "supabaseChatSessionId", appleAuthorizationCodeKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
