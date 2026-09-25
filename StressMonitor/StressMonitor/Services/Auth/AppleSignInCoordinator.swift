import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

// MARK: - Apple Sign-In Result

/// The three values Firebase needs to build an Apple OAuth credential, plus
/// the authorization code Apple requires for token revocation at deletion
/// time (Guideline 5.1.1(v) — a deleted Sign in with Apple account must also
/// have its token revoked).
struct AppleSignInPayload: Sendable {
    let identityToken: String
    let rawNonce: String
    let authorizationCode: String?
    let email: String?
}

// MARK: - Apple Sign-In Coordinator

/// Bridges `ASAuthorizationController`'s delegate callbacks into async/await.
/// Held for the lifetime of one request: `ASAuthorizationController` keeps only
/// weak references, so the caller must retain this object until it resumes.
@MainActor
final class AppleSignInCoordinator: NSObject {

    private var continuation: CheckedContinuation<AppleSignInPayload, Error>?
    private var rawNonce: String?
    private weak var presenter: UIViewController?

    /// Runs the native Apple sign-in sheet and returns the credential payload.
    func signIn(presenting viewController: UIViewController) async throws -> AppleSignInPayload {
        let nonce = Self.randomNonce()
        rawNonce = nonce
        presenter = viewController

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email]
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    /// `ASAuthorizationError.canceled` — the user dismissed the sheet, which is
    /// not an error worth surfacing (mirrors `GoogleSignInCancellation`).
    static func isUserCancellation(_ error: Error) -> Bool {
        (error as? ASAuthorizationError)?.code == .canceled
    }

    // MARK: - Nonce

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        for _ in 0..<length {
            result.append(charset[Int.random(in: 0..<charset.count)])
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        let identityToken = credential?.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        let authorizationCode = credential?.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        let email = credential?.email

        Task { @MainActor in
            guard let continuation = self.continuation else { return }
            self.continuation = nil
            guard let identityToken, let rawNonce = self.rawNonce else {
                continuation.resume(throwing: AuthServiceError.appleSignInFailed(underlying: nil))
                return
            }
            continuation.resume(returning: AppleSignInPayload(
                identityToken: identityToken,
                rawNonce: rawNonce,
                authorizationCode: authorizationCode,
                email: email
            ))
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            guard let continuation = self.continuation else { return }
            self.continuation = nil
            continuation.resume(throwing: error)
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {

    nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            presenter?.view.window ?? UIWindow()
        }
    }
}
