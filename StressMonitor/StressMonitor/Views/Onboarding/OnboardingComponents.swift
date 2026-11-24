import SwiftUI

// MARK: - Onboarding shared pieces (UI V2)

/// Step dots above each onboarding CTA (v2.css `.dots`): the current step is
/// a wide accent capsule, finished steps are accent dots and upcoming steps
/// `line2` dots. Each dot is a 44 pt button so a finished step can be
/// revisited; skipping ahead more than one step stays disabled.
struct OnboardingStepDots: View {
    static let stepNames = ["Welcome", "Permissions", "Dashboard"]

    let current: Int
    var onSelect: ((Int) -> Void)?

    var body: some View {
        HStack(spacing: -22) {
            ForEach(0..<Self.stepNames.count, id: \.self) { index in
                dot(index: index)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: V2Metrics.minTouchTarget)
    }

    private func dot(index: Int) -> some View {
        let isCurrent = index == current
        return Button(action: { onSelect?(index) }) {
            Capsule()
                .fill(index <= current ? Color.V2.accent : Color.V2.line2)
                .frame(width: isCurrent ? 20 : 8, height: 8)
                .frame(width: V2Metrics.minTouchTarget, height: V2Metrics.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(index > current + 1) // Can't skip ahead
        .accessibilityLabel("Step \(index + 1) of \(Self.stepNames.count), \(Self.stepNames[index])")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

/// 44 pt chevron-only Back button used at the top of onboarding screens.
struct OnboardingBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: AppIconSystem.Nav.back.sfSymbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.V2.accent)
                .frame(width: V2Metrics.minTouchTarget, height: V2Metrics.minTouchTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

/// Icon tile + title + one line, as used in the onboarding cards and the
/// Health purpose list (v2.css `.ic.soft` + `.sh b` + `.fn mute`).
struct OnboardingInfoRow: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.V2.accent)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: V2Metrics.radiusXS, style: .continuous)
                        .fill(Color.V2.accentSoft)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.V2.ink)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Color.V2.ink2)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}
