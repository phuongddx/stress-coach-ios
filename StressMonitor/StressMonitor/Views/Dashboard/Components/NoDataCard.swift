import SwiftUI

/// Reusable card component for displaying no data states
/// Used for individual metrics like HRV, Heart Rate, etc.
struct NoDataCard: View {
    let dataType: DataType
    let onAction: () -> Void

    enum DataType: String, CaseIterable {
        case hrv
        case heartRate
        case stress
        case timeline
        case trends

        var icon: String {
            switch self {
            case .hrv: return "heart.circle"
            case .heartRate: return "waveform.path.ecg"
            case .stress: return "brain.head.profile"
            case .timeline: return "clock"
            case .trends: return "chart.bar"
            }
        }

        var title: String {
            switch self {
            case .hrv: return "No HRV Data"
            case .heartRate: return "No Heart Rate Data"
            case .stress: return "No Stress Data"
            case .timeline: return "No Timeline Data"
            case .trends: return "No Trends Yet"
            }
        }

        var description: String {
            switch self {
            case .hrv: return "HRV data will appear here after your first measurement."
            case .heartRate: return "Heart rate data will sync from Apple Watch."
            case .stress: return "Measure stress to see your patterns here."
            case .timeline: return "Timeline will populate as you take measurements."
            case .trends: return "Measure stress for a few days to see your patterns here."
            }
        }

        var actionTitle: String {
            switch self {
            case .hrv, .heartRate, .stress: return "Measure Now"
            case .timeline: return "Get Started"
            case .trends: return "Refresh"
            }
        }
    }

    var body: some View {
        V2Card {
            V2StateView(
                systemImage: dataType.icon,
                title: dataType.title,
                message: dataType.description,
                actionTitle: dataType.actionTitle,
                action: onAction
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dataType.title). \(dataType.description)")
        .accessibilityHint("Double tap to \(dataType.actionTitle.lowercased())")
    }
}

// MARK: - Preview

#Preview("All No Data Cards") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(NoDataCard.DataType.allCases, id: \.self) { type in
                NoDataCard(dataType: type, onAction: {})
            }
        }
        .padding()
    }
    .background(Color.V2.bg)
}
