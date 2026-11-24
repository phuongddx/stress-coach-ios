import SwiftUI

/// 5-tier stress category — single source of truth for the watch app.
///
/// Aligned with the iOS app's `StressCategory` and the UI V2 stress scale.
/// The tier is always shown three ways — colour, shape (`icon`) and name —
/// so colour is never the only encoding (WCAG).
///
/// | Tier      | Score range | Colour (V2 dark) | Shape          |
/// |-----------|-------------|------------------|----------------|
/// | Relaxed   | 0–24        | `tierRelaxed`    | `leaf.fill`    |
/// | Mild      | 25–49       | `tierMild`       | `circle.fill`  |
/// | Elevated  | 50–74       | `tierElevated`   | `triangle.fill`|
/// | High      | 75–89       | `tierHigh`       | `square.fill`  |
/// | Severe    | 90+         | `tierSevere`     | `octagon.fill` |
public enum StressCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case relaxed
    case mild
    case moderate
    case high
    case severe

    public var id: String { rawValue }

    // MARK: - Dual Coding: Colour

    /// Tier colour (UI V2 dark — text and fill share one value on black).
    public var color: Color {
        switch self {
        case .relaxed:  return WatchV2.tierRelaxed
        case .mild:     return WatchV2.tierMild
        case .moderate: return WatchV2.tierElevated
        case .high:     return WatchV2.tierHigh
        case .severe:   return WatchV2.tierSevere
        }
    }

    /// Text colour on dark surfaces. In V2 dark the tier text colour equals
    /// the fill colour.
    public var inkColor: Color { color }

    /// Fill colour for bars, gauge arcs and heatmap cells.
    public var fillColor: Color { color }

    // MARK: - Dual Coding: Glyph + Icon

    /// Geometric glyph used in tier labels (always paired with the colour).
    public var glyph: String {
        switch self {
        case .relaxed:  return "◌"
        case .mild:     return "◎"
        case .moderate: return "◐"
        case .high:     return "◑"
        case .severe:   return "●"
        }
    }

    /// SF Symbol icon for this stress category.
    public var icon: String {
        switch self {
        case .relaxed:  return "leaf.fill"
        case .mild:     return "circle.fill"
        case .moderate: return "triangle.fill"
        case .high:     return "square.fill"
        case .severe:   return "octagon.fill"
        }
    }

    // MARK: - Display

    /// Capitalised display name ("Relaxed", "Mild", …) for tier labels.
    ///
    /// `.moderate` reads "Elevated" to match the iOS app's
    /// `StressCategory.displayName` — `TierNamePreferences` (which still
    /// defaults `.moderate` to "Moderate") has no call sites anywhere in the
    /// watch target and is keyed to the unrelated `WatchStressCategory`
    /// type, so it cannot justify a cross-platform naming mismatch for a
    /// synced measurement.
    public var displayName: String {
        switch self {
        case .relaxed:  return "Relaxed"
        case .mild:     return "Mild"
        case .moderate: return "Elevated"
        case .high:     return "High"
        case .severe:   return "Severe"
        }
    }

    /// Short label combining the glyph and name ("◌ Relaxed").
    public var glyphLabel: String { "\(glyph) \(displayName)" }

    /// Non-overlapping integer endpoints — a boundary score (25, 50, 75, 90) belongs to exactly one tier, matching `category(for:)`.
    public var scoreRange: ClosedRange<Double> {
        switch self {
        case .relaxed:  return 0...24
        case .mild:     return 25...49
        case .moderate: return 50...74
        case .high:     return 75...89
        case .severe:   return 90...150
        }
    }

    // MARK: - Pattern / Accessibility

    public var pattern: String {
        switch self {
        case .relaxed:  return "solid fill"
        case .mild:     return "diagonal lines"
        case .moderate: return "dots pattern"
        case .high:     return "crosshatch"
        case .severe:   return "solid warning"
        }
    }

    public var accessibilityDescription: String {
        "\(displayName) stress level, represented by \(icon) icon with \(pattern)"
    }

    public func accessibilityValue(level: Double) -> String {
        "\(Int(level)) out of 100, \(displayName) stress"
    }

    // MARK: - Resolution

    /// Resolve the tier from a raw 0–100+ stress level. Boundaries mirror
    /// the iOS app's `StressResult.category(for:)`.
    public static func category(for level: Double) -> StressCategory {
        switch level {
        case ..<25: return .relaxed
        case ..<50: return .mild
        case ..<75: return .moderate
        case ..<90: return .high
        default:    return .severe
        }
    }
}

// MARK: - Stress Source

/// Represents a stress source with name, percentage, and colour.
struct StressSource: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let percentage: Double
    let color: Color
}
