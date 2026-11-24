import SwiftUI

/// Top-of-Settings identity card: avatar with initial, name/email row, Plus upsell pill,
/// and a 3-metric snapshot row (Bio age · Stress · Streak) separated by hairline dividers.
struct MeHeroCard: View {
    var bioAge: Int? = nil
    var stressLevel: Double? = nil
    var streakDays: Int = 0
    var displayName: String = "You"
    var email: String? = nil
    var onPlusTap: (() -> Void)? = nil

    @ScaledMetric(relativeTo: .title2) private var avatarSize: CGFloat = 52

    private var initial: String {
        String(displayName.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    var body: some View {
        SettingsCard {
            VStack(spacing: 16) {
                headerRow
                metricRow
            }
        }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var headerRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 14))
        return layout {
            ZStack {
                Circle()
                    .fill(Color.V2.accentSoft)
                Text(initial)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.V2.accent)
            }
            .frame(width: avatarSize, height: avatarSize)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.headline)
                    .foregroundStyle(Color.V2.ink)
                if let email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(Color.V2.ink3)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 8)
            }

            // Omitted when the owner supplies no tap handler — the upsell has
            // nowhere to go, so it must not render.
            if let onPlusTap {
                PlusPill(onTap: onPlusTap)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName). Bio age \(bioAge.map(String.init) ?? "unknown"). Stress \(stressLabel). \(streakDays) day streak.")
    }

    private var metricRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            metricCell(
                value: bioAge.map { "\($0)" } ?? "—",
                label: "Bio",
                accessibilityValue: bioAge.map { "\($0) years" } ?? "unknown"
            )
            metricCell(
                value: stressText,
                label: stressLabel,
                accessibilityValue: stressText
            )
            metricCell(
                value: "\(streakDays)d",
                label: "Streak",
                accessibilityValue: "\(streakDays) day streak"
            )
        }
    }

    private func metricCell(value: String, label: String, accessibilityValue: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.v2Number(.title2))
                .foregroundStyle(Color.V2.ink)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.V2.ink3)
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: V2Metrics.radiusSM, style: .continuous)
                .fill(Color.V2.surface2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(accessibilityValue)")
    }

    private var stressText: String {
        guard let level = stressLevel else { return "—" }
        return "\(Int(level.rounded()))"
    }

    private var stressLabel: String {
        guard let level = stressLevel else { return "Stress" }
        return StressCategory(from: level).displayName
    }
}

#Preview {
    VStack(spacing: 16) {
        MeHeroCard(bioAge: 26, stressLevel: 42, streakDays: 7, displayName: "Alex", email: "alex@ripple.app")
        MeHeroCard(displayName: "Guest")
    }
    .padding()
    .background(Color.V2.bg)
}
