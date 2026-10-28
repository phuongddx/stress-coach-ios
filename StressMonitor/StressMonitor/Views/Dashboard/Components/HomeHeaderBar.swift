import SwiftUI

/// Compact Home header — date stamp on the left, bio-age + streak chips on the
/// right. Drops the decorative greeting per the 04-home spec: the date stamp and
/// the two information chips carry the header, freeing the hero to be the stress
/// indicator.
///
/// Spec reference: design/screens/04-home.html — `.date-row`.
struct HomeHeaderBar: View {
    let date: Date
    let bioAge: Int?
    let streakDays: Int

    init(date: Date = Date(), bioAge: Int? = nil, streakDays: Int = 0) {
        self.date = date
        self.bioAge = bioAge
        self.streakDays = streakDays
    }

    var body: some View {
        HStack {
            dateStamp
            Spacer(minLength: 8)
            chipRow
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dateStampVoiceover). \(bioAccessibility) \(streakAccessibility)")
    }

    // MARK: - Date stamp

    private var dateStamp: some View {
        Text(dateStampText)
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
    }

    private var dateStampText: String {
        let f = DateFormatter()
        f.amSymbol = "AM"
        f.pmSymbol = "PM"
        f.dateFormat = "EEE · MMM d · h:mm a"
        return f.string(from: date).uppercased()
    }

    private var dateStampVoiceover: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    // MARK: - Chips

    private var chipRow: some View {
        HStack(spacing: 6) {
            if let bioAge {
                bioChip(value: bioAge)
            }
            streakChip(days: streakDays)
        }
    }

    private func bioChip(value: Int) -> some View {
        HeaderChip(
            symbol: AppIconSystem.Setting.biologicalAge.sfSymbol,
            numberText: "\(value)",
            suffix: "BIO",
            accent: Color(hex: "#8B5CF6")
        )
        .accessibilityLabel("Biological age \(value) years")
    }

    private func streakChip(days: Int) -> some View {
        HeaderChip(
            symbol: AppIconSystem.Metric.streak.sfSymbol,
            numberText: "\(days)",
            suffix: "D",
            accent: Color.stressRelaxed
        )
        .accessibilityLabel("\(days) day streak")
    }

    private var bioAccessibility: String {
        bioAge.map { "Biological age \($0)." } ?? ""
    }

    private var streakAccessibility: String {
        "\(streakDays) day streak."
    }
}

// MARK: - HeaderChip

private struct HeaderChip: View {
    let symbol: String
    let numberText: String
    let suffix: String
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accent)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(numberText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(-0.3)
                Text(suffix)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.4)
            }
            .foregroundStyle(accent)
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background(accent.opacity(0.12))
        .overlay(Capsule().stroke(accent.opacity(0.24), lineWidth: 1))
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview("HomeHeaderBar") {
    VStack {
        HomeHeaderBar(bioAge: 26, streakDays: 7)
        Divider().padding(.vertical)
        HomeHeaderBar(bioAge: nil, streakDays: 0)
        Spacer()
    }
    .padding()
    .background(HomeCharacterDesignTokens.homeBackground)
}
