import SwiftUI

/// Watch **Cycle** screen — current menstrual-cycle phase and context (UI V2).
///
/// A cycle ring (day of cycle / length) next to "Day N · of L · Phase",
/// then cards for the next phase, the predicted next period and a short
/// stress-correlation note. Scrolled with the Digital Crown.
struct WatchCycleView: View {
    @State private var viewModel = WatchCycleViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                if let data = viewModel.cycleData {
                    phaseHeader(data)
                    infoCard(
                        title: "Next phase",
                        value: viewModel.predictNextPhase().displayName
                    )
                    if let prediction = data.nextPrediction {
                        infoCard(
                            title: "Next period",
                            value: prediction.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                    if let note = viewModel.stressCorrelationForToday() {
                        correlationNote(note)
                    }
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            .padding(.bottom, 12)
        }
        .background(WatchDesignTokens.canvas.ignoresSafeArea())
        .navigationTitle("Cycle")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Phase header (ring + day)

    private func phaseHeader(_ data: CycleData) -> some View {
        let fraction = CGFloat(min(max(Double(data.dayOfCycle) / Double(max(data.cycleLength, 1)), 0), 1))
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(WatchV2.surface2, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(WatchV2.cycle, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: data.currentPhase.icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(WatchV2.cycle)
            }
            .frame(width: 52, height: 52)
            .padding(3.5)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text("Day \(data.dayOfCycle)")
                    .font(.v2Number(.title3, weight: .bold))
                    .foregroundStyle(WatchV2.ink)
                Text("of \(data.cycleLength) · \(data.currentPhase.displayName)")
                    .font(.caption2)
                    .foregroundStyle(WatchV2.ink2)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Info card

    private func infoCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(WatchV2.ink3)
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(WatchV2.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: WatchV2.radiusCard, style: .continuous)
                .fill(WatchV2.surface)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Correlation note

    private func correlationNote(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "waveform.path.ecg")
                    .imageScale(.small)
                    .accessibilityHidden(true)
                Text("Stress note")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(WatchV2.accent)
            Text(note)
                .font(.footnote)
                .foregroundStyle(WatchV2.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: WatchV2.radiusCard, style: .continuous)
                .fill(WatchV2.accentSoft)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "drop")
                .font(.title2)
                .foregroundStyle(WatchV2.cycle)
                .accessibilityHidden(true)
            Text("No cycle logged")
                .font(.headline)
                .foregroundStyle(WatchV2.ink)
            Text("Log the start of your cycle to see predictions and stress correlations.")
                .font(.footnote)
                .foregroundStyle(WatchV2.ink3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
            Button {
                viewModel.logCycleStart(Date())
            } label: {
                Text("Log Today")
                    .font(.headline)
                    .foregroundStyle(WatchV2.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 36)
                    .background(Capsule(style: .continuous).fill(WatchV2.accent))
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
        }
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        WatchCycleView()
    }
}
#endif
