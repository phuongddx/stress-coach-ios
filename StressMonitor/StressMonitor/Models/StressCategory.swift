import SwiftUI

public enum StressCategory: String, CaseIterable, Codable, Sendable {
    case relaxed
    case mild
    case moderate
    case high
    case severe

    // MARK: - Dual Coding: Color

    /// Tier text colour (UI V2): passes 4.5:1 on the V2 canvas and surfaces in
    /// both appearances. Shapes, arcs and bars use `fillColor`.
    public var color: Color {
        switch self {
        case .relaxed: return Color("V2TierRelaxed")
        case .mild: return Color("V2TierMild")
        case .moderate: return Color("V2TierElevated")
        case .high: return Color("V2TierHigh")
        case .severe: return Color("V2TierSevere")
        }
    }

    // MARK: - Dual Coding: Icon

    /// SF Symbol icon for this stress category
    public var icon: String {
        switch self {
        case .relaxed: return "leaf.fill"
        case .mild: return "circle.fill"
        case .moderate: return "triangle.fill"
        case .high: return "square.fill"
        case .severe: return "octagon.fill"
        }
    }

    // MARK: - Dual Coding: Pattern Description

    /// Accessibility pattern description for color-blind users
    public var pattern: String {
        switch self {
        case .relaxed: return "solid fill"
        case .mild: return "diagonal lines"
        case .moderate: return "dots pattern"
        case .high: return "crosshatch"
        case .severe: return "solid warning"
        }
    }

    // MARK: - Accessibility

    /// VoiceOver description combining all dual coding elements
    public var accessibilityDescription: String {
        "\(displayName) stress level, represented by \(icon) icon with \(pattern)"
    }

    /// Accessibility hint for interactive stress indicators
    public var accessibilityHint: String {
        "Stress category indicator"
    }

    /// Accessibility value for stress level indicators
    /// - Parameter level: Stress level from 0-100
    public func accessibilityValue(level: Double) -> String {
        "\(Int(level)) out of 100, \(displayName) stress"
    }
}

// MARK: - Level-Derived Init + Display Name

extension StressCategory {
    init(from level: Double) {
        self = StressResult.category(for: level)
    }

    var displayName: String {
        switch self {
        case .relaxed: return "Relaxed"
        case .mild: return "Mild"
        case .moderate: return "Elevated"
        case .high: return "High"
        case .severe: return "Severe"
        }
    }
}

// MARK: - Stress Source

/// Represents a stress source with name, percentage, and color
struct StressSource: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let percentage: Double
    let color: Color
}
