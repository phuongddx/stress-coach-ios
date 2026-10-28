import Foundation
import SwiftData
import Testing
@testable import StressMonitor

/// Test double for ``CloudKitResetServiceProtocol`` backed by a seeded
/// in-memory record store. Three behaviors pin the v1.0 CR-01 regression
/// signal (DATA-04):
/// - `.lying` — every protocol method returns normally WITHOUT touching the
///   store: reports success while records survive (the CR-01 truthiness
///   shape). Survivors are observable only through ``remainingRecords`` —
///   never through the success return.
/// - `.throwing` — every protocol method throws (a genuine failure the
///   orchestrator must propagate as `DeletionError.cloudKitError`).
/// - `.draining` — deletes actually mutate the store (the honest double).
///
/// Constructor-injected only — no statics, so state can't leak between tests.
@MainActor
final class SeededCloudKitResetService: CloudKitResetServiceProtocol, @unchecked Sendable {
    enum Behavior {
        case lying
        case throwing(CloudKitResetError)
        case draining
    }

    let behavior: Behavior
    private var store: [CloudKitRecordType: Int]
    private(set) var calls: [String] = []

    init(behavior: Behavior, seededRows: [CloudKitRecordType: Int] = [:]) {
        self.behavior = behavior
        self.store = seededRows
    }

    /// Exact integer count of surviving seeded rows across every record
    /// type — no rounding, sampling, or approximation. Zero survivors and
    /// exactly one survivor are distinguishable through this accessor.
    var remainingRecords: Int { store.values.reduce(0, +) }

    private func resolve(deleting recordType: CloudKitRecordType?) async throws {
        switch behavior {
        case .lying:
            // Report success without mutating the store — the CR-01 shape.
            return
        case .throwing(let error):
            throw error
        case .draining:
            if let recordType {
                store[recordType] = 0
            } else {
                store = [:]
            }
        }
    }

    func deleteRecords(ofType recordType: CloudKitRecordType, expectedProgress: ClosedRange<Double>) async throws {
        calls.append("deleteRecords(\(recordType.rawValue))")
        try await resolve(deleting: recordType)
    }

    func deleteRecords(ofType recordType: CloudKitRecordType, in range: ClosedRange<Date>) async throws {
        calls.append("deleteRecords(\(recordType.rawValue), in:)")
        try await resolve(deleting: recordType)
    }

    func deleteRecords(ofType recordType: CloudKitRecordType, before date: Date) async throws {
        calls.append("deleteRecords(\(recordType.rawValue), before:)")
        try await resolve(deleting: recordType)
    }

    func deleteAllRecords(confirmation: (() async -> Bool)?, includeBaseline: Bool) async throws {
        calls.append("deleteAllRecords(includeBaseline: \(includeBaseline))")
        try await resolve(deleting: nil)
    }

    func performDatabaseReset(confirmation: (() async -> Bool)?) async throws {
        calls.append("performDatabaseReset")
        try await resolve(deleting: nil)
    }
}

/// CI-visible regression suite for the v1.0 CR-01 failure mode: CloudKit
/// batch delete reports success while records survive. The suite is
/// deliberately UNGATED (no enable/disable trait on the @Suite) so the
/// default CI run proves this coverage.
///
/// The contract under test: emptiness is only ever established by querying
/// the store (here, `remainingRecords`), never by trusting a success
/// return; and a genuine CloudKit failure must propagate as
/// `DeletionError.cloudKitError` with the underlying error preserved.
@Suite("CloudKit Delete Truthiness")
@MainActor
struct DataDeleterCloudKitTruthinessTests {

    // MARK: - Fixtures

