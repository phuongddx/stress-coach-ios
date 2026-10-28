import Foundation
import CloudKit
import Security
import SwiftData
import Testing
@testable import StressMonitor

@Suite("Delete All Credential Clearance")
@MainActor
struct DeleteAllCredentialClearanceTests {

    @Test("clearCredentialsAndSharedCaches removes Supabase JWT from Keychain")
    func clearsSupabaseJWTFromKeychain() throws {
        let service = "com.stressmonitor.app"
        let account = "supabaseAccessToken"

        try KeychainService.save("test-jwt", service: service, account: account)

        DataDeleterService.clearCredentialsAndSharedCaches()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        #expect(status == errSecItemNotFound)
    }

    @Test("clearCredentialsAndSharedCaches removes the stored chat session id")
    func clearsStressChatSessionId() throws {
        UserDefaults.standard.set("seed-session-id", forKey: "stressChatSessionId")

        DataDeleterService.clearCredentialsAndSharedCaches()

        #expect(UserDefaults.standard.string(forKey: "stressChatSessionId") == nil)
    }

    @Test("clearCredentialsAndSharedCaches removes App Group widget cache")
    func clearsAppGroupWidgetCache() throws {
        let suiteID = WidgetConstants.appGroupID
        let testKey = "latest_stress_level"

        guard let defaults = UserDefaults(suiteName: suiteID) else {
            Issue.record("Could not create UserDefaults for suite \(suiteID)")
            return
        }
        defaults.set(72.5, forKey: testKey)

        DataDeleterService.clearCredentialsAndSharedCaches()

        let snapshot = UserDefaults(suiteName: suiteID)?.dictionaryRepresentation()
        #expect(snapshot?[testKey] == nil)
    }
}

@Suite("Data Deleter Consolidation")
@MainActor
struct DataDeleterConsolidationTests {

    @Test("clearCredentialsAndSharedCaches removes Supabase refresh token from Keychain")
    func factoryResetClearsRefreshToken() throws {
        let service = "com.stressmonitor.app"
        let account = "supabaseRefreshToken"

        try KeychainService.save("test-refresh-token", service: service, account: account)

        DataDeleterService.clearCredentialsAndSharedCaches()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        #expect(status == errSecItemNotFound)
    }
}

@Suite("Export Protection")
struct ExportProtectionTests {

    @Test("validateExportSize rejects record count exceeding cap")
    func rejectsRecordCountOverCap() throws {
        let overageRecords = Array(
            repeating: StressMeasurement(timestamp: Date(), stressLevel: 50, hrv: 40),
            count: DataExportViewModel.maxExportRecords + 1
        )

        #expect(throws: ExportError.self) {
            try DataExportViewModel.validateExportSize(recordCount: overageRecords.count, format: .csv)
        }
    }

    @Test("validateExportSize accepts record count within cap")
    func acceptsRecordCountWithinCap() throws {
        #expect(throws: Never.self) {
            try DataExportViewModel.validateExportSize(recordCount: 100, format: .csv)
        }
    }

    @Test("cleanupExportTempFile removes stress_export file from caches")
    func removesTempFileOnShareDismiss() throws {
        let cachesDir = try FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        )
        let tempFile = cachesDir.appendingPathComponent("stress_export_test_cleanup.json")
        try "{\"test\":1}".write(to: tempFile, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: tempFile.path))

        DataExportViewModel.cleanupExportTempFile(at: tempFile)

        #expect(!FileManager.default.fileExists(atPath: tempFile.path))
    }
}

@Suite("Data Deletion Scope Enforcement")
@MainActor
struct DataDeleterScopedDeletionTests {

    private func makeService(modelContext: ModelContext) -> DataDeleterService {
        DataDeleterService(
            modelContext: modelContext,
            cloudKitContainer: CKContainer(identifier: "iCloud.com.stressmonitor.tests"),
            repository: StressRepository(modelContext: modelContext),
            logger: .default
        )
    }

