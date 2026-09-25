import Foundation
import Testing
import UIKit
@testable import StressMonitor

/// Test double for `AuthServiceProtocol`, pinned to the test target so it
/// never ships in the Release app (threat T-03-01). Returns a fixed token so
/// `StressAPIClient.authorizedRequest` can be asserted without a live Firebase
/// session, and records sign-out / sign-in calls for the FirebaseAuthService
/// seam test. Reused by `FirebaseAuthServiceTests` — do not duplicate.
final class MockAuthService: AuthServiceProtocol, @unchecked Sendable {
    let token: String
    let googleSignInError: Error?
    var email: String?
    private(set) var signOutCallCount = 0
    private(set) var anonymousSignInCallCount = 0
    private(set) var tokenCallCount = 0
    private(set) var googleSignInCallCount = 0
    private(set) var appleSignInCallCount = 0
    private(set) var lastPresentingViewController: UIViewController?

    init(
        token: String = "fake-token",
        googleSignInError: Error? = AuthServiceError.googleSignInFailed(underlying: nil),
        email: String? = nil
    ) {
        self.token = token
        self.googleSignInError = googleSignInError
        self.email = email
    }

    func signInAnonymously() async throws {
        anonymousSignInCallCount += 1
    }

    func getIDToken() async throws -> String {
        tokenCallCount += 1
        return token
    }

    var currentAccountEmail: String? {
        email
    }

    func signOut() throws {
        signOutCallCount += 1
    }

    func signInWithGoogle(presenting viewController: UIViewController) async throws {
        googleSignInCallCount += 1
        lastPresentingViewController = viewController
        try await Task.sleep(nanoseconds: 50_000_000)
        if let googleSignInError { throw googleSignInError }
    }

    func signInWithApple(presenting viewController: UIViewController) async throws {
        appleSignInCallCount += 1
        lastPresentingViewController = viewController
    }
}

/// Stub `URLProtocol` that captures the outgoing request and returns a stubbed
/// status/body so `StressAPIClient`'s header and decoding behavior can be
/// asserted without hitting the network. Reset `lastRequest` (and set
/// `statusCode` / `responseBody`) before each test that inspects them.
///
/// Multi-request flows set `responseByPath` (keyed by URL path) so several
/// endpoints can be stubbed in one test; while it is non-nil it takes
/// precedence over `statusCode` / `responseBody`. `capturedRequests`
/// accumulates every request in dispatch order for ordering assertions —
/// reset both alongside the single-response statics.
final class RequestCaptureURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var statusCode: Int = 200
    nonisolated(unsafe) static var responseBody: Data?
    /// Per-request statuses consumed in dispatch order (overlapping-request
    /// tests); empty by default. Takes precedence over the single
    /// `statusCode`, but not over `responseByPath`.
    nonisolated(unsafe) static var statusCodeSequence: [Int] = []
    nonisolated(unsafe) static var responseByPath: [String: (statusCode: Int, body: Data?)]?
    nonisolated(unsafe) static var capturedRequests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        Self.capturedRequests.append(request)
        let stub: (statusCode: Int, body: Data?)
        if let responseByPath = Self.responseByPath,
           let pathStub = responseByPath[request.url?.path ?? ""] {
            stub = pathStub
        } else if !Self.statusCodeSequence.isEmpty {
            stub = (Self.statusCodeSequence.removeFirst(), Self.responseBody ?? Data())
        } else {
            stub = (Self.statusCode, Self.responseBody ?? Data())
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
struct StressAPIClientTests {

    private func makeClient(token: String = "fake-token") -> StressAPIClient {
        StressAPIClient(
            authService: MockAuthService(token: token),
            baseURL: URL(string: "https://api.test")!
        )
    }

    // MARK: - authorizedRequest — Bearer token injection (D-03 contract)

    @Test("authorizedRequest injects the auth service token as a Bearer header")
    func authorizedRequestInjectsBearerToken() async throws {
        let client = makeClient(token: "fake-token")
        let request = try await client.authorizedRequest(path: "chat", method: "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fake-token")
    }

    @Test("authorizedRequest sets Content-Type to application/json")
    func authorizedRequestSetsContentType() async throws {
        let client = makeClient()
        let request = try await client.authorizedRequest(path: "chat", method: "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test("authorizedRequest propagates the supplied HTTP method")
    func authorizedRequestPropagatesMethod() async throws {
        let client = makeClient()
        let request = try await client.authorizedRequest(path: "chat", method: "POST")
        #expect(request.httpMethod == "POST")
    }

    @Test("authorizedRequest attaches the body Data when provided")
    func authorizedRequestAttachesBody() async throws {
        let client = makeClient()
        let body = Data([0x01, 0x02, 0x03])
        let request = try await client.authorizedRequest(path: "chat", method: "POST", body: body)
        #expect(request.httpBody == body)
    }

    @Test("authorizedRequest targets baseURL + path")
    func authorizedRequestTargetsBaseURLPlusPath() async throws {
        let client = makeClient()
        let request = try await client.authorizedRequest(path: "chat", method: "POST")
        #expect(request.url?.absoluteString == "https://api.test/chat")
    }

    @Test("authorizedRequest sets Accept when provided (SSE streaming)")
    func authorizedRequestSetsAcceptWhenProvided() async throws {
        let client = makeClient()
        let request = try await client.authorizedRequest(path: "chat", method: "POST", accept: "text/event-stream")
        #expect(request.value(forHTTPHeaderField: "Accept") == "text/event-stream")
    }

    // MARK: - getHealth — public, no auth (D-03: /health is the unauthed endpoint)

    @Test("getHealth sends no Authorization header to /health")
    func getHealthSendsNoAuthorizationHeader() async throws {
        RequestCaptureURLProtocol.lastRequest = nil
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RequestCaptureURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = StressAPIClient(
            authService: MockAuthService(token: "should-not-appear"),
            session: session
        )
        _ = try await client.getHealth()
        let captured = RequestCaptureURLProtocol.lastRequest
        #expect(captured?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    // MARK: - HTTP error mapping (D-07: 402 → insufficientCredits)
    // The mapper lives on StressLLMService (the streaming consumer that owns
    // the error contract), invoked after StressAPIClient surfaces the status
    // code in the HTTPURLResponse. Exposed as an internal static seam so the
    // status-code → error-case table is asserted without a URLSession stub.

    @Test("HTTP 402 maps to insufficientCredits, not .unavailable")
    func maps402ToInsufficientCredits() {
        let error = StressLLMService.mapHTTPError(402)
        guard case .insufficientCredits = error else {
            Issue.record("expected .insufficientCredits for 402, got \(String(describing: error))")
            return
        }
        #expect(Bool(true))
    }

    @Test("HTTP 401 maps to unavailable with a sign-in reason")
    func maps401ToUnavailable() {
        let error = StressLLMService.mapHTTPError(401)
        guard case .unavailable = error else {
            Issue.record("expected .unavailable for 401, got \(String(describing: error))")
            return
        }
        #expect(Bool(true))
    }

    @Test("HTTP 429 maps to rateLimited")
    func maps429ToRateLimited() {
        let error = StressLLMService.mapHTTPError(429)
        guard case .rateLimited = error else {
            Issue.record("expected .rateLimited for 429, got \(String(describing: error))")
            return
        }
        #expect(Bool(true))
    }

    @Test("HTTP 2xx maps to nil (no error)")
    func maps2xxToNil() {
        #expect(StressLLMService.mapHTTPError(200) == nil)
        #expect(StressLLMService.mapHTTPError(204) == nil)
    }
}
