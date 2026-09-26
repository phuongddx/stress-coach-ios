import FirebaseAuth
import os
import SwiftData
import SwiftUI

#if DEBUG
enum DemoMode {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-demo-mode")
}

/// WR-03: DEBUG-only opt-in for the mocked IAP money path. Launch with
/// `-mock-iap` (Edit Scheme → Run → Arguments) to route purchases through
/// `MockStoreKitService`; DEBUG builds otherwise exercise the REAL StoreKit
/// path at both wiring sites. Release builds exclude the mock at compile
/// time (`#if DEBUG` on MockStoreKitService), so the opt-in is inert there.
enum MockIAPMode {
    static let launchArgument = "-mock-iap"

    /// `arguments` is injectable so the wiring pin suite
    /// (StoreKitServiceWiringTests) can drive both resolution outcomes —
    /// a test process cannot change its own launch arguments. Production
    /// callers use the process's own arguments (DemoMode precedent).
    static func isEnabled(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(launchArgument)
    }
}
#endif

@main
struct StressMonitorApp: App {
    // Central navigation + paywall state. Owned here so they are available to
    // every scene, tab, sheet, and the root full-screen paywall cover.
    @State private var appRouter = AppRouter()
    @State private var paywall = PaywallController()
    // Owned once for the app's process lifetime so the Transaction.updates
    // listener started in its init runs the whole time, not just while the
    // paywall happens to be on screen. See StoreKitServiceEnvironment.swift.
    // Built in `init` so it can hold the app-scope `CreditService` — every
    // server grant (purchase path and Transaction.updates redelivery) then
    // converges the same balance instance the UI displays.
    @State private var storeKitService: StoreKitServiceProtocol
    /// App-scope credit balance cache: paywall + chat surfaces read this one
    /// instance so every convergence source updates the same displayed value.
    @State private var creditService: CreditService
    /// App-scope AI-coach preference pair (language + coaching style): the
    /// Settings pickers and the stress-context payload read this one instance
    /// so every surface converges on the same seeded state.
    @State private var preferencesService = PreferencesService()
    @Environment(\.scenePhase) private var scenePhase
    // MARK: - Versioned Schema (V1 → V2 adds Habit)
    //
    // SwiftData can silently wipe an existing store on iOS 17.0–17.3 when the
    // model set changes without an explicit migration plan. We declare V1 (the
    // shipping schema through Phase 2) and V2 (adds Habit) plus a lightweight
    // stage so the on-disk store is migrated in place rather than reset.

    enum AppSchemaV1: VersionedSchema {
        static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

        static var models: [any PersistentModel.Type] {
            [StressMeasurement.self, CharacterUnlock.self]
        }

        static func modelProvider() -> Schema {
            Schema(models)
        }
    }

    enum AppSchemaV2: VersionedSchema {
        static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

        static var models: [any PersistentModel.Type] {
            [StressMeasurement.self, CharacterUnlock.self, Habit.self]
        }

        static func modelProvider() -> Schema {
            Schema(models)
        }
    }

    enum AppMigrationPlan: SchemaMigrationPlan {
        static var schemas: [any VersionedSchema.Type] {
            [AppSchemaV1.self, AppSchemaV2.self]
        }

        static var stages: [MigrationStage] {
            [MigrationStage.lightweight(fromVersion: AppSchemaV1.self, toVersion: AppSchemaV2.self)]
        }
    }

    static let schema: Schema = AppSchemaV2.modelProvider()

