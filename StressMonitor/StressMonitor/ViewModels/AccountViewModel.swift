import UIKit

@MainActor
@Observable
final class AccountViewModel {

    var linkedEmail: String?
    var isSigningIn = false
    var isDeletingAccount = false
    var errorMessage: String?

    private let authService: AuthServiceProtocol
    private let accountAPI: AccountDeleting

    init(
        authService: AuthServiceProtocol = FirebaseAuthService(),
        accountAPI: AccountDeleting? = nil
    ) {
        self.authService = authService
        self.accountAPI = accountAPI ?? StressAPIClient(authService: authService)
    }

    func refreshAccountState() {
        linkedEmail = authService.currentAccountEmail
    }

    /// Sign in with Apple — offered alongside Google so the app is not
    /// dependent on a single third-party login (Guideline 4.8).
    func signInWithApple(presenting viewController: UIViewController) async throws {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }

        do {
            try await authService.signInWithApple(presenting: viewController)
            refreshAccountState()
        } catch {
            errorMessage = AppleSignInCoordinator.isUserCancellation(error)
                ? nil
                : error.localizedDescription
            throw error
        }
    }

    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }

        do {
            try await authService.signInWithGoogle(presenting: viewController)
            refreshAccountState()
        } catch {
            errorMessage = GoogleSignInCancellation.isUserCancellation(error)
                ? nil
                : error.localizedDescription
            throw error
        }
    }

    // MARK: - Account Deletion

    /// In-app account deletion (App Review Guideline 5.1.1(v)).
    ///
    /// Calls `DELETE /account`, then signs out and clears stored credentials
    /// so the deleted session cannot be reused, and sends the app back to
    /// onboarding. Returns `true` only when the backend accepted the request.
    func deleteAccount() async -> Bool {
        guard !isDeletingAccount else { return false }
        isDeletingAccount = true
        errorMessage = nil
        defer { isDeletingAccount = false }

        do {
            try await accountAPI.deleteAccount()
        } catch {
            errorMessage = error.localizedDescription
            return false
        }

        FirebaseAuthService.clearStoredCredentials()
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        linkedEmail = nil
        return true
    }
}

enum GoogleSignInCancellation {
    static func isUserCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "com.google.GIDSignIn" && nsError.code == -5
    }
}
