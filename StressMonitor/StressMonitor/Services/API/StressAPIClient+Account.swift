import Foundation

// MARK: - Account API Errors

/// Typed errors for the account endpoints. `.unauthorized` mirrors the probe
/// the credits and sessions endpoints use — a stale session must surface, not
/// be mistaken for a completed deletion.
enum AccountAPIError: Error, LocalizedError, Equatable, Sendable {
    case unauthorized
    case invalidResponse
    case server(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in again to delete your account."
        case .invalidResponse:
            return "Couldn't delete your account (invalid server response)."
        case .server(let statusCode):
            return "Couldn't delete your account (server error \(statusCode))."
        }
    }
}

// MARK: - Account Deleting

/// The one call the deletion flow makes against the backend. Split from
/// `StressAPIClient` so `AccountDeletionService` can be tested without a
/// URLSession.
protocol AccountDeleting: Sendable {
    func deleteAccount() async throws
}

// MARK: - StressAPIClient + Account

extension StressAPIClient: AccountDeleting {

    /// `DELETE /account` — the backend acknowledges the deletion request for
    /// the authenticated uid.
    ///
    /// Only 2xx counts as success. A 404 is *not* treated as "already gone":
    /// the backend answers unknown paths with `404 {"error":"Not found"}`, so
    /// swallowing it would report a successful deletion against any deployment
    /// that does not carry this route yet.
    func deleteAccount() async throws {
        let request = try await authorizedRequest(path: "account", method: "DELETE")
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AccountAPIError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw AccountAPIError.unauthorized
        default:
            throw AccountAPIError.server(statusCode: httpResponse.statusCode)
        }
    }
}
