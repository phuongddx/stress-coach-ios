import Foundation
import Observation
import WidgetKit

@Observable
final class WatchStressViewModel {
  var currentStress: StressResult?
  var isLoading = false
  var errorMessage: String?

  /// The current 0–100 level, falling back to the last stored reading.
  /// `nil` until a real measurement exists — views render an empty state.
  var currentLevel: Double? {
    currentStress?.level ?? WatchSharedDataStore.shared.latest?.level
  }

  private let healthKit: WatchHealthKitManager
  private let algorithm: StressAlgorithmServiceProtocol
  private let connectivity: WatchConnectivityManager
  private let complicationProvider: ComplicationDataProvider
  private let sharedStore: WatchSharedDataStore

  init(
    healthKit: WatchHealthKitManager = WatchHealthKitManager(),
    algorithm: StressAlgorithmServiceProtocol = MultiFactorStressCalculator(),
    connectivity: WatchConnectivityManager = .shared,
    complicationProvider: ComplicationDataProvider = .shared,
    sharedStore: WatchSharedDataStore = .shared
  ) {
    self.healthKit = healthKit
    self.algorithm = algorithm
    self.connectivity = connectivity
    self.complicationProvider = complicationProvider
    self.sharedStore = sharedStore
  }

  func requestAuthorization() async {
    do {
      try await healthKit.requestAuthorization()
    } catch {
      errorMessage = "Authorization failed: \(error.localizedDescription)"
    }
  }

  func measureStress() async {
    isLoading = true
    errorMessage = nil

    do {
      async let hrv = healthKit.fetchLatestHRV()
      async let hr = healthKit.fetchHeartRate(samples: 10)

      let (hrvData, hrData) = try await (hrv, hr)

      guard let hrvValue = hrvData?.value,
        let heartRate = hrData.first?.value
      else {
        errorMessage = "No health data available"
        isLoading = false
        return
      }

      let sleepData = try? await healthKit.fetchSleepData(for: Date())
      let activityData = try? await healthKit.fetchActivityData(for: Date())
      let recoveryData = try? await healthKit.fetchRecoveryData(for: Date())

      let result = try await algorithm.calculateMultiFactorStress(
        context: StressContext(
          baseline: PersonalBaseline(),
          hrv: hrvValue,
          heartRate: heartRate,
          sleepData: sleepData,
          activityData: activityData,
          recoveryData: recoveryData,
          lastReadingDate: hrvData?.timestamp
        )
      )

      currentStress = result
      syncToPhone(result: result)
      syncToComplications(result: result)
      syncToSharedStore(result: result)
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func loadLatestStress() async {
    isLoading = true

    let data = await connectivity.requestData("fetchLatest")

    if let level = data["stressLevel"] as? Double,
      let categoryRaw = data["category"] as? String,
      let category = StressCategory(rawValue: categoryRaw),
      let confidence = data["confidence"] as? Double,
      let hrv = data["hrv"] as? Double,
      let heartRate = data["heartRate"] as? Double,
      let timestamp = data["timestamp"] as? Date
    {
      currentStress = StressResult(
        level: level,
        category: category,
        confidence: confidence,
        hrv: hrv,
        heartRate: heartRate,
        timestamp: timestamp
      )
      sharedStore.save(SharedReading(level: level, timestamp: timestamp))
    }

    isLoading = false
  }

  private func syncToPhone(result: StressResult) {
    let data: [String: Any] = [
      "stressLevel": result.level,
      "category": result.category.rawValue,
      "confidence": result.confidence,
      "hrv": result.hrv,
      "heartRate": result.heartRate,
      "timestamp": result.timestamp,
    ]

    connectivity.syncData(data)
  }

  private func syncToComplications(result: StressResult) {
    complicationProvider.saveMeasurement(result)
  }

  private func syncToSharedStore(result: StressResult) {
    sharedStore.save(SharedReading(level: result.level, timestamp: result.timestamp))
  }
}
