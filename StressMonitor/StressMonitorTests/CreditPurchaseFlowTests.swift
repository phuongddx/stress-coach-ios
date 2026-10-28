import Foundation
import Testing
@testable import StressMonitor

// MARK: - Test doubles

/// `CreditServiceProtocol` double with call counters, pinned to the test
/// target per the MockAuthService convention (never ships in the app).
@MainActor
final class MockCreditService: CreditServiceProtocol {
    private(set) var balance: CreditBalance?
    private(set) var applyBalanceCallCount = 0
    private(set) var lastAppliedBalance: CreditBalance?

    init(balance: CreditBalance? = nil) {
        self.balance = balance
    }

    func refreshBalance() async throws {}

    func apply(_ balance: CreditBalance) {
        applyBalanceCallCount += 1
        lastAppliedBalance = balance
        self.balance = balance
    }

    func apply(creditsRemaining: Int) {}
}

/// StoreKit-shaped transaction fake so the redeem/finish ordering is
/// pinnable without a StoreKitTest session.
final class FakePurchaseTransaction: PurchaseTransactionHandle, @unchecked Sendable {
    let productID: String
    let jwsRepresentation: String
    let revocationDate: Date?
    let expirationDate: Date?
    private(set) var finishCallCount = 0

    init(
        productID: String,
        jwsRepresentation: String = "header.payload.signature",
        revocationDate: Date? = nil,
        expirationDate: Date? = nil
    ) {
        self.productID = productID
        self.jwsRepresentation = jwsRepresentation
        self.revocationDate = revocationDate
        self.expirationDate = expirationDate
    }

    func finish() async {
        finishCallCount += 1
    }
}

/// Records redeemer invocations and observes the transaction's finish count
/// at redeem time — the redeem-before-finish ordering probe.
@MainActor
final class RedemptionSpy {
    private(set) var callCount = 0
    private(set) var receivedJWS: [String] = []
    private(set) var finishCountAtRedeem: Int?
    var balance = CreditBalance(total: 60, used: 0, remaining: 60, planType: .free, freeResetAt: nil)
    var error: Error?

    func redeemer(_ jws: String, transaction: FakePurchaseTransaction) async throws -> CreditBalance {
        callCount += 1
        receivedJWS.append(jws)
        finishCountAtRedeem = transaction.finishCallCount
        if let error { throw error }
        return balance
    }
}

/// Records subscription-verify invocations (DEC-1 server-premium sync),
/// including the transaction's finish count at verify time — the
/// post-before-finish ordering probe for the demotion signal.
@MainActor
final class SubscriptionVerifySpy {
    private(set) var callCount = 0
    private(set) var receivedJWS: [String] = []
    private(set) var finishCountAtVerify: Int?
    var error: Error?

    func verifier(
        _ jws: String,
        transaction: FakePurchaseTransaction? = nil
    ) async throws -> CreditBalance {
        callCount += 1
        receivedJWS.append(jws)
        if let transaction { finishCountAtVerify = transaction.finishCallCount }
        if let error { throw error }
        return CreditBalance(total: 999_999, used: 0, remaining: 999_999, planType: .premium, freeResetAt: nil)
    }
}

// MARK: - Deferred-grant ordering pins (derived-CR-05 iOS half)

@MainActor
struct CreditPurchaseFlowTests {

    private static let smallPackID = "com.stressmonitor.app.credits.small"
    private static let monthlySubID = "com.stressmonitor.app.premium.monthly"

    private func makeCatalog() -> StoreKitProductCatalog {
        StoreKitProductCatalog(
            monthlyProductID: Self.monthlySubID,
            subscriptionGroupID: nil,
            smallPackProductID: Self.smallPackID,
            largePackProductID: "com.stressmonitor.app.credits.large"
        )
    }

    private func makeState() -> PremiumState {
        let defaults = UserDefaults(suiteName: "CreditPurchaseFlowTests-\(UUID().uuidString)")!
        return PremiumState(defaults: defaults, key: "isPremiumUser")
    }

    private func makeService(
        state: PremiumState,
        creditService: MockCreditService? = nil,
        redeemer: PurchaseRedeemer? = nil,
        subscriptionVerifier: PurchaseRedeemer? = nil
    ) -> StoreKitService {
        StoreKitService(
            premiumState: state,
            catalog: makeCatalog(),
            creditService: creditService ?? MockCreditService(),
            redeemer: redeemer,
            subscriptionVerifier: subscriptionVerifier
        )
    }

    // MARK: Pack path — deferred grant ordering

