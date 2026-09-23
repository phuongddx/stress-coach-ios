import Foundation

// MARK: - Auth Service Errors

/// Failures raised by `AuthServiceProtocol` implementations. Kept distinct
/// from `LLMServiceError` so an authentication problem renders as a sign-in
/// message wherever it surfaces, rather than as an AI-availability failure.
enum AuthServiceError: Error, LocalizedError {
    case notConfigured
    case notSignedIn
    case googleSignInFailed(underlying: Error?)
    case appleSignInFailed(underlying: Error?)
    case accountDeletionFailed(underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Sign-in is unavailable in this build. Please update Ripple and try again."
        case .notSignedIn:
            return "Please sign in to continue."
        case .googleSignInFailed(let underlying):
            return underlying?.localizedDescription
                ?? "Google Sign-In could not be completed. Please try again."
        case .appleSignInFailed(let underlying):
            return underlying?.localizedDescription
                ?? "Sign in with Apple could not be completed. Please try again."
        case .accountDeletionFailed(let underlying):
            return underlying?.localizedDescription
                ?? "Your account could not be deleted. Please try again."
        }
    }
}
