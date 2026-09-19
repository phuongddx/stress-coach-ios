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

    private var headerRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(HomeCharacterDesignTokens.Ripple.primary.opacity(0.14))
                Text(initial)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(HomeCharacterDesignTokens.Ripple.deep)
            }
            .frame(width: 52, height: 52)
            .overlay(
                Circle()
                    .stroke(Color.Wellness.adaptiveSecondaryText.opacity(0.18), lineWidth: 0.5)
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                if let email {
                    Text(email)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 8)

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
        HStack(spacing: 0) {
            metricCell(
                value: bioAge.map { "\($0)" } ?? "—",
                label: "Bio",
                accessibilityValue: bioAge.map { "\($0) years" } ?? "unknown"
            )
            hairlineDivider
            metricCell(
                value: stressText,
                label: stressLabel,
                accessibilityValue: stressText
            )
            hairlineDivider
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
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(accessibilityValue)")
    }

    private var hairlineDivider: some View {
        Rectangle()
            .fill(Color.Wellness.adaptiveSecondaryText.opacity(0.18))
            .frame(width: 0.5, height: 32)
            .accessibilityHidden(true)
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
    .background(Color.appBackground)
}