    /// In-memory context with one seeded measurement. The container is
    /// returned alongside its context and must stay alive for the whole
    /// test — dropping it first crashes SwiftData.
    private func makeContextWithOneMeasurement() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: StressMeasurement.self, CharacterUnlock.self,
            configurations: config
        )
        let ctx = container.mainContext
        ctx.insert(StressMeasurement(timestamp: Date(), stressLevel: 50, hrv: 40, restingHeartRate: 65))
        try ctx.save()
        return (container, ctx)
    }

    private func makeService(
        _ ctx: ModelContext,
        cloudKit: SeededCloudKitResetService
    ) -> DataDeleterService {
        DataDeleterService(
            modelContext: ctx,
            cloudKitResetService: cloudKit,
            repository: StressRepository(modelContext: ctx),
            logger: .default
        )
    }

    // MARK: - Prong 1: genuine failure propagates

    @Test("a genuine CloudKit failure propagates as DeletionError.cloudKitError with the underlying error preserved")
    func genuineFailurePropagatesAsCloudKitError() async throws {
        let (container, ctx) = try makeContextWithOneMeasurement()
        let cloudKit = SeededCloudKitResetService(
            behavior: .throwing(.accountNotAvailable),
            seededRows: [.stressMeasurement: 3]
        )
        let service = makeService(ctx, cloudKit: cloudKit)

        do {
            try await service.deleteAllMeasurements()
            Issue.record("Expected deleteAllMeasurements to throw on a genuine CloudKit failure")
        } catch let DeletionError.cloudKitError(underlying) {
            #expect(underlying.localizedDescription == CloudKitResetError.accountNotAvailable.errorDescription)
        } catch {
            Issue.record("Expected DeletionError.cloudKitError, got \(error)")
        }

        // CloudKit failed before local deletion started, so local data must remain intact.
        let remaining = try ctx.fetch(FetchDescriptor<StressMeasurement>())
        #expect(remaining.count == 1)
        _ = container // keep the in-memory store alive until the assertions are done
    }

    // MARK: - Prong 2: truthiness canary (CR-01)

    /// A lying CloudKit double returns success while its seeded rows
    /// survive. The success return must NEVER be taken as proof of
    /// emptiness — survivors are observable only by querying the store
    /// (`remainingRecords`). This pins the regression signal the phase's
    /// DATA-01 live verification and any future orchestrator change must
    /// keep honoring.
    @Test("a lying CloudKit double reports success while the query-based check observes survivors")
    func lyingDoubleSuccessReturnNeverStandsInForAQuery() async throws {
        let (container, ctx) = try makeContextWithOneMeasurement()
        let cloudKit = SeededCloudKitResetService(
            behavior: .lying,
            seededRows: [.stressMeasurement: 5, .syncMetadata: 2]
        )
        let service = makeService(ctx, cloudKit: cloudKit)

        // The lying double reports success — the pipeline completes without throwing.
        try await service.deleteAllMeasurements()

        // …and the query-based check sees the survivors the success return concealed.
        // Emptiness is established here, never by the absence of an error.
        #expect(cloudKit.remainingRecords == 7)

        // The local half of the pipeline really ran (CR-01 is a CloudKit-side lie).
        let remaining = try ctx.fetch(FetchDescriptor<StressMeasurement>())
        #expect(remaining.isEmpty)
        _ = container // keep the in-memory store alive until the assertions are done
    }

    // MARK: - Prong 3: honest drain

    @Test("an honest CloudKit double drains its seeded store through the deleteAllMeasurements seam")
    func drainingDoubleEmptiesSeededStoreThroughTheSeam() async throws {
        let (container, ctx) = try makeContextWithOneMeasurement()
        let cloudKit = SeededCloudKitResetService(
            behavior: .draining,
            seededRows: [.stressMeasurement: 3]
        )
        let service = makeService(ctx, cloudKit: cloudKit)

        try await service.deleteAllMeasurements()

        // The orchestrator really drove the reset through the seam.
        #expect(cloudKit.calls == ["deleteRecords(CD_StressMeasurement)"])
        #expect(cloudKit.remainingRecords == 0)

        let remaining = try ctx.fetch(FetchDescriptor<StressMeasurement>())
        #expect(remaining.isEmpty)
        _ = container // keep the in-memory store alive until the assertions are done
    }

    // MARK: - Boundary: exact survivor counts

    @Test("zero survivors and exactly one survivor are distinguishable by exact integer count")
    func zeroSurvivorsAndExactlyOneSurvivorAreDistinguishable() async throws {
        // Honest drain: one seeded row is really deleted → zero survivors.
        let (drainedContainer, drainedCtx) = try makeContextWithOneMeasurement()
        let drainingCloudKit = SeededCloudKitResetService(
            behavior: .draining,
            seededRows: [.stressMeasurement: 1]
        )
        try await makeService(drainedCtx, cloudKit: drainingCloudKit).deleteAllMeasurements()
        #expect(drainingCloudKit.remainingRecords == 0)

        // Lying double: one seeded row stays → exactly one survivor, not
        // "roughly empty" — the counts differ by the smallest possible step.
        let (lyingContainer, lyingCtx) = try makeContextWithOneMeasurement()
        let lyingCloudKit = SeededCloudKitResetService(
            behavior: .lying,
            seededRows: [.stressMeasurement: 1]
        )
        try await makeService(lyingCtx, cloudKit: lyingCloudKit).deleteAllMeasurements()
        #expect(lyingCloudKit.remainingRecords == 1)

        _ = drainedContainer // keep the in-memory stores alive until the assertions are done
        _ = lyingContainer
    }

    // MARK: - Idempotency

    @Test("a second deleteAllMeasurements on the already-emptied store completes without throwing")
    func secondRunOnEmptiedStoreCompletesWithoutThrowing() async throws {
        let (container, ctx) = try makeContextWithOneMeasurement()
        let cloudKit = SeededCloudKitResetService(
            behavior: .draining,
            seededRows: [.stressMeasurement: 2]
        )
        let service = makeService(ctx, cloudKit: cloudKit)

        try await service.deleteAllMeasurements()
        #expect(cloudKit.remainingRecords == 0)

        // The empty-store re-run must be safe (no throw, no spurious error).
        try await service.deleteAllMeasurements()
        #expect(cloudKit.remainingRecords == 0)

        let remaining = try ctx.fetch(FetchDescriptor<StressMeasurement>())
        #expect(remaining.isEmpty)
        _ = container // keep the in-memory store alive until the assertions are done
    }
}