    @Test("Pack purchase redeems exactly once with the JWS before finish, then applies the balance")
    func packPurchaseRedeemsBeforeFinishAndAppliesBalance() async throws {
        let state = makeState()
        let creditService = MockCreditService()
        let fake = FakePurchaseTransaction(productID: Self.smallPackID, jwsRepresentation: "jws.small.pack")
        let spy = RedemptionSpy()
        let service = makeService(
            state: state,
            creditService: creditService,
            redeemer: { jws in try await spy.redeemer(jws, transaction: fake) }
        )

        try await service.completePurchase(fake, jwsRepresentation: fake.jwsRepresentation)

        #expect(spy.callCount == 1)
        #expect(spy.receivedJWS == ["jws.small.pack"])
        #expect(spy.finishCountAtRedeem == 0)
        #expect(fake.finishCallCount == 1)
        #expect(creditService.applyBalanceCallCount == 1)
        #expect(creditService.lastAppliedBalance == spy.balance)
        #expect(!state.isPremiumUser)
    }

    @Test("Redeem failure propagates and never finishes the transaction")
    func redeemFailureNeverFinishes() async throws {
        let creditService = MockCreditService()
        let fake = FakePurchaseTransaction(productID: Self.smallPackID)
        let spy = RedemptionSpy()
        spy.error = CreditsAPIError.invalidTransaction
        let service = makeService(
            state: makeState(),
            creditService: creditService,
            redeemer: { jws in try await spy.redeemer(jws, transaction: fake) }
        )

        await #expect(throws: CreditsAPIError.invalidTransaction) {
            try await service.completePurchase(fake, jwsRepresentation: fake.jwsRepresentation)
        }

