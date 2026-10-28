import Foundation
import Observation
import HealthKit
#if DEBUG
import os
#endif

@Observable
@MainActor
final class StressViewModel {

    var currentStress: StressResult?
    var historicalData: [StressMeasurement] = []
    var baseline: PersonalBaseline?
    var liveHeartRate: Double?
    var isLoading = false
    var errorMessage: String?
    var lastRefresh: Date?

    // MARK: - New Properties for Dashboard Enhancement

    /// Last 7 HRV readings for mini chart
    var hrvHistory: [Double] = []
    /// Today's measurements for timeline
    var todayMeasurements: [StressMeasurement] = []
    /// Consecutive days, ending today, with at least one measurement.
    private(set) var streakDays = 0
    /// Current week average stress
    var weeklyCurrentAvg: Double = 0
    /// Previous week average stress
    var weeklyPreviousAvg: Double = 0
    /// AI-generated insight
    var aiInsight: AIInsight?
    var dataQualityInfo: DataQualityInfo?

    // MARK: - Dashboard Vitals State

    /// Latest respiratory rate in breaths/min. Nil when unavailable (simulator, or
    /// no Apple Watch data) — the vitals row renders `—` in that case.
    var respiratoryRate: Double?
    /// Latest self-reported mood from the Home check-in.
    var mood: MoodEntry?

    // MARK: - Behavioral Metrics (Home health-data row)

    /// Duration of the most recent workout (today or yesterday) in minutes — drives the Exercise tile.
    var lastWorkoutMinutes: Int?
    /// When the most recent workout ended; lets the tile say which day it was.
    var lastWorkoutEndDate: Date?
    /// Total sleep in hours from last night — drives the Sleep tile.
    var todaySleepHours: Double?
    /// Time outdoors in minutes — drives the Daylight tile (best-effort).
    var todayDaylightMinutes: Int?

    // MARK: - Bio Age Properties

    /// Estimated biological age result — nil until enough data accumulates
    var bioAgeResult: BioAgeResult?
    /// User's chronological age from the HealthKit date of birth. Nil when the
    /// user has not set one — no bio-age estimate is made without it.
    var userAge: Int?
    var isDateOfBirthMissing: Bool { userAge == nil }
    /// Whether there's enough data for a bio age estimate
    var hasSufficientBioAgeData: Bool = false

    // MARK: - Permission State

    /// Set exclusively when HKError.errorAuthorizationDenied is caught — NOT a proxy for currentStress == nil.
    var isPermissionRequired: Bool = false
    /// Re-entry guard for requestHealthKitAccess(). Drives button disabled state in PermissionCardView.
    private(set) var isRequestingAccess: Bool = false

    // MARK: - Auto-Refresh Properties

    /// Last refresh time for debounce
    private var lastRefreshTime: Date?
    /// Minimum interval between refreshes (60 seconds)
    private let refreshInterval: TimeInterval = 60
    /// HealthKit observer query for HRV
    private var observerQuery: HKObserverQuery?
    /// HealthStore instance
    private let healthStore = HKHealthStore()

    /// Timestamp of the last underlying HRV reading persisted from
    /// loadCurrentStress — repeated UI-driven loads of the same HealthKit
    /// sample persist exactly one measurement (WIRE-01 dedupe guard).
    private var lastPersistedReadingDate: Date?

    private let healthKit: HealthKitServiceProtocol
    private let algorithm: StressAlgorithmServiceProtocol
    private let repository: StressRepositoryProtocol
    private let calibrator = FactorCalibrator()
    private let bioAgeCalculator = BioAgeCalculator()

    /// Stored Task for heart rate observation cancellation
    private var heartRateTask: Task<Void, Never>?

    #if DEBUG
    /// Demo mode periodic stress recalculation task
    private var demoRefreshTask: Task<Void, Never>?
    #endif

    init(
        healthKit: HealthKitServiceProtocol,
        algorithm: StressAlgorithmServiceProtocol,
        repository: StressRepositoryProtocol
    ) {
        self.healthKit = healthKit
        self.algorithm = algorithm
        self.repository = repository
    }

