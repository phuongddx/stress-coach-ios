import SwiftUI

// MARK: - Plus Chart ID

/// Every iPhone chart that only Plus shows unblurred (SPEC 6.3). Each case is
/// attached at exactly one `.plusLocked(_:)` call site.
enum PlusChartID: String, CaseIterable, Hashable {
    case homeStressOverTime
    case trendsDailyBars
    case trendsDistribution
    case trendsCalendar
    case trendsHRV
    case bioAgeDaily
    case breathingBeforeAfter

    /// Spoken name used in the locked chart's accessibility label.
    var displayName: String {
        switch self {
        case .homeStressOverTime: return "Stress over time"
        case .trendsDailyBars: return "Daily stress"
        case .trendsDistribution: return "Time spent by tier"
        case .trendsCalendar: return "Monthly heatmap"
        case .trendsHRV: return "HRV trend"
        case .bioAgeDaily: return "Biological age"
        case .breathingBeforeAfter: return "Before and after HRV"
        }
    }
}

// MARK: - Lock Presentation

/// Copy for a locked chart, kept free of SwiftUI so it can be unit tested.
struct PlusLockPresentation: Equatable {
    let message: String
    let buttonTitle: String
    let accessibilityLabel: String
    let accessibilityHint: String

    /// Nil when the chart is not locked: the content is then shown untouched.
    static func make(isLocked: Bool, trialEligible: Bool, chart: PlusChartID) -> PlusLockPresentation? {
        guard isLocked else { return nil }
        return PlusLockPresentation(
            message: "See your full chart with Plus",
            buttonTitle: trialEligible ? "Try Plus free" : "Unlock Plus",
            accessibilityLabel: "\(chart.displayName) chart locked",
            accessibilityHint: "Double-tap to unlock Plus"
        )
    }
}

// MARK: - Modifier

private struct PlusLockedModifier: ViewModifier {
    let chart: PlusChartID
    // Optional so previews and tests that render a chart without the app
    // root's environment fall back to the shared rules instead of trapping.
    @Environment(PlusAccess.self) private var injectedAccess: PlusAccess?
    @Environment(PaywallController.self) private var paywall: PaywallController?

    func body(content: Content) -> some View {
        let plusAccess = injectedAccess ?? .shared
        if let presentation = PlusLockPresentation.make(
            isLocked: plusAccess.isChartLocked,
            trialEligible: plusAccess.trialAvailable,
            chart: chart
        ) {
            content
                .blur(radius: 12)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .overlay {
                    PlusLockOverlay(presentation: presentation) {
                        paywall?.present(reason: .chart(chart))
                    }
                }
        } else {
            content
        }
    }
}

// MARK: - Overlay

private struct PlusLockOverlay: View {
    let presentation: PlusLockPresentation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Short charts (the tier bar) only fit the compact row.
            ViewThatFits(in: .vertical) {
                fullLayout
                compactLayout
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityHint(presentation.accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }

    private var fullLayout: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "lock.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.iapHeaderTeal)
            Text(presentation.message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            pill
        }
        .padding(DesignTokens.Spacing.md)
    }

    private var compactLayout: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.iapHeaderTeal)
            pill
        }
    }

    private var pill: some View {
        Text(presentation.buttonTitle)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .frame(minHeight: 32)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Color.iapCTATeal, Color.iapHeaderTeal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            )
    }
}

// MARK: - View Extension

extension View {
    /// Blurs this chart when `PlusAccess.isChartLocked` and covers it with
    /// an invitation to Plus; a tap opens the paywall for `chart`. When the
    /// chart is not locked the view is returned unchanged.
    func plusLocked(_ chart: PlusChartID) -> some View {
        modifier(PlusLockedModifier(chart: chart))
    }
}

// MARK: - Previews

#if DEBUG
@MainActor
private func previewAccess(locked: Bool, trial: Bool) -> PlusAccess {
    let suite = "PlusLockedPreview.\(locked).\(trial)"
    let defaults = UserDefaults(suiteName: suite) ?? .standard
    defaults.removePersistentDomain(forName: suite)
    let access = PlusAccess(
        premiumState: PremiumState(defaults: defaults, key: "isPremiumUser"),
        availability: locked ? .enabled : .postponed(reason: .awaitingAppStoreProducts),
        defaults: defaults
    )
    access.markCatalogLoaded(true)
    access.updateTrial(available: trial, periodUnit: trial ? "14-day" : nil)
    return access
}

private struct PlusLockedPreviewChart: View {
    var body: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Layout.cornerRadius)
            .fill(LinearGradient(colors: [.green, .orange, .red], startPoint: .leading, endPoint: .trailing))
            .frame(height: 180)
            .padding()
    }
}

#Preview("Locked, trial available") {
    PlusLockedPreviewChart()
        .plusLocked(.trendsHRV)
        .environment(previewAccess(locked: true, trial: true))
        .environment(PaywallController())
}

#Preview("Locked, no trial") {
    PlusLockedPreviewChart()
        .plusLocked(.trendsHRV)
        .environment(previewAccess(locked: true, trial: false))
        .environment(PaywallController())
}

#Preview("Unlocked") {
    PlusLockedPreviewChart()
        .plusLocked(.trendsHRV)
        .environment(previewAccess(locked: false, trial: true))
        .environment(PaywallController())
}
#endif