        #expect(spy.callCount == 1)
        #expect(fake.finishCallCount == 0)
        #expect(creditService.applyBalanceCallCount == 0)
    }

    @Test("Revoked pack transaction is finished without any redemption attempt")
    func revokedPackFinishesWithoutRedemption() async throws {
        let creditService = MockCreditService()
        let fake = FakePurchaseTransaction(
            productID: Self.smallPackID,
            revocationDate: Date()
        )
        let spy = RedemptionSpy()
        let service = makeService(
            state: makeState(),
            creditService: creditService,
            redeemer: { jws in try await spy.redeemer(jws, transaction: fake) }
        )

        try await service.completePurchase(fake, jwsRepresentation: fake.jwsRepresentation)

        #expect(spy.callCount == 0)
        #expect(fake.finishCallCount == 1)
        #expect(creditService.applyBalanceCallCount == 0)
    }

    // MARK: Updates-listener path — same orchestration, retry semantics

    @Test("Updates-listener path routes a pack through the same redeem-before-finish ordering")
    func updatesListenerPackPathRedeemsBeforeFinish() async throws {
        let fake = FakePurchaseTransaction(productID: Self.smallPackID)
        let spy = RedemptionSpy()
        let service = makeService(
            state: makeState(),
            redeemer: { jws in try await spy.redeemer(jws, transaction: fake) }
        )

        await service.handle(transaction: fake, jwsRepresentation: fake.jwsRepresentation)

        #expect(spy.callCount == 1)
        #expect(spy.finishCountAtRedeem == 0)
        #expect(fake.finishCallCount == 1)
    }

    @Test("Updates-listener redeem failure leaves the transaction unfinished for redelivery")
    func updatesListenerFailureLeavesUnfinished() async throws {
        let fake = FakePurchaseTransaction(productID: Self.smallPackID)
        let spy = RedemptionSpy()
        spy.error = CreditsAPIError.server(statusCode: 500)
        let service = makeService(
            state: makeState(),
            redeemer: { jws in try await spy.redeemer(jws, transaction: fake) }
        )

        await service.handle(transaction: fake, jwsRepresentation: fake.jwsRepresentation)

        #expect(spy.callCount == 1)
        #expect(fake.finishCallCount == 0)
    }

    @Test("Updates-listener path finishes a revoked pack instead of retrying forever")
    func updatesListenerRevokedPackBreaksRetryLoop() async throws {
        let fake = FakePurchaseTransaction(
            productID: Self.smallPackID,
            revocationDate: Date()
        )
        let spy = RedemptionSpy()
        spy.error = CreditsAPIError.invalidTransaction
        let service = makeService(
            state: makeState(),
            redeemer: { jws in try await spy.redeemer(jws, transaction: fake) }
        )

        await service.handle(transaction: fake, jwsRepresentation: fake.jwsRepresentation)

        #expect(spy.callCount == 0)
        #expect(fake.finishCallCount == 1)
    }

    // MARK: Unverified deliveries are never finished (listener entry)

    @Test("An unverified transaction delivered through the listener entry is never finished")
    func unverifiedDeliveryNeverFinishesTransaction() async throws {
        let fake = FakePurchaseTransaction(productID: Self.smallPackID)
        let service = makeService(state: makeState())

        await service.handleUnverifiedTransaction(fake)

        #expect(fake.finishCallCount == 0)
    }

    @Test("A redelivered unverified transaction is still finished zero times")
    func redeliveredUnverifiedStillFinishedZeroTimes() async throws {
        let fake = FakePurchaseTransaction(productID: Self.smallPackID)
        let service = makeService(state: makeState())

        await service.handleUnverifiedTransaction(fake)
        await service.handleUnverifiedTransaction(fake)

        #expect(fake.finishCallCount == 0)
    }

    // MARK: Subscription path — legacy grant, no regression

    @Test("Subscription transaction takes the legacy grant path — immediate finish, no redemption, server verify")
    func subscriptionTakesLegacyPath() async throws {
        let state = makeState()
        let fake = FakePurchaseTransaction(productID: Self.monthlySubID, jwsRepresentation: "jws.sub.monthly")
        let redeemer = RedemptionSpy()
        let verifier = SubscriptionVerifySpy()
        let service = makeService(
            state: state,
            redeemer: { jws in try await redeemer.redeemer(jws, transaction: fake) },
            subscriptionVerifier: { jws in try await verifier.verifier(jws) }
        )

        try await service.completePurchase(fake, jwsRepresentation: fake.jwsRepresentation)

        #expect(redeemer.callCount == 0)
        #expect(verifier.callCount == 1)
        #expect(verifier.receivedJWS == ["jws.sub.monthly"])
        #expect(fake.finishCallCount == 1)
        #expect(state.isPremiumUser)
    }

    @Test("Subscription finish is not blocked by a server-verify failure")
    func subscriptionFinishSurvivesVerifyFailure() async throws {
        let state = makeState()
        let fake = FakePurchaseTransaction(productID: Self.monthlySubID)
        let verifier = SubscriptionVerifySpy()
        verifier.error = CreditsAPIError.server(statusCode: 404)
        let service = makeService(
            state: state,
            subscriptionVerifier: { jws in try await verifier.verifier(jws) }
        )

        try await service.completePurchase(fake, jwsRepresentation: fake.jwsRepresentation)

        #expect(verifier.callCount == 1)
        #expect(fake.finishCallCount == 1)
        #expect(state.isPremiumUser)
    }

    @Test("Expired subscription transaction finishes without granting premium")
    func expiredSubscriptionDoesNotGrant() async throws {
        let state = makeState()
        let fake = FakePurchaseTransaction(
            productID: Self.monthlySubID,
            expirationDate: Date.distantPast
        )
        let verifier = SubscriptionVerifySpy()
        let service = makeService(
            state: state,
            subscriptionVerifier: { jws in try await verifier.verifier(jws) }
        )

        try await service.completePurchase(fake, jwsRepresentation: fake.jwsRepresentation)

        #expect(fake.finishCallCount == 1)
        #expect(!state.isPremiumUser)
    }

    // MARK: Posting policy — a revoked JWS is a demotion signal; an expired JWS never reaches the server

    @Test("Revoked subscription transaction is posted as a demotion signal before finish, never grants premium")
    func revokedSubscriptionPostsDemotionSignalWithoutGranting() async throws {
        let state = makeState()
        let fake = FakePurchaseTransaction(
            productID: Self.monthlySubID,
            jwsRepresentation: "jws.sub.revoked",
            revocationDate: Date(),
            expirationDate: Date.distantFuture
        )
        let verifier = SubscriptionVerifySpy()
        let service = makeService(
            state: state,
            subscriptionVerifier: { jws in try await verifier.verifier(jws, transaction: fake) }
        )

        try await service.completePurchase(fake, jwsRepresentation: fake.jwsRepresentation)

        #expect(verifier.callCount == 1)
        #expect(verifier.receivedJWS == ["jws.sub.revoked"])
        #expect(verifier.finishCountAtVerify == 0)
        #expect(fake.finishCallCount == 1)
        #expect(!state.isPremiumUser)
    }

    @Test("Expired subscription transaction is never synced to the server and still finishes")
    func expiredSubscriptionNeverSyncs() async throws {
        let state = makeState()
        let fake = FakePurchaseTransaction(
            productID: Self.monthlySubID,
            expirationDate: Date.distantPast
        )
        let verifier = SubscriptionVerifySpy()
        let service = makeService(
            state: state,
            subscriptionVerifier: { jws in try await verifier.verifier(jws) }
        )

        try await service.completePurchase(fake, jwsRepresentation: fake.jwsRepresentation)

        #expect(verifier.callCount == 0)
        #expect(fake.finishCallCount == 1)
        #expect(!state.isPremiumUser)
    }
}
