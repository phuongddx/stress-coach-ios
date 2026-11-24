import Charts
import SwiftUI
import WidgetKit

// MARK: - Tier Copy

extension StressCategory {
    /// Short line shown under a score (same copy as the app's `v2Substate`).
    var v2Substate: String {
        switch self {
        case .relaxed: return "Calm · recovered"
        case .mild: return "Focused · steady"
        case .moderate: return "Tense · busy"
        case .high: return "Wired · ease off"
        case .severe: return "Running hot · time to reset"
        }
    }

    /// One Ripple line for the large widget (shortened from the app's Action tab copy).
    var widgetTip: String {
        switch self {
        case .relaxed, .mild: return "A slow breath keeps you here."
        case .moderate: return "A 2-minute box breath helps bring it down."
        case .high: return "Box breathing first, then a short walk."
        case .severe: return "Start with a slow breath, then step away for a few minutes."
        }
    }
}

// MARK: - Reading Text

/// Display strings built only from the timeline entry that already exists.
enum WidgetReadingText {
    static func score(_ level: Double) -> String {
        "\(Int(level.rounded()))"
    }

    /// "9:20 PM" for a fresh reading.
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "2d ago" for a stale reading.
    static func age(_ date: Date) -> String {
        date.formatted(.relative(presentation: .numeric, unitsStyle: .narrow))
    }

    /// "Updated 9:20 PM" when fresh, "Updated 2d ago" when stale.
    static func updated(_ stress: StressData, state: WidgetDataState) -> String {
        state == .stale ? "Updated \(age(stress.timestamp))" : "Updated \(time(stress.timestamp))"
    }

    /// One VoiceOver summary for a whole widget.
    static func accessibilitySummary(_ stress: StressData?, state: WidgetDataState) -> String {
        guard let stress else { return "Stress, no reading yet" }
        let category = stress.stressCategory
        return "Stress \(score(stress.level)) of 100, \(category.displayName). \(updated(stress, state: state))"
    }
}

// MARK: - Score

/// The score in rounded, tabular digits, or "—" when there is no reading.
struct WidgetScoreText: View {
    let level: Double?
    var style: Font.TextStyle = .largeTitle

    var body: some View {
        Text(level.map(WidgetReadingText.score) ?? "—")
            .font(.v2Number(style))
            .foregroundStyle(level == nil ? Color.V2.ink3 : Color.V2.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .widgetAccentable()
    }
}

// MARK: - Tier Label

/// Tier shape + name in the tier text colour. `compact` shows the shape only and
/// keeps the name as the accessibility label. Outside full-colour rendering the
/// shape and name carry the tier and the colour falls back to `.primary`.
struct WidgetTierLabel: View {
    let category: StressCategory
    var compact: Bool = false
    var font: Font = .subheadline.weight(.semibold)

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .imageScale(.small)
            if !compact {
                Text(category.displayName)
                    .lineLimit(1)
            }
        }
        .font(font)
        .foregroundStyle(renderingMode.showsTierColor ? category.color : Color.primary)
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.displayName)
    }
}

// MARK: - Companion

/// The widget's Ripple v2 head on the companion disc. `nil` (no reading yet)
/// shows the base pose. Decorative: the score and tier carry the meaning, so
/// it is hidden from VoiceOver.
///
/// Light mode puts the head on a solid teal `#206A5D` chip, because the suit
/// outline is too faint on the light surface (spec §4.3). Dark mode keeps the
/// soft companion-tint disc.
struct WidgetCompanionBadge: View {
    let category: StressCategory?
    var size: CGFloat = 44

    @Environment(\.colorScheme) private var colorScheme

    private static let lightChip = Color(hex: "206A5D")

    private var discColor: Color {
        if colorScheme == .light { return Self.lightChip }
        let tier = category.map { WidgetStressTier.from(category: $0) } ?? .resting
        return tier.accent.opacity(0.22)
    }

    var body: some View {
        WidgetCharacterFace(category: category, size: size * 0.86, showsRing: false)
            .frame(width: size, height: size)
            .background(Circle().fill(discColor))
            .accessibilityHidden(true)
    }
}

// MARK: - History

/// History readings oldest first, newest last, capped at `limit`.
func widgetRecentReadings(_ history: [StressData], limit: Int) -> [StressData] {
    Array(history.sorted { $0.timestamp < $1.timestamp }.suffix(limit))
}

private func historyAccessibilityLabel(_ readings: [StressData]) -> String {
    let levels = readings.map(\.level)
    guard let high = levels.max(), let low = levels.min() else { return "Recent readings" }
    return "Recent readings: \(readings.count) readings, highest \(WidgetReadingText.score(high)), lowest \(WidgetReadingText.score(low))"
}

/// Accent line with a dot per reading; the newest dot is larger. No axes.
struct WidgetTrendLine: View {
    let readings: [StressData]

    var body: some View {
        Chart {
            ForEach(readings) { item in
                LineMark(x: .value("Time", item.timestamp), y: .value("Stress", item.level))
                    .foregroundStyle(Color.V2.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                PointMark(x: .value("Time", item.timestamp), y: .value("Stress", item.level))
                    .foregroundStyle(Color.V2.accent)
                    .symbolSize(item.id == readings.last?.id ? 60 : 20)
            }
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(historyAccessibilityLabel(readings))
    }
}

/// One bar per reading in its tier fill colour. No axes.
struct WidgetHistoryBars: View {
    let readings: [StressData]

    var body: some View {
        Chart {
            ForEach(Array(readings.enumerated()), id: \.offset) { index, item in
                BarMark(x: .value("Reading", "\(index)"), y: .value("Stress", max(item.level, 4)))
                    .foregroundStyle(item.stressCategory.fillColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(historyAccessibilityLabel(readings))
    }
}

/// Shown where the history chart goes until the app has published two readings.
struct WidgetGatheringView: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "waveform.path.ecg")
                .font(.title3)
                .foregroundStyle(Color.V2.ink3)
                .accessibilityHidden(true)
            Text("Gathering data…")
                .font(.footnote)
                .foregroundStyle(Color.V2.ink3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Home Screen Container

extension View {
    /// Shared chrome for the home-screen families: V2 surface as the system
    /// container background, placeholder redaction, and a Dynamic Type cap so
    /// the fixed widget frame cannot clip.
    func widgetV2HomeContainer(isPlaceholder: Bool) -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .redacted(reason: isPlaceholder ? .placeholder : [])
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .containerBackground(Color.V2.surface, for: .widget)
    }
}
