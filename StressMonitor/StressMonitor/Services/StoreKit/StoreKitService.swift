import Foundation
import os
import StoreKit

/// Minimal transaction surface the grant flow needs, abstracted so the
/// redeem-before-finish ordering is pinnable by unit tests without a
/// StoreKitTest session (whose suite is disabled for session-isolation
/// reasons — see StoreKitServiceTests.swift).
///
/// The signed JWS is deliberately NOT part of this surface: StoreKit 2
/// exposes it on `VerificationResult.jwsRepresentation`, not on
/// `Transaction`, so it travels as an explicit parameter alongside the
/// handle.
protocol PurchaseTransactionHandle: Sendable {
    var productID: String { get }
    var revocationDate: Date? { get }
    var expirationDate: Date? { get }
    func finish() async
}

extension Transaction: PurchaseTransactionHandle {}

/// Sends a signed purchase JWS to the backend and returns the
/// server-authoritative post-call balance.
typealias PurchaseRedeemer = @MainActor (String) async throws -> CreditBalance

@MainActor
final class StoreKitService: StoreKitServiceProtocol {

    private let premiumState: PremiumState
    private let catalog: StoreKitProductCatalog
    private let creditService: CreditServiceProtocol?
    private let redeemer: PurchaseRedeemer
    private let subscriptionVerifier: PurchaseRedeemer
    private var productsByID: [String: Product] = [:]
    private var transactionUpdatesTask: Task<Void, Never>?
    private static let logger = Logger(subsystem: "com.stressmonitor.app", category: "StoreKitService")

    // MARK: - Init / Deinit

    init(
        premiumState: PremiumState? = nil,
        catalog: StoreKitProductCatalog? = nil,
        creditService: CreditServiceProtocol? = nil,
        redeemer: PurchaseRedeemer? = nil,
        subscriptionVerifier: PurchaseRedeemer? = nil,
        availability: PurchaseAvailability = .current
    ) {
        self.premiumState = premiumState ?? .shared
        self.catalog = catalog ?? .live
        self.creditService = creditService
        let apiClient = StressAPIClient()
        self.redeemer = redeemer ?? { jws in try await apiClient.redeemPurchase(jws: jws) }
        self.subscriptionVerifier = subscriptionVerifier ?? { jws in try await apiClient.verifySubscription(jws: jws) }
        // While purchases are postponed the app offers no way to buy, so the
        // transaction listener and the entitlement refresh would only query
        // products that do not exist in App Store Connect. Flipping
        // `PurchaseAvailability.current` back to `.enabled` restores both.
        guard availability == .enabled else { return }
        self.transactionUpdatesTask = listenForTransactions()
        Task { await refreshEntitlements() }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    // MARK: - StoreKitServiceProtocol

    var availablePlans: [SubscriptionPlan] {
        get async {
            let productIDs = catalog.allProductIDs
            guard !productIDs.isEmpty else {
                // No product IDs configured — return fallback display plans.
                return SubscriptionPlan.defaultPlans
            }

            do {
                let products = try await Product.products(for: Array(productIDs))
                guard !products.isEmpty else {
                    return SubscriptionPlan.defaultPlans
                }

                // Cache products by ID
                for product in products {
                    productsByID[product.id] = product
                }

                // Map to SubscriptionPlan, sorted annual first, then monthly, then weekly
                var plans = products.compactMap { [catalog] product -> SubscriptionPlan? in
                    guard let period = catalog.period(for: product.id) else { return nil }
                    return Self.planFromProduct(product, period: period, catalog: catalog)
                }
                .sorted { lhs, rhs in
                    Self.periodSortOrder(lhs.period) < Self.periodSortOrder(rhs.period)
                }

                // Real savings, not a hardcoded guess — needs both prices loaded
                // together, which is only true here, after all products fetched.
                if let monthly = plans.first(where: { $0.period == .monthly }),
                   let annualIndex = plans.firstIndex(where: { $0.period == .annual }),
                   monthly.pricePerMonth > 0 {
                    let annualPricePerMonth = plans[annualIndex].pricePerMonth
                    let savings = (monthly.pricePerMonth - annualPricePerMonth) / monthly.pricePerMonth
                    let percent = Int((savings as NSDecimalNumber).doubleValue * 100)
                    if percent > 0 {
                        plans[annualIndex].savingsPercent = percent
                    }
                }

                return plans.isEmpty ? SubscriptionPlan.defaultPlans : plans
            } catch {
                // Fetch failed — return fallback display plans.
                // Purchases will still fail clearly since no cached product exists.
                return SubscriptionPlan.defaultPlans
            }
        }
    }

    var isPremiumUser: Bool {
        premiumState.isPremiumUser
    }

    /// Pack catalog with locale-correct prices when the StoreKit products
    /// resolve; the DEC-2 display packs otherwise (mirrors `availablePlans`).
    var availablePacks: [CreditPack] {
        get async {
            let packIDs = CreditPackID.allCases.compactMap { catalog.packID(for: $0) }
            guard !packIDs.isEmpty else { return CreditPack.defaultPacks }

            do {
                let products = try await Product.products(for: packIDs)
                guard !products.isEmpty else { return CreditPack.defaultPacks }

                for product in products {
                    productsByID[product.id] = product
                }

                return CreditPackID.allCases.map { id in
                    let fallback = CreditPack.defaultPacks.first { $0.id == id } ?? CreditPack.defaultPacks[0]
                    guard let productID = catalog.packID(for: id),
                          let product = products.first(where: { $0.id == productID }) else {
                        return fallback
                    }
                    return Self.packFromProduct(product, id: id, fallback: fallback)
                }
            } catch {
                return CreditPack.defaultPacks
            }
        }
    }

    func purchase(_ plan: SubscriptionPlan) async throws {
        // 1. Resolve product ID
        let productID = plan.productID ?? catalog.productID(for: plan.period)
        guard let productID else {
            throw StoreKitError.missingProductConfiguration
        }

        // 2–3. Shared purchase steps (fetch/cache product, run purchase sheet)
        let result = try await purchaseProduct(resolving: productID)

        // 4. Handle result
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            try await completePurchase(transaction, jwsRepresentation: verification.jwsRepresentation)
            await refreshEntitlements()

        case .userCancelled:
            throw StoreKitError.purchaseCancelled

        case .pending:
            throw StoreKitError.purchasePending

        @unknown default:
            throw StoreKitError.purchaseFailed
        }
    }