    @Test("includeLocal: true, includeCloud: false deletes local data without touching CloudKit")
    func localOnlyScopeDeletesLocalWithoutTouchingCloud() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: StressMeasurement.self, configurations: config)
        let ctx = container.mainContext

        let now = Date()
        ctx.insert(StressMeasurement(timestamp: now, stressLevel: 50, hrv: 40, restingHeartRate: 65))
        try ctx.save()

        let service = makeService(modelContext: ctx)

        try await service.deleteMeasurements(
            in: now.addingTimeInterval(-60)...now.addingTimeInterval(60),
            includeLocal: true,
            includeCloud: false
        )

        let remaining = try ctx.fetch(FetchDescriptor<StressMeasurement>())
        #expect(remaining.isEmpty)
    }

    @Test("includeLocal: false leaves local data untouched")
    func scopeExcludingLocalLeavesLocalDataIntact() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: StressMeasurement.self, configurations: config)
        let ctx = container.mainContext

        let now = Date()
        ctx.insert(StressMeasurement(timestamp: now, stressLevel: 50, hrv: 40, restingHeartRate: 65))
        try ctx.save()

        let service = makeService(modelContext: ctx)

        // includeCloud is also false so this exercises the scope gate without any network access.
        try await service.deleteMeasurements(
            in: now.addingTimeInterval(-60)...now.addingTimeInterval(60),
            includeLocal: false,
            includeCloud: false
        )

        let remaining = try ctx.fetch(FetchDescriptor<StressMeasurement>())
        #expect(remaining.count == 1)
    }
}

/// Test double for ``CloudKitResetServiceProtocol`` that can simulate a CloudKit
/// failure or a mid-flight cancellation without any network access.
@MainActor
final class FakeCloudKitResetService: CloudKitResetServiceProtocol {
    enum Behavior {
        case succeed
        case throwError(CloudKitResetError)
        /// Cancels the Task currently executing the CloudKit call, simulating the
        /// user tapping Cancel while the network request is already in flight.
        case cancelCallingTask
    }

    var behavior: Behavior = .succeed

    private func resolve() async throws {
        switch behavior {
        case .succeed:
            return
        case .throwError(let error):
            throw error
        case .cancelCallingTask:
            withUnsafeCurrentTask { $0?.cancel() }
        }
    }

    func deleteRecords(ofType recordType: CloudKitRecordType, expectedProgress: ClosedRange<Double>) async throws {
        try await resolve()
    }

    func deleteRecords(ofType recordType: CloudKitRecordType, in range: ClosedRange<Date>) async throws {
        try await resolve()
    }

    func deleteRecords(ofType recordType: CloudKitRecordType, before date: Date) async throws {
        try await resolve()
    }

    func deleteAllRecords(confirmation: (() async -> Bool)?, includeBaseline: Bool) async throws {
        try await resolve()
    }

    func performDatabaseReset(confirmation: (() async -> Bool)?) async throws {
        try await resolve()
    }
}

@Suite("CloudKit Failure & Cancellation Ordering")
@MainActor
struct DataDeleterFailureAndCancellationTests {