// MARK: - Factory Reset Sweep Completeness (Habit)

/// Regression suite for the store-sweep completeness gap the phase research
/// surfaced: `Habit` is synced (`AppSchemaV2`, `cloudKitDatabase: .automatic`
/// — StressMonitorApp.swift:69-79) yet was deleted by no code path in
/// `performFactoryReset`. Pins the fix (mirrors the `CharacterUnlock`
/// deletion at `DataDeleterService.swift:431`) so a synced model surviving
/// a claimed-complete factory reset regresses loudly, not silently.
@Suite("Factory Reset Sweep Completeness")
@MainActor
struct FactoryResetSweepCompletenessTests {

    // MARK: - Fixtures

    /// In-memory context seeded with one row each of StressMeasurement,
    /// CharacterUnlock, and Habit — the full local sweep set
    /// `performFactoryReset` must empty. The container is returned
    /// alongside its context and must stay alive for the whole test.
    private func makeContextWithMeasurementCharacterAndHabit() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: StressMeasurement.self, CharacterUnlock.self, Habit.self,
            configurations: config
        )
        let ctx = container.mainContext
        ctx.insert(StressMeasurement(timestamp: Date(), stressLevel: 50, hrv: 40, restingHeartRate: 65))
        ctx.insert(CharacterUnlock(characterId: "ripple", isUnlocked: true))
        ctx.insert(Habit(type: .hydration, currentValue: 1.2))
        try ctx.save()
        return (container, ctx)
    }

    /// Empty in-memory context registering the same schema — proves the
    /// empty-input case never throws.
    private func makeEmptyContext() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: StressMeasurement.self, CharacterUnlock.self, Habit.self,
            configurations: config
        )
        return (container, container.mainContext)
    }

    /// Server-session wipe never needs a real network round trip here — an
    /// immediate empty first page mirrors "list, see nothing, return"
    /// (FakeServerSessionWiper precedent, DataDeleterServerWipeTests.swift).
    private func makeService(
        _ ctx: ModelContext,
        cloudKit: SeededCloudKitResetService,
        wiper: FakeServerSessionWiper
    ) -> DataDeleterService {
        DataDeleterService(
            modelContext: ctx,
            cloudKitResetService: cloudKit,
            repository: StressRepository(modelContext: ctx),
            serverSessionWiper: wiper,
            logger: .default
        )
    }

    // MARK: - Habit-survives pin (planner decision: FIX, mirrors CharacterUnlock)

    @Test("performFactoryReset empties Habit, StressMeasurement, and CharacterUnlock")
    func performFactoryResetEmptiesEveryLocalSweepModelIncludingHabit() async throws {
        let (container, ctx) = try makeContextWithMeasurementCharacterAndHabit()
        let cloudKit = SeededCloudKitResetService(behavior: .draining, seededRows: [.stressMeasurement: 1])
        let wiper = FakeServerSessionWiper(behavior: .pages([]))
        let service = makeService(ctx, cloudKit: cloudKit, wiper: wiper)

        try await service.performFactoryReset()

        // The gap this suite pins: no code path deleted Habit until this fix.
        #expect(try ctx.fetch(FetchDescriptor<Habit>()).isEmpty)
        // Existing behavior stays pinned — no regression on the models
        // factory reset already swept.
        #expect(try ctx.fetch(FetchDescriptor<StressMeasurement>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<CharacterUnlock>()).isEmpty)
        _ = container // keep the in-memory store alive until the assertions are done
    }

    // MARK: - Empty-store idempotency

    @Test("performFactoryReset on an already-empty store completes without throwing")
    func performFactoryResetOnEmptyStoreCompletesWithoutThrowing() async throws {
        let (container, ctx) = try makeEmptyContext()
        let cloudKit = SeededCloudKitResetService(behavior: .draining)
        let wiper = FakeServerSessionWiper(behavior: .pages([]))
        let service = makeService(ctx, cloudKit: cloudKit, wiper: wiper)

        try await service.performFactoryReset()

        #expect(try ctx.fetch(FetchDescriptor<Habit>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<StressMeasurement>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<CharacterUnlock>()).isEmpty)
        _ = container // keep the in-memory store alive until the assertions are done
    }
}