    func loadCurrentStress() async {
        #if DEBUG
        let t0 = CFAbsoluteTimeGetCurrent()
        os_signpost(.begin, log: OSLog(subsystem: "com.stressmonitor.app", category: "Launch"), name: "LoadCurrentStress")
        #endif

        isLoading = true
        defer {
            isLoading = false
            #if DEBUG
            os_signpost(.end, log: OSLog(subsystem: "com.stressmonitor.app", category: "Launch"), name: "LoadCurrentStress")
            #endif
        }

        do {
            let fetchedBaseline = try? await repository.getBaseline()
            let currentBaseline = baseline ?? fetchedBaseline ?? PersonalBaseline()

            // Phase 3: ALL 5 HealthKit queries in parallel (HRV+HR were already async let,
            // now sleep/activity/recovery join them)
            async let hrv = healthKit.fetchLatestHRV()
            async let hr = healthKit.fetchHeartRate(samples: 1)
            async let sleepTask = healthKit.fetchSleepData(for: Date())
            async let activityTask = healthKit.fetchActivityData(for: Date())
            async let recoveryTask = healthKit.fetchRecoveryData(for: Date())

            // Await critical data first
            let (hrvData, hrData) = try await (hrv, hr)

            guard let hrvValue = hrvData?.value else {
                return
            }

            // Graceful degradation for secondary factors
            let sleepData = try? await sleepTask
            let activityData = try? await activityTask
            let recoveryData = try? await recoveryTask

            // RR is best-effort: returns nil on simulator or when no Apple Watch
            // breathing data exists. Failure here must never break stress calc.
            let rrValue = try? await healthKit.fetchRespiratoryRate()

            let context = StressContext(
                baseline: currentBaseline,
                hrv: hrvValue,
                heartRate: hrData.first?.value,
                sleepData: sleepData,
                activityData: activityData,
                recoveryData: recoveryData,
                lastReadingDate: hrvData?.timestamp
            )

            let result = try await algorithm.calculateMultiFactorStress(context: context)
            currentStress = result
            respiratoryRate = rrValue
            lastWorkoutMinutes = activityData?.lastWorkoutDurationMinutes.map { Int($0) }
            lastWorkoutEndDate = activityData?.lastWorkoutEndTime
            todaySleepHours = sleepData?.totalSleepHours
            todayDaylightMinutes = await fetchTodayDaylightMinutes()
            isPermissionRequired = false
            baseline = currentBaseline
            lastRefresh = Date()
            errorMessage = nil

            if let breakdown = result.factorBreakdown {
                dataQualityInfo = DataQualityInfo(from: breakdown, baseline: currentBaseline)
            }

            // Widget write path (WIRE-01): one persisted measurement per new
            // underlying HRV reading — repository.save publishes the six
            // latest_* App Group keys and reloads the widget timelines. The
            // reading is marked persisted BEFORE the save await so two
            // interleaved loads sharing one sample cannot both save; a
            // swallowed save failure degrades like the secondary factors and
            // skips that reading's retry (accepted trade-off).
            if let readingDate = hrvData?.timestamp, readingDate != lastPersistedReadingDate {
                lastPersistedReadingDate = readingDate
                try? await repository.save(makeMeasurement(from: result))
            }

            #if DEBUG
            let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            os_signpost(.event, log: OSLog(subsystem: "com.stressmonitor.app", category: "Launch"), name: "StressResult", "Calculated in %.1fms", elapsed)
            #endif
        } catch let hkError as HKError where hkError.code == .errorAuthorizationDenied {
            isPermissionRequired = true
            currentStress = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Request HealthKit authorization. Only sets isPermissionRequired for known auth failures —
    /// framework errors go to errorMessage. Guards against double-tap with isRequestingAccess.
    func requestHealthKitAccess() async {
        guard !isRequestingAccess else { return }
        isRequestingAccess = true
        defer { isRequestingAccess = false }

        do {
            try await healthKit.requestAuthorization()
            isPermissionRequired = false
            await loadCurrentStress()
        } catch let hkError as HKError
            where hkError.code == .errorAuthorizationNotDetermined
               || hkError.code == .errorAuthorizationDenied {
            isPermissionRequired = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadHistoricalData(days: Int) async {
        do {
            historicalData = try await repository.fetchRecent(limit: days * 24)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Load baseline and return quickly. Calibration is deferred to a background Task
    /// so it doesn't block the critical launch path.
    /// Uses Task { } (NOT Task.detached) because repository is @MainActor.
    func loadBaseline() async {
        #if DEBUG
        let t0 = CFAbsoluteTimeGetCurrent()
        os_signpost(.begin, log: OSLog(subsystem: "com.stressmonitor.app", category: "Launch"), name: "LoadBaseline")
        #endif

        do {
            let loadedBaseline = try await repository.getBaseline()
            baseline = loadedBaseline
            if let breakdown = currentStress?.factorBreakdown {
                dataQualityInfo = DataQualityInfo(from: breakdown, baseline: loadedBaseline)
            }
            errorMessage = nil

            // Phase 2: Defer calibration — Task (NOT Task.detached) because repository is @MainActor
            Task { [weak self] in
                guard let self else { return }
                do {
                    let measurements = try await self.repository.fetchRecent(limit: 200)
                    if measurements.count >= 30 {
                        var calibrated = loadedBaseline
                        let weights = self.calibrator.calibrate(from: measurements)
                        let hourly = self.calibrator.calculateHourlyBaseline(from: measurements)
                        calibrated.factorWeights = weights
                        calibrated.hourlyHRVBaseline = hourly
                        calibrated.calibrationDate = Date()
                        try await self.repository.updateBaseline(calibrated)
                        self.baseline = calibrated
                    }
                } catch {
                    // Calibration failure is non-critical — baseline already loaded
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        os_signpost(.end, log: OSLog(subsystem: "com.stressmonitor.app", category: "Launch"), name: "LoadBaseline", "%.1fms", elapsed)
        #endif
    }

    func refreshHealthData() async {
        await loadCurrentStress()
    }

    func observeHeartRate() {
        heartRateTask = Task {
            for await sample in healthKit.observeHeartRateUpdates() {
                liveHeartRate = sample?.value
            }
        }
    }

    /// Maps a calculated StressResult to its persisted StressMeasurement shape.
    /// Single source for both the legacy calculateAndSaveStress path and the
    /// live loadCurrentStress save, so the two rows stay identical.
    private func makeMeasurement(from result: StressResult) -> StressMeasurement {
        let measurement = StressMeasurement(
            timestamp: result.timestamp,
            stressLevel: result.level,
            hrv: result.hrv,
            restingHeartRate: result.heartRate,
            confidences: [result.confidence]
        )

        if let breakdown = result.factorBreakdown {
            measurement.hrvComponent = breakdown.hrvComponent
            measurement.hrComponent = breakdown.hrComponent
            measurement.sleepComponent = breakdown.sleepComponent
            measurement.activityComponent = breakdown.activityComponent
            measurement.recoveryComponent = breakdown.recoveryComponent
            measurement.dataCompleteness = breakdown.dataCompleteness
        }

        return measurement
    }

    func calculateAndSaveStress() async throws {
        let fetchedBaseline = try? await repository.getBaseline()
        let currentBaseline = baseline ?? fetchedBaseline ?? PersonalBaseline()

        // Phase 3: All 5 queries in parallel
        async let hrv = healthKit.fetchLatestHRV()
        async let hr = healthKit.fetchHeartRate(samples: 1)
        async let sleepTask = healthKit.fetchSleepData(for: Date())
        async let activityTask = healthKit.fetchActivityData(for: Date())
        async let recoveryTask = healthKit.fetchRecoveryData(for: Date())

        let (hrvData, hrData) = try await (hrv, hr)

        guard let hrvValue = hrvData?.value else { throw StressError.noData }

        // Graceful degradation for secondary factors
        let sleepData = try? await sleepTask
        let activityData = try? await activityTask
        let recoveryData = try? await recoveryTask

        let context = StressContext(
            baseline: currentBaseline,
            hrv: hrvValue,
            heartRate: hrData.first?.value,
            sleepData: sleepData,
            activityData: activityData,
            recoveryData: recoveryData,
            lastReadingDate: hrvData?.timestamp
        )

        let result = try await algorithm.calculateMultiFactorStress(context: context)

        let measurement = makeMeasurement(from: result)

        try await repository.save(measurement)
        currentStress = result
        lastRefresh = Date()
    }

    func clearError() {
        errorMessage = nil
    }

    /// Record a subjective mood from the Home check-in. Replacing the same-day
    /// entry keeps the dashboard's "current mood" chip accurate.
    func setMood(_ level: MoodLevel) {
        mood = MoodEntry(level: level)
    }

    // MARK: - Dashboard Data Loading

    /// Load all dashboard data — stress calculation and history run in parallel
    func loadDashboardData() async {
        #if DEBUG
        let t0 = CFAbsoluteTimeGetCurrent()
        os_signpost(.begin, log: OSLog(subsystem: "com.stressmonitor.app", category: "Launch"), name: "LoadDashboard")
        #endif

        isLoading = true

        // Phase 3: Run stress calculation and history fetch in parallel
        async let stressTask: Void = loadCurrentStress()
        async let historyTask: Void = loadHistoricalData(days: 14)
        _ = await (stressTask, historyTask)

        // Derived data depends on both completing
        loadTodayMeasurements()
        await loadStreak()
        loadWeeklyComparison()
        generateInsight()
        calculateBioAge()

        isLoading = false

        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        os_signpost(.end, log: OSLog(subsystem: "com.stressmonitor.app", category: "Launch"), name: "LoadDashboard", "%.1fms", elapsed)
        #endif
    }

    /// Load today's measurements for timeline view
    func loadTodayMeasurements() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        todayMeasurements = historicalData.filter { $0.timestamp >= startOfDay }
        hrvHistory = Array(todayMeasurements.map { $0.hrv }.suffix(7))
    }

    /// Streak looks back a fixed window by date, independent of how many
    /// measurements the history fetch happened to return.
    func loadStreak() async {
        let now = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -MeasurementStreak.lookbackDays, to: now),
              let measurements = try? await repository.fetchMeasurements(from: start, to: now) else { return }
        streakDays = MeasurementStreak.days(from: measurements.map(\.timestamp))
    }

    /// Calculate current vs previous week averages
    func loadWeeklyComparison() {
        let calendar = Calendar.current
        let now = Date()

        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) else {
            weeklyCurrentAvg = 0
            weeklyPreviousAvg = 0
            return
        }

        let currentWeek = historicalData.filter { $0.timestamp >= weekStart }
        let prevWeek = historicalData.filter { $0.timestamp >= prevWeekStart && $0.timestamp < weekStart }

        weeklyCurrentAvg = currentWeek.isEmpty ? 0 : currentWeek.map(\.stressLevel).reduce(0, +) / Double(currentWeek.count)
        weeklyPreviousAvg = prevWeek.isEmpty ? 0 : prevWeek.map(\.stressLevel).reduce(0, +) / Double(prevWeek.count)
    }

    /// Last 7 days of stress as chart points, oldest first. Each day's bar
    /// encodes the peak stress recorded that day; days without any measurement
    /// carry no value so the chart leaves them empty.
    var weeklyStressPoints: [StressDataPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (-6...0).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let peak = historicalData
                .filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
                .map(\.stressLevel)
                .max()
            return StressDataPoint(
                date: day,
                value: peak.map { Int($0.rounded()) },
                category: peak.map { StressResult.category(for: $0) }
            )
        }
    }

    // MARK: - Vitals vs Weekly Average

    /// Latest HRV minus the mean of the past week's earlier readings, in ms.
    /// Nil until at least three earlier readings exist.
    var hrvDeltaVsWeeklyAverage: Int? {
        guard let current = currentStress?.hrv, current > 0 else { return nil }
        return deltaVsWeeklyAverage(current: current, metric: \.hrv)
    }

    /// Latest heart rate minus the mean of the past week's earlier readings, in bpm.
    /// Nil when the current reading has no heart rate or fewer than three earlier readings exist.
    var heartRateDeltaVsWeeklyAverage: Int? {
        guard let current = currentStress?.heartRate, current > 0 else { return nil }
        return deltaVsWeeklyAverage(current: current, metric: \.restingHeartRate)
    }

    private func deltaVsWeeklyAverage(current: Double, metric: KeyPath<StressMeasurement, Double>) -> Int? {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) else { return nil }
        let earlier = historicalData
            .filter { $0.timestamp >= cutoff && $0.timestamp != currentStress?.timestamp }
            .map { $0[keyPath: metric] }
            .filter { $0 > 0 }
        guard earlier.count >= 3 else { return nil }
        let average = earlier.reduce(0, +) / Double(earlier.count)
        return Int((current - average).rounded())
    }

    /// Generate AI insight from current stress and history
    func generateInsight() {
        guard let stress = currentStress else {
            aiInsight = nil
            return
        }
        let personalBaselineHRV = bioAgeCalculator.hasEnoughData(measurements: historicalData) ? baseline?.baselineHRV : nil
        aiInsight = InsightGenerator.generate(from: stress, history: historicalData, baselineHRV: personalBaselineHRV)
    }

    // MARK: - Bio Age Calculation

    /// Calculate biological age from current health data and measurement history.
    /// Requires 7+ days of data for a reliable estimate.
    func calculateBioAge() {
        let calendar = Calendar.current
        if let dobComponent = healthKit.dateOfBirthComponents,
           let dob = calendar.date(from: dobComponent) {
            userAge = calendar.dateComponents([.year], from: dob, to: Date()).year
        } else {
            userAge = nil
        }

        // Check data sufficiency
        hasSufficientBioAgeData = bioAgeCalculator.hasEnoughData(measurements: historicalData)

        guard let userAge, hasSufficientBioAgeData else {
            bioAgeResult = nil
            return
        }

        // Use 7 most recent readings' average HRV and RHR for stability
        let recent = historicalData.sorted { $0.timestamp > $1.timestamp }.prefix(7)
        let avgHRV = average(of: recent.map(\.hrv).filter { $0 > 0 })
        let avgRHR = average(of: recent.map(\.restingHeartRate).filter { $0 > 0 })

        // Sleep efficiency from latest context if available
        let sleepEfficiency: Double? = nil

        bioAgeResult = bioAgeCalculator.calculate(
            chronologicalAge: userAge,
            hrv: avgHRV,
            restingHeartRate: avgRHR,
            sleepEfficiency: sleepEfficiency,
            previousResult: bioAgeResult
        )
    }

    private func average(of values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Auto-Refresh with HKObserverQuery

    /// Check if enough time has passed for a refresh
    private var canRefresh: Bool {
        guard let last = lastRefreshTime else { return true }
        return Date().timeIntervalSince(last) >= refreshInterval
    }

    /// Start auto-refresh via HealthKit observer
    func startAutoRefresh() {
        // Demo mode: timer-based refresh instead of HKObserverQuery
        #if DEBUG
        if DemoMode.isEnabled {
            startDemoAutoRefresh()
            return
        }
        #endif

        // Skip HealthKit observer in simulator — no HealthKit entitlement in sim builds
        #if targetEnvironment(simulator)
        return
        #else
        let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!

        let query = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self else {
                completionHandler()
                return
            }

            if let error = error {
                Task { @MainActor [weak self] in
                    self?.errorMessage = "HealthKit observer error: \(error.localizedDescription)"
                }
                completionHandler()
                return
            }

            Task { @MainActor [weak self] in
                self?.handleHealthKitUpdate()
            }

            completionHandler()
        }

        healthStore.execute(query)
        observerQuery = query
        #endif
    }

    #if DEBUG
    /// Demo mode: periodic stress recalculation every 15s
    private func startDemoAutoRefresh() {
        demoRefreshTask?.cancel()
        demoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled, let self else { return }
                await self.loadCurrentStress()
                self.loadTodayMeasurements()
                await self.loadStreak()
                self.generateInsight()
            }
        }
    }
    #endif

    /// Stop auto-refresh observer
    func stopAutoRefresh() {
        // Cancel HKObserverQuery
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }
        // Cancel heart rate observation Task
        heartRateTask?.cancel()
        heartRateTask = nil
        #if DEBUG
        demoRefreshTask?.cancel()
        demoRefreshTask = nil
        #endif
    }

    /// Handle HealthKit update with debounce
    private func handleHealthKitUpdate() {
        guard canRefresh else { return }

        let previousCategory = currentStress?.category

        Task {
            await loadCurrentStress()
            loadTodayMeasurements()
            await loadStreak()
            generateInsight()

            // Haptic feedback on category change
            if let newCategory = currentStress?.category,
               newCategory != previousCategory {
                HapticManager.shared.stressLevelChanged(to: newCategory)
            }

            lastRefreshTime = Date()
        }
    }
}

enum StressError: Error {
    case noData
}

// MARK: - Daylight

extension StressViewModel {
    /// `nil` when HealthKit has no daylight samples today or the source can't read them.
    fileprivate func fetchTodayDaylightMinutes() async -> Int? {
        guard let source = healthKit as? HabitHealthDataProviding,
              let minutes = try? await source.fetchTodayDaylightMinutes() else { return nil }
        return Int(minutes.rounded())
    }
}
