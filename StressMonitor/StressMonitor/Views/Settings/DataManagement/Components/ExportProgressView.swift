import SwiftUI

/// Progress view for data export operations
/// Displays progress bar, current operation, records processed, and estimated time remaining
struct ExportProgressView: View {
    let progress: Double // 0.0 to 1.0
    let currentOperation: String
    let recordsProcessed: Int
    let totalRecords: Int
    let estimatedTimeRemaining: TimeInterval?
    let isCancellable: Bool
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Progress indicator with animation
            ZStack {
                Circle()
                    .stroke(Color.V2.surface3, lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.V2.accent,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animateIfMotionAllowed(.easeInOut(duration: 0.3), value: progress)

                VStack(spacing: 4) {
                    Text("\(Int(progress * 100))%")
                        .font(.v2Number(.title, weight: .bold))
                        .foregroundStyle(Color.V2.ink)

                    Text("Complete")
                        .font(.caption)
                        .foregroundStyle(Color.V2.ink3)
                }
            }
            .accessibilityLabel("Export progress: \(Int(progress * 100)) percent complete")
            .accessibilityValue("\(recordsProcessed) of \(totalRecords) records processed")

            VStack(spacing: 12) {
                // Current operation
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(currentOperation)
                        .font(.body)
                        .foregroundStyle(Color.V2.ink)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous)
                        .fill(Color.V2.surface2)
                )

                // Records processed
                HStack {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(Color.V2.ink3)
                    Text("\(recordsProcessed) of \(totalRecords) records")
                        .font(.callout)
                        .foregroundStyle(Color.V2.ink3)
                        .monospacedDigit()
                    Spacer()
                }
                .padding(.horizontal, 20)

                // Estimated time remaining
                if let timeRemaining = estimatedTimeRemaining {
                    HStack {
                        Image(systemName: AppIconSystem.Metric.time.sfSymbol)
                            .foregroundStyle(Color.V2.ink3)
                        Text(estimatedTimeText(timeRemaining))
                            .font(.callout)
                            .foregroundStyle(Color.V2.ink3)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            }

            Spacer()

            // Cancel button (if cancellable)
            if isCancellable {
                Button(action: onCancel) {
                    Text("Cancel")
                }
                .buttonStyle(.v2(.secondary))
                .padding(.horizontal, 32)
                .accessibilityHint("Cancel the export operation")
            }
        }
        .padding(.top, 32)
        .padding(.bottom, 24)
    }

    private func estimatedTimeText(_ timeInterval: TimeInterval) -> String {
        if timeInterval < 60 {
            return "About \(Int(timeInterval)) seconds remaining"
        } else {
            let minutes = Int(timeInterval / 60)
            return "About \(minutes) minute\(minutes == 1 ? "" : "s") remaining"
        }
    }
}

/// Linear progress bar variant for use in cards
struct ExportProgressBarView: View {
    let progress: Double // 0.0 to 1.0
    let currentOperation: String
    let recordsProcessed: Int
    let totalRecords: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(currentOperation)
                    .font(.callout)
                    .foregroundStyle(Color.V2.ink)
                Spacer()
                Text("\(recordsProcessed)/\(totalRecords)")
                    .font(.v2Number(.caption))
                    .foregroundStyle(Color.V2.ink3)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(Color.V2.surface3)
                        .frame(height: 8)

                    // Progress fill
                    Capsule()
                        .fill(Color.V2.accent)
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animateIfMotionAllowed(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(currentOperation), \(recordsProcessed) of \(totalRecords) records, \(Int(progress * 100)) percent complete")
    }
}

#Preview {
    VStack(spacing: 40) {
        ExportProgressView(
            progress: 0.65,
            currentOperation: "Preparing data...",
            recordsProcessed: 650,
            totalRecords: 1000,
            estimatedTimeRemaining: 45,
            isCancellable: true,
            onCancel: {}
        )

        ExportProgressBarView(
            progress: 0.45,
            currentOperation: "Generating CSV...",
            recordsProcessed: 450,
            totalRecords: 1000
        )
        .padding()
    }
}
