import SwiftUI
import SwiftData

@Observable
class DetailViewModel {
    let measurement: StressMeasurement
    var baseline: PersonalBaseline?
    var todayAverage: Double?
    var weeklyAverage: Double?
    var trend: TrendDirection?
    var recommendations: [Recommendation] = []

    private let repository: StressRepositoryProtocol

    init(measurement: StressMeasurement, modelContext: ModelContext, baselineCalculator: BaselineCalculator? = nil) {
        self.measurement = measurement
        self.repository = StressRepository(modelContext: modelContext, baselineCalculator: baselineCalculator)
    }

    func loadData() async {
        do {
            async let bl = repository.getBaseline()
            async let today = repository.fetchAverageHRV(hours: 24)
            async let week = repository.fetchAverageHRV(days: 7)

            baseline = try await bl
            todayAverage = try await today
            weeklyAverage = try await week

            trend = calculateTrend()
            recommendations = generateRecommendations()
        } catch {}
    }

    var category: StressCategory {
        StressResult.category(for: measurement.stressLevel)
    }

    func shareMeasurement() {
        var lines = [
            "Stress Measurement - \(formatDate(measurement.timestamp))",
            "",
            "Stress Level: \(Int(measurement.stressLevel))/100"
        ]
        if measurement.hrv > 0 {
            lines.append("HRV: \(Int(measurement.hrv)) ms")
        }
        lines.append("Category: \(categoryTitle(category))")
        let text = lines.joined(separator: "\n")

        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func calculateTrend() -> TrendDirection {
        guard let today = todayAverage else { return .stable }
        let diff = measurement.hrv - today
        if diff > 5 { return .up }
        if diff < -5 { return .down }
        return .stable
    }

    private func generateRecommendations() -> [Recommendation] {
        switch category {
        case .high, .severe:
            return [
                Recommendation(
                    title: "Breathing Exercise",
                    description: "Take a 5-minute resonance breathing break",
                    icon: "wind",
                    action: .breathing
                ),
                Recommendation(
                    title: "Hydration",
                    description: "Drink a glass of water to support recovery",
                    icon: "drop",
                    action: .hydration
                )
            ]
        case .moderate:
            return [
                Recommendation(
                    title: "Short Walk",
                    description: "A 10-minute walk can help reduce stress",
                    icon: "figure.walk",
                    action: .walk
                )
            ]
        default:
            return [
                Recommendation(
                    title: "Keep it up!",
                    description: "Your stress is well-managed today",
                    icon: "checkmark.circle.fill",
                    action: .none
                )
            ]
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, YYYY"
        return formatter.string(from: date)
    }
}

struct Recommendation {
    let title: String
    let description: String
    let icon: String
    let action: RecommendationAction
}

enum RecommendationAction {
    case breathing
    case hydration
    case walk
    case none
}

func categoryTitle(_ category: StressCategory) -> String {
    switch category {
    case .relaxed: return "Relaxed"
    case .mild: return "Mild"
    case .moderate: return "Elevated"
    case .high: return "High"
    case .severe: return "Severe"
    }
}

func iconForCategory(_ category: StressCategory) -> String {
    Color.stressIcon(for: category)
}

func colorForCategory(_ category: StressCategory) -> Color {
    Color.stressColor(for: category)
}

func trendIcon(_ trend: TrendDirection) -> String {
    switch trend {
    case .up: return "arrow.up"
    case .down: return "arrow.down"
    case .stable: return "minus"
    }
}

func trendColor(_ trend: TrendDirection) -> Color {
    switch trend {
    case .up: return .stressRelaxed
    case .down: return .stressHigh
    case .stable: return .secondary
    }
}