    /// In-memory context seeded with one measurement. The container is
    /// returned alongside its context and must stay alive for the whole
    /// test — returning the context alone lets the container (the only
    /// owner of the in-memory store) deallocate, and the next SwiftData
    /// operation on the orphaned context traps.
    private func makeContextWithOneMeasurement() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: StressMeasurement.self, configurations: config)
        let ctx = container.mainContext
        ctx.insert(StressMeasurement(timestamp: Date(), stressLevel: 50, hrv: 40, restingHeartRate: 65))
        try ctx.save()
        return (container, ctx)
    }

    @Test("deleteAllMeasurements surfaces a CloudKitResetError as DeletionError.cloudKitError with the correct message")
    func deleteAllMeasurementsPropagatesCloudKitFailureMessage() async throws {
        let (container, ctx) = try makeContextWithOneMeasurement()

        let fakeCloudKit = FakeCloudKitResetService()
        fakeCloudKit.behavior = .throwError(.accountNotAvailable)

        let service = DataDeleterService(
            modelContext: ctx,
            cloudKitResetService: fakeCloudKit,
            repository: StressRepository(modelContext: ctx),
            logger: .default
        )

        do {
            try await service.deleteAllMeasurements()
            Issue.record("Expected deleteAllMeasurements to throw")
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

    @Test("cancelling after CloudKit deletion has started still deletes local data (no split-brain)")
    func cancellationAfterCloudKitStartsStillDeletesLocal() async throws {
        let (container, ctx) = try makeContextWithOneMeasurement()

        let fakeCloudKit = FakeCloudKitResetService()
        fakeCloudKit.behavior = .cancelCallingTask

        let service = DataDeleterService(
            modelContext: ctx,
            cloudKitResetService: fakeCloudKit,
            repository: StressRepository(modelContext: ctx),
            logger: .default
        )

        // The fake cancels its own running Task from inside the CloudKit call, simulating
        // the user tapping Cancel while the network request is in flight (CR-01). Once
        // CloudKit deletion has started, local deletion must still run to completion.
        let deletionTask = Task {
            try await service.deleteAllMeasurements()
        }
        try await deletionTask.value

        let remaining = try ctx.fetch(FetchDescriptor<StressMeasurement>())
        #expect(remaining.isEmpty)
        _ = container // keep the in-memory store alive until the assertions are done
    }

    @Test("cancelling before CloudKit deletion starts aborts the whole operation")
    func cancellationBeforeCloudKitStartsAbortsOperation() async throws {
        let (container, ctx) = try makeContextWithOneMeasurement()

        let fakeCloudKit = FakeCloudKitResetService()

        let service = DataDeleterService(
            modelContext: ctx,
            cloudKitResetService: fakeCloudKit,
            repository: StressRepository(modelContext: ctx),
            logger: .default
        )

        let deletionTask = Task {
            try await service.deleteAllMeasurements()
        }
        deletionTask.cancel()

        do {
            try await deletionTask.value
            Issue.record("Expected deleteAllMeasurements to throw after cancellation")
        } catch DeletionError.operationCancelled {
            // Expected: cancelled before the irreversible CloudKit phase began.
        } catch {
            Issue.record("Expected DeletionError.operationCancelled, got \(error)")
        }

        // Cancelled before CloudKit deletion started, so nothing should have been touched.
        let remaining = try ctx.fetch(FetchDescriptor<StressMeasurement>())
        #expect(remaining.count == 1)
        _ = container // keep the in-memory store alive until the assertions are done
    }

    @Test("scoped deleteMeasurements(in:includeLocal:includeCloud:) still deletes local data when cancelled mid-flight (no split-brain)")
    func scopedDeleteInRangeCancellationAfterCloudKitStartsStillDeletesLocal() async throws {
        let (container, ctx) = try makeContextWithOneMeasurement()
        let now = Date()

        let fakeCloudKit = FakeCloudKitResetService()
        fakeCloudKit.behavior = .cancelCallingTask

        let service = DataDeleterService(
            modelContext: ctx,
            cloudKitResetService: fakeCloudKit,
            repository: StressRepository(modelContext: ctx),
            logger: .default
        )

        // Exercises the same cancellation-ordering guarantee as
        // cancellationAfterCloudKitStartsStillDeletesLocal, but through the scoped
        // deleteMeasurements(in:includeLocal:includeCloud:) path — the one DataDeleteView
        // actually calls for anything other than "everything, all time" (WR-04).
        let deletionTask = Task {
            try await service.deleteMeasurements(
                in: now.addingTimeInterval(-60)...now.addingTimeInterval(60),
                includeLocal: true,
                includeCloud: true
            )
        }
        try await deletionTask.value

        let remaining = try ctx.fetch(FetchDescriptor<StressMeasurement>())
        #expect(remaining.isEmpty)
        _ = container // keep the in-memory store alive until the assertions are done
    }
}

@Suite("Data Export Field Selection")
@MainActor
struct DataExportFieldSelectionTests {

    /// In-memory context for export tests. The container is returned
    /// alongside its context and must stay alive for the whole test —
    /// returning the context alone lets the container (the only owner of
    /// the in-memory store) deallocate, and the next SwiftData operation
    /// on the orphaned context traps.
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: StressMeasurement.self, configurations: config)
        return (container, container.mainContext)
    }

    @Test("CSV export omits fields whose toggle is disabled")
    func csvExportHonorsToggles() async throws {
        let (container, ctx) = try makeContext()
        ctx.insert(StressMeasurement(timestamp: Date(), stressLevel: 62.5, hrv: 48.0, restingHeartRate: 72.0))
        try ctx.save()

        let viewModel = DataExportViewModel()
        viewModel.dateRange = .all
        viewModel.format = .csv
        viewModel.includeHRV = false
        viewModel.includeHeartRate = true
        viewModel.includeStressLevels = false
        viewModel.includeBaseline = false

        let url = try await viewModel.exportData(modelContext: ctx)
        defer { DataExportViewModel.cleanupExportTempFile(at: url) }

        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("Heart Rate"))
        #expect(!content.contains("HRV"))
        #expect(!content.contains("Stress Level"))
        _ = container // keep the in-memory store alive until the assertions are done
    }

    @Test("JSON export includes a baseline section only when the toggle is enabled")
    func jsonExportIncludesBaselineWhenRequested() async throws {
        let (container, ctx) = try makeContext()
        // The baseline calculator requires 30+ HRV samples inside its 30-day
        // window (minimumSampleCount = 30; identical values survive IQR
        // outlier filtering). Seeding a single measurement made
        // getBaseline() throw insufficientSamples, which fetchBaseline's
        // try? swallowed, omitting the baseline section asserted below.
        for offset in 0..<40 {
            ctx.insert(StressMeasurement(
                timestamp: Date().addingTimeInterval(Double(offset) * -43_200),
                stressLevel: 62.5,
                hrv: 48.0,
                restingHeartRate: 72.0
            ))
        }
        try ctx.save()

        let viewModel = DataExportViewModel()
        viewModel.dateRange = .all
        viewModel.format = .json
        viewModel.includeBaseline = true

        let url = try await viewModel.exportData(modelContext: ctx)
        defer { DataExportViewModel.cleanupExportTempFile(at: url) }

        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("\"baseline\""))
        #expect(content.contains("\"restingHeartRate\""))
        _ = container // keep the in-memory store alive until the assertions are done
    }
}

@Suite("CloudKit Encryption")
struct CloudKitEncryptionTests {

    @Test("health fields round-trip through encryptedValues and are absent from plaintext keys")
    func healthFieldsRoundTripThroughEncryptedValues() throws {
        let record = CKRecord(recordType: "CD_StressMeasurement")
        let stressLevel: Double = 62.5
        let hrv: Double = 48.0
        let restingHeartRate: Double = 72.0

        record.encryptedValues["stressLevel"] = stressLevel
        record.encryptedValues["hrv"] = hrv
        record.encryptedValues["restingHeartRate"] = restingHeartRate

        let readStressLevel = try #require(record.encryptedValues["stressLevel"] as? Double)
        let readHRV = try #require(record.encryptedValues["hrv"] as? Double)
        let readHR = try #require(record.encryptedValues["restingHeartRate"] as? Double)

        #expect(readStressLevel == stressLevel)
        #expect(readHRV == hrv)
        #expect(readHR == restingHeartRate)

        #expect(record["stressLevel"] == nil)
        #expect(record["hrv"] == nil)
        #expect(record["restingHeartRate"] == nil)
    }
}