    func purchase(pack: CreditPack) async throws {
        // 1. Resolve product ID
        let productID = pack.productID ?? catalog.packID(for: pack.id)
        guard let productID else {
            throw StoreKitError.missingProductConfiguration
        }

        // 2–3. Shared purchase steps (fetch/cache product, run purchase sheet)
        let result = try await purchaseProduct(resolving: productID)

        // 4. Handle result — deferred grant: the server redeems the signed
        // transaction and only the server's ack finishes it (see
        // completePurchase). A crash before the ack leaves the transaction
        // unfinished, so Transaction.updates redelivers and retries.
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            try await completePurchase(transaction, jwsRepresentation: verification.jwsRepresentation)

        case .userCancelled:
            throw StoreKitError.purchaseCancelled

        case .pending:
            throw StoreKitError.purchasePending

        @unknown default:
            throw StoreKitError.purchaseFailed
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
        if !premiumState.isPremiumUser {
            throw StoreKitError.noActiveSubscription
        }
    }

    func fetchPurchaseHistory() async -> [String] {
        var entries: [String] = []
        for await result in Transaction.all {
            switch result {
            case .verified(let transaction):
                let productID = transaction.productID
                let date = transaction.purchaseDate.formatted(date: .abbreviated, time: .shortened)
                var entry = "\(productID) — \(date)"
                if let exp = transaction.expirationDate {
                    entry += " (expires: \(exp.formatted(date: .abbreviated, time: .shortened)))"
                }
                if let rev = transaction.revocationDate {
                    entry += " (revoked: \(rev.formatted(date: .abbreviated, time: .shortened)))"
                }
                entries.append(entry)
            case .unverified:
                break
            }
        }
        return entries
    }

