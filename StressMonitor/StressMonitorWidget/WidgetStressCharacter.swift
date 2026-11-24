import SwiftUI
import WidgetKit

// MARK: - StressTier (Widget)

/// Five-band stress representation for the Ripple character.
///
/// **Design rule:** never show a numeric stress score.
/// The character's pose (`WidgetRipplePose`) *is* the indicator.
///
/// - 0…20  → "Resting"
/// - 21…40 → "Calm"
/// - 41…60 → "Balanced"
/// - 61…80 → "Tense"
/// - 81…100→ "Overwhelmed"
enum WidgetStressTier: Int, CaseIterable, Sendable {
    case resting = 0
    case calm = 1
    case balanced = 2
    case tense = 3
    case overwhelmed = 4

    static func from(level: Double) -> WidgetStressTier {
        switch level {
        case ..<21:   return .resting
        case ..<41:   return .calm
        case ..<61:   return .balanced
        case ..<81:   return .tense
        default:      return .overwhelmed
        }
    }

    /// The companion face for a displayed category, so the face always
    /// matches the tier label beside it (the score bands in
    /// `StressResult.category(for:)` differ from `from(level:)`).
    static func from(category: StressCategory) -> WidgetStressTier {
        switch category {
        case .relaxed:  return .resting
        case .mild:     return .calm
        case .moderate: return .balanced
        case .high:     return .tense
        case .severe:   return .overwhelmed
        }
    }

    var accent: Color {
        switch self {
        case .resting:     return WidgetPalette.ripple
        case .calm:        return WidgetPalette.blossom
        case .balanced:    return WidgetPalette.lumi
        case .tense:       return WidgetPalette.ember
        case .overwhelmed: return WidgetPalette.zephyr
        }
    }
}

// MARK: - WidgetPalette

/// Companion colour ramp, re-pointed at the UI V2 companion tints and surfaces
/// (Theme/WidgetV2Tokens.swift). Companion tints are for backgrounds only.
enum WidgetPalette {
    static let ripple     = Color.V2.Companion.ripple
    static let blossom    = Color.V2.Companion.blossom
    static let lumi       = Color.V2.Companion.lumi
    static let ember      = Color.V2.Companion.ember
    static let zephyr     = Color.V2.Companion.zephyr
    static let darkCanvas = Color.V2.bg
    static let darkCard   = Color.V2.surface
    static let mutedInk   = Color.V2.ink3
}

// MARK: - WidgetCharacterFace

/// Reusable Ripple character face for widgets.
/// Shows the Ripple v2 head for the category on an accent-coloured ring —
/// **never a numeric score**. `nil` (no reading yet) shows the base pose.
struct WidgetCharacterFace: View {
    let category: StressCategory?
    var size: CGFloat = 64
    var showsRing: Bool = true
    var glow: Bool = false

    private var tier: WidgetStressTier {
        category.map { WidgetStressTier.from(category: $0) } ?? .resting
    }

    private var pose: WidgetRipplePose { WidgetRipplePose.from(category: category) }

    var body: some View {
        ZStack {
            if showsRing {
                Circle()
                    .stroke(tier.accent.opacity(0.2), lineWidth: ringWidth)

                Circle()
                    .trim(from: 0, to: fillFraction)
                    .stroke(
                        tier.accent,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            if glow {
                Circle()
                    .fill(tier.accent.opacity(0.15))
                    .frame(width: size * 0.6, height: size * 0.6)
                    .blur(radius: size * 0.06)
            }

            // Full colour in tinted / accented rendering (spec §4.4) so the
            // face stays readable instead of being flattened to the tint.
            Image(pose.headAssetName)
                .resizable()
                .widgetAccentedRenderingMode(.fullColor)
                .scaledToFit()
                .frame(width: headSize, height: headSize)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pose.accessibilityLabel)
    }

    private var ringWidth: CGFloat { max(3, size * 0.05) }
    /// The head art reaches the corners of its 512 artboard (ears), so keep it
    /// inside the ring / disc.
    private var headSize: CGFloat { size * (showsRing ? 0.62 : 0.92) }
    private var fillFraction: CGFloat {
        CGFloat(tier.rawValue + 1) / CGFloat(WidgetStressTier.allCases.count)
    }
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