    static let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .automatic
    )

    private static let persistenceLogger = Logger(
        subsystem: "com.stressmonitor.app",
        category: "Persistence"
    )

    private static let appLogger = Logger(
        subsystem: "com.stressmonitor.app",
        category: "App"
    )

    var sharedModelContainer: ModelContainer = { makeContainer() }()

    // MARK: - ModelContainer Recovery

    /// Creates the app's ModelContainer. When `url` is nil the default Application
    /// Support location is used; tests pass an isolated URL under the temp dir.
    /// On a schema mismatch the on-disk store is deleted and the container is
    /// recreated without a migration plan (D5 = Option A: accept data loss).
    internal static func makeContainer(at url: URL? = nil) -> ModelContainer {
        do {
            let container = try makePrimaryContainer(at: url)
            seedDefaultCharacterUnlocks(in: container.mainContext)
            return container
        } catch {
            persistenceLogger.error("ModelContainer primary creation failed: \(error.localizedDescription). Recovering.")
            return makeRecoveredContainer(at: url)
        }
    }

    private static func makePrimaryContainer(at url: URL?) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: AppMigrationPlan.self,
            configurations: [makeConfiguration(at: url)]
        )
    }

    private static func makeRecoveredContainer(at url: URL?) -> ModelContainer {
        let storeURL = resolvedStoreURL(for: url)
        removeStoreFiles(at: storeURL)

        let recoveryConfig: ModelConfiguration
        if let url {
            recoveryConfig = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            recoveryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        }

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [recoveryConfig]
            )
            seedDefaultCharacterUnlocks(in: container.mainContext)
            persistenceLogger.notice("Recovered ModelContainer (local-only) after deleting incompatible store.")
            return container
        } catch {
            persistenceLogger.fault("Recovery failed: \(error.localizedDescription). Using in-memory fallback.")
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try! ModelContainer(for: schema, configurations: [memoryConfig])
            seedDefaultCharacterUnlocks(in: container.mainContext)
            return container
        }
    }

    /// True when the running process is a unit-test host launched by
    /// xcodebuild/XCTest rather than a real user session. XCTest sets this
    /// environment variable on every test-host launch. Real CloudKit account
    /// setup can hang for tens of seconds when no iCloud account is present
    /// (always true on CI simulators), and the app-level container is built
    /// eagerly on every process launch — including test-host relaunches —
    /// so leaving CloudKit enabled here risks killing the test host on a
    /// per-launch timeout, unrelated to whatever test happens to be running.
    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private static func makeConfiguration(at url: URL?) -> ModelConfiguration {
        if let url {
            return ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        }
        return ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: isRunningUnitTests ? .none : .automatic
        )
    }

    private static func resolvedStoreURL(for url: URL?) -> URL {
        url ?? URL.applicationSupportDirectory.appending(path: "default.store")
    }

    private static func removeStoreFiles(at storeURL: URL) {
        let directory = storeURL.deletingLastPathComponent()
        let baseName = storeURL.lastPathComponent
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: directory.appending(path: baseName + suffix))
        }
    }

    init() {
        let creditService = CreditService()
        _creditService = State(initialValue: creditService)
        _storeKitService = State(initialValue: Self.makeStoreKitService(creditService: creditService))
        // `Auth.auth()` traps without a configured FIRApp, so the anonymous
        // sign-in rides the same guard as configuration. Auth-dependent
        // surfaces degrade via typed errors instead.
        if FirebaseBootstrap.bootstrap() == .configured {
            Task { try? await Auth.auth().signInAnonymously() }
        }
        #if DEBUG
        os_signpost(.begin, log: OSLog(subsystem: "com.stressmonitor.app", category: "Launch"), name: "AppInit")
        #endif
        // FontBlaster.blast() removed — fonts now load async in DashboardView
    }

    var body: some Scene {
        WindowGroup {
            // The `PaywallController` is owned here (true singleton) and
            // injected into the tree. The `.fullScreenCover` that consumes it
            // lives on `MainTabView`, so the paywall renders above the entire
            // TabView (all tabs + navigation stacks).
            OnboardingContainerView()
                .environment(appRouter)
                .environment(paywall)
                .environment(creditService)
                .environment(preferencesService)
                .environment(\.storeKitService, storeKitService)
                .preferredColorScheme(AppearanceManager.shared.colorScheme)
                #if DEBUG
                .onAppear {
                    let elapsed = (CFAbsoluteTimeGetCurrent() - Self.initTimestamp) * 1000
                    os_signpost(.end, log: OSLog(subsystem: "com.stressmonitor.app", category: "Launch"), name: "AppInit", "%.1fms to first view appear", elapsed)
                }
                #endif
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            // Self-correct entitlement state on every foreground, not only
            // when Transaction.updates happens to deliver something while
            // the app is already running.
            guard newPhase == .active else { return }
            Task { @MainActor in
                // Skipped while purchases are postponed — there is nothing to
                // self-correct and no product to query.
                if PurchaseAvailability.isEnabled {
                    await storeKitService.refreshEntitlements()
                }
                // Also refreshes the credit balance on every foreground; a
                // 401 here doubles as the AUTH-02 stale-session probe.
                do {
                    try await creditService.refreshBalance()
                } catch {
                    Self.appLogger.notice(
                        "Credit balance refresh failed: \(error.localizedDescription, privacy: .public)"
                    )
                }
                CharacterCollectionViewModel.syncPremiumCharacterEntitlement(
                    isPremium: PremiumState.shared.isPremiumUser,
                    in: sharedModelContainer.mainContext
                )
                // Daily HealthKit upload rides the same foreground tick:
                // once per local day, consent-gated server-side (a 403
                // CONSENT_REQUIRED flips `needsConsent` for the prompt UI).
                await HealthSyncService.shared.syncYesterdayIfNeeded()
            }
        }
    }

    // MARK: - StoreKit factory (DEBUG vs Release)

    // Internal + arguments-injectable so StoreKitServiceWiringTests asserts
    // through the real factory (WR-03 pin), never by constructing services
    // directly. See MockIAPMode for the `-mock-iap` opt-in.
    #if DEBUG
    static func makeStoreKitService(
        creditService: CreditService,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> StoreKitServiceProtocol {
        if MockIAPMode.isEnabled(arguments: arguments) {
            return MockStoreKitService(premiumState: .shared)
        }
        return StoreKitService(premiumState: .shared, creditService: creditService)
    }
    #else
    private static func makeStoreKitService(creditService: CreditService) -> StoreKitServiceProtocol {
        StoreKitService(premiumState: .shared, creditService: creditService)
    }
    #endif

    #if DEBUG
    private static let initTimestamp = CFAbsoluteTimeGetCurrent()
    #endif

    private static func seedDefaultCharacterUnlocks(in context: ModelContext) {
        let descriptor = FetchDescriptor<CharacterUnlock>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingIds = Set(existing.map(\.characterId))

        for creature in CharacterCreature.allCharacters where !existingIds.contains(creature.id) {
            let isFree = creature.unlockType == .free
            let unlock = CharacterUnlock(
                characterId: creature.id,
                isUnlocked: isFree,
                currentEvolution: .droplet,
                isActive: creature.id == "ripple"
            )
            context.insert(unlock)
        }

        try? context.save()

        if let ripple = CharacterCreature.find(by: "ripple") {
            CharacterSelectionSync.shared.saveActiveCharacter(characterId: ripple.id, evolution: .droplet)
        }
    }
}

let ciNegativeTestBrokenOnPurpose: Int = "not an int"