    func refreshEntitlements() async {
        var hasActive = false

        // 1. Check current entitlements
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                // Only consider known products
                guard catalog.period(for: transaction.productID) != nil else { continue }

                // Active if not revoked and not expired
                let notRevoked = transaction.revocationDate == nil
                let notExpired = transaction.expirationDate.map { $0 > Date() } ?? true

                if notRevoked && notExpired {
                    hasActive = true
                    // DEC-1: re-sync server-side premium from the durable
                    // entitlement source; fire-and-forget so a foreground
                    // refresh never blocks on the network.
                    Task {
                        await self.syncSubscriptionEntitlementToServer(
                            transaction,
                            jwsRepresentation: result.jwsRepresentation
                        )
                    }
                }
            case .unverified:
                break
            }
        }

        // 2. Check subscription group status if configured
        if let groupID = catalog.subscriptionGroupID {
            do {
                let statuses = try await Product.SubscriptionInfo.status(for: groupID)
                for status in statuses {
                    switch status.state {
                    case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
                        hasActive = true
                    case .expired, .revoked:
                        break
                    default:
                        break
                    }
                }
            } catch {
                // Subscription status check failed — rely on entitlement check above
            }
        }

        premiumState.isPremiumUser = hasActive
    }

    func isEligibleForIntroOffer(for period: SubscriptionPeriod) async -> Bool {
        guard let productID = catalog.productID(for: period) else { return false }
        let product: Product?
        if let cached = productsByID[productID] {
            product = cached
        } else {
            product = (try? await Product.products(for: [productID]))?.first
        }
        guard let product else { return false }
        guard let subscription = product.subscription else { return false }
        return await subscription.isEligibleForIntroOffer
    }

    // MARK: - Transaction listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionVerification: result)
            }
        }
    }

    /// Updates-listener entry — routes each `Transaction.updates` delivery.
    ///
    /// Finish-site reachability audit (all five finish sites in this
    /// service): the four `completePurchase` finishes — the revoked-pack
    /// arm, the pack-after-redeem arm, the revoked-subscription arm, and
    /// the subscription tail — execute only for verified transactions, by
    /// construction. `purchase(_:)` and `purchase(pack:)` run
    /// `checkVerified` first and throw on `.unverified` before
    /// `completePurchase` is ever reached, and
    /// `handle(transaction:jwsRepresentation:)` is reached only from the
    /// `.verified` case below. Those four finishes are intentional queue
    /// hygiene (clearing revoked/refunded/legacy-subscription transactions
    /// so the queue drains) and are pinned by `CreditPurchaseFlowTests`.
    /// The fifth site was this entry's own `.unverified` branch, which
    /// finished — and thereby destroyed — the only consumable proof of
    /// purchase; it now ignores without finishing
    /// (`handleUnverifiedTransaction`).
    private func handle(transactionVerification result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            await handle(transaction: transaction, jwsRepresentation: result.jwsRepresentation)

        case .unverified(let transaction, _):
            await handleUnverifiedTransaction(transaction)
        }
    }

    /// `.unverified` branch of the updates-listener entry, extracted
    /// protocol-typed so unit tests can drive it with a fake transaction —
    /// `VerificationResult<Transaction>` itself cannot be constructed in
    /// tests (no public `Transaction` initializer).
    ///
    /// No grant occurs for an unverified payload, and no finish either: a
    /// finished unverified consumable is gone forever, destroying the only
    /// proof of purchase the server redeem path needs. Leaving it
    /// unfinished makes `Transaction.updates` redeliver it — the same
    /// retry contract `handle(transaction:jwsRepresentation:)` documents.
    /// This mirrors Apple's canonical observer sample, which ignores
    /// unverified transactions without finishing them, and the in-file
    /// `.unverified: break` arms of `fetchPurchaseHistory()` and
    /// `refreshEntitlements()`.
    func handleUnverifiedTransaction(_ transaction: any PurchaseTransactionHandle) async {
        Self.logger.warning(
            "Ignoring unverified transaction (\(transaction.productID, privacy: .public)) — left unfinished for Transaction.updates redelivery"
        )
    }

    // MARK: - Grant orchestration

    /// Steps 2–3 shared by both purchase entry points: fetch/cache the
    /// product, then run the purchase sheet with the iOS 18.2 scene variant.
    private func purchaseProduct(resolving productID: String) async throws -> Product.PurchaseResult {
        let product: Product
        if let cached = productsByID[productID] {
            product = cached
        } else {
            let fetched = try await Product.products(for: [productID])
            guard let first = fetched.first else {
                throw StoreKitError.productNotFound
            }
            product = first
            productsByID[product.id] = product
        }

        if #available(iOS 18.2, *),
           let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first {
            return try await product.purchase(confirmIn: scene)
        }
        return try await product.purchase()
    }

    /// Unified grant choke point for a verified transaction — both
    /// `purchase(...)` entry points and the `Transaction.updates` listener
    /// route through here. Grant/finish ordering ONLY — the authoritative
    /// `refreshEntitlements()` correction stays at the calling entry points
    /// so this orchestration remains unit-pinnable without StoreKit state.
    ///
    /// Pack productIDs use the deferred grant: the backend redeems the JWS
    /// BEFORE `finish()`, because a finished consumable is gone forever — an
    /// unfinished one is redelivered and retried. A refunded (revoked) pack
    /// is finished WITHOUT any redemption — the server permanently rejects
    /// its JWS, and retrying it would wedge the transaction queue forever.
    /// Subscription productIDs
    /// keep the legacy immediate finish (restorable via currentEntitlements)
    /// plus a best-effort server premium sync (DEC-1). Posting policy, in
    /// evaluation order: a revoked (refunded) subscription JWS IS posted —
    /// as a demotion signal the server shortens premium_until with, never
    /// an activation — and never grants or clears local premium
    /// (`refreshEntitlements` stays the sole local corrector, so a user
    /// holding a different still-active subscription keeps it). An expired
    /// JWS is never posted. Both are still finished so the queue clears.
    func completePurchase(
        _ transaction: any PurchaseTransactionHandle,
        jwsRepresentation: String
    ) async throws {
        if catalog.pack(for: transaction.productID) != nil {
            if transaction.revocationDate != nil {
                // Refunded pack: already-granted credits are intentionally
                // left in place (no clawback) — the fix's contract is queue
                // hygiene, and the server rejects this JWS permanently.
                await transaction.finish()
                return
            }
            let balance = try await redeemer(jwsRepresentation)
            await transaction.finish()
            creditService?.apply(balance)
            return
        }

        let isKnownSubscription = catalog.period(for: transaction.productID) != nil

        if isKnownSubscription && transaction.revocationDate != nil {
            await syncSubscriptionEntitlementToServer(transaction, jwsRepresentation: jwsRepresentation)
            await transaction.finish()
            return
        }

        let isActive = isKnownSubscription &&
            transaction.revocationDate == nil &&
            (transaction.expirationDate.map { $0 > Date() } ?? true)

        if isActive {
            await syncSubscriptionEntitlementToServer(transaction, jwsRepresentation: jwsRepresentation)
            premiumState.isPremiumUser = true
        }

        await transaction.finish()
    }

    /// Updates-listener entry: identical ordering to the purchase path, but
    /// a redemption failure must NOT propagate — the transaction stays
    /// unfinished so StoreKit redelivers it and the grant retries.
    func handle(
        transaction: any PurchaseTransactionHandle,
        jwsRepresentation: String
    ) async {
        do {
            try await completePurchase(transaction, jwsRepresentation: jwsRepresentation)
        } catch {
            // Leave unfinished — redelivery through Transaction.updates is
            // the crash/failure retry path for consumables.
        }
        await refreshEntitlements()
    }

    /// Best-effort mirror of a subscription transaction into server-side
    /// premium (DEC-1). Never blocks the caller's success path on server
    /// state — a subscription is re-derivable from
    /// `Transaction.currentEntitlements`, unlike a consumable, so a later
    /// foreground refresh re-runs this.
    private func syncSubscriptionEntitlementToServer(
        _ transaction: any PurchaseTransactionHandle,
        jwsRepresentation: String
    ) async {
        do {
            _ = try await subscriptionVerifier(jwsRepresentation)
        } catch {
            // Endpoint absence or a network failure converges on the next
            // refresh; the local grant below still proceeds.
        }
    }

    // MARK: - Helpers

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreKitError.receiptValidationFailed
        }
    }

    private static func planFromProduct(
        _ product: Product,
        period: SubscriptionPeriod,
        catalog: StoreKitProductCatalog
    ) -> SubscriptionPlan {
        let pricePerPeriod = product.price ?? .zero
        // Months per billing cycle for pricePerMonth normalization
        let months: Decimal
        switch period {
        case .annual:  months = 12
        case .monthly: months = 1
        case .weekly:  months = 12.0 / 52.0  // ~0.23 months per week
        }
        let pricePerMonth = pricePerPeriod / months

        let isAnnual = period == .annual
        let billingSummary: String? = {
            switch period {
            case .annual:  return "Billed annually"
            case .monthly: return "Billed monthly"
            case .weekly:  return "Billed weekly"
            }
        }()

        // Computed after all products load — see availablePlans. A lone
        // product (e.g. only the annual tier configured) leaves this nil,
        // which is honest; a hardcoded guess here was not.
        let savingsPercent: Int? = nil

        return SubscriptionPlan(
            id: period,
            displayName: product.displayName,
            pricePerMonth: NSDecimalNumber(decimal: pricePerMonth) as Decimal,
            pricePerPeriod: pricePerPeriod,
            period: period,
            savingsPercent: savingsPercent,
            isBestValue: isAnnual,
            subtitle: isAnnual ? "Best value option" : nil,
            productID: product.id,
            displayPrice: product.displayPrice,
            billingSummary: billingSummary,
            hasIntroductoryOffer: product.subscription?.introductoryOffer != nil,
            introOfferPeriodUnit: Self.introOfferPeriodUnit(from: product)
        )
    }

    /// Display sort order: annual (0) -> monthly (1) -> weekly (2).
    private static func periodSortOrder(_ period: SubscriptionPeriod) -> Int {
        switch period {
        case .annual:  0
        case .monthly: 1
        case .weekly:  2
        }
    }

    private static func packFromProduct(
        _ product: Product,
        id: CreditPackID,
        fallback: CreditPack
    ) -> CreditPack {
        CreditPack(
            id: id,
            credits: fallback.credits,
            displayName: product.displayName.isEmpty ? fallback.displayName : product.displayName,
            productID: product.id,
            displayPrice: product.displayPrice,
            pricePerPack: product.price
        )
    }

    private static func introOfferPeriodUnit(from product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer else { return nil }
        let value = offer.period.value
        switch offer.period.unit {
        case .day:   return "\(value)-day"
        case .week:  return "\(value * 7)-day"
        case .month: return "\(value)-month"
        case .year:  return "\(value)-year"
        @unknown default: return nil
        }
    }
}
