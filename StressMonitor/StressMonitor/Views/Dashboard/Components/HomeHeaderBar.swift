import SwiftUI

/// Home header (UI V2): the date on the left, bio-age and streak tags on the
/// right, then a large time-of-day greeting.
///
/// Spec reference: ui-v2-design/screens.js `S.home` head.
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
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    dateStamp
                    Spacer(minLength: 8)
                    chipRow
                }
                VStack(alignment: .leading, spacing: 8) {
                    dateStamp
                    chipRow
                }
            }
            .frame(minHeight: V2Metrics.minTouchTarget)

            Text(greeting)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.V2.ink)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(greeting). \(dateStampVoiceover). \(bioAccessibility) \(streakAccessibility)")
    }

    // MARK: - Date stamp

    private var dateStamp: some View {
        Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.V2.ink3)
    }

    private var dateStampVoiceover: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: - Chips

    private var chipRow: some View {
        HStack(spacing: 6) {
            if let bioAge {
                HeaderTag(
                    symbol: AppIconSystem.Setting.biologicalAge.sfSymbol,
                    text: "Bio age \(bioAge)",
                    foreground: Color.V2.plus,
                    background: Color.V2.plusBg
                )
                .accessibilityLabel("Biological age \(bioAge) years")
            }
            HeaderTag(
                symbol: AppIconSystem.Metric.streak.sfSymbol,
                text: "\(streakDays)-day streak",
                foreground: Color.V2.accent,
                background: Color.V2.accentSoft
            )
            .accessibilityLabel("\(streakDays) day streak")
        }
    }

    private var bioAccessibility: String {
        bioAge.map { "Biological age \($0)." } ?? ""
    }

    private var streakAccessibility: String {
        "\(streakDays) day streak."
    }
}

// MARK: - HeaderTag

private struct HeaderTag: View {
    let symbol: String
    let text: String
    let foreground: Color
    let background: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(text)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(background))
        .lineLimit(1)
        .fixedSize()
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
    .background(Color.V2.bg)
}
