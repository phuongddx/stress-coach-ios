import Foundation
import SwiftData

/// Where a habit's value comes from: HealthKit auto-feed or user entry.
enum HabitSource: String, Codable, Sendable {
    case auto
    case manual
}

/// The three habits tracked on the Action tab.
enum HabitType: String, CaseIterable, Codable, Sendable, Identifiable {
    case hydration
    case caffeine
    case sunlight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hydration: return "Hydration"
        case .caffeine:  return "Caffeine"
        case .sunlight:  return "Sunlight"
        }
    }

    var icon: String {
        switch self {
        case .hydration: return "drop.fill"
        case .caffeine:  return "cup.and.saucer.fill"
        case .sunlight:  return "sun.max.fill"
        }
    }

    /// AUTO habits read from HealthKit; LOG habits are user-entered.
    /// Matches the Action tab pill styling: hydration + sunlight AUTO, caffeine LOG.
    var source: HabitSource {
        switch self {
        case .hydration, .sunlight: return .auto
        case .caffeine:             return .manual
        }
    }

    var unit: String {
        switch self {
        case .hydration: return "L"
        case .caffeine:  return "cups"
        case .sunlight:  return "min"
        }
    }

    var goal: Double {
        switch self {
        case .hydration: return 2.0
        case .caffeine:  return 3
        case .sunlight:  return 60
        }
    }
}

/// Persisted daily habit log. One row per habit per day.
@Model
final class Habit {
    var id: UUID = UUID()
    var type: HabitType = HabitType.hydration
    var currentValue: Double = 0
    var goalValue: Double = 0
    var source: HabitSource = HabitSource.auto
    var date: Date = Date()

    /// True once HealthKit has supplied today's value for an AUTO habit. Not
    /// persisted: an AUTO row without it has no measurement, so it renders "—"
    /// instead of the seeded 0.
    @Transient var isAutoValueAvailable: Bool = false

    init(
        id: UUID = UUID(),
        type: HabitType,
        currentValue: Double = 0,
        goalValue: Double? = nil,
        source: HabitSource? = nil,
        date: Date = Date(),
        isAutoValueAvailable: Bool = false
    ) {
        self.id = id
        self.type = type
        self.currentValue = currentValue
        self.goalValue = goalValue ?? type.goal
        self.source = source ?? type.source
        self.date = date
        self.isAutoValueAvailable = isAutoValueAvailable
    }

    /// True when the row has a real value to show. Manual rows always do (0
    /// cups is a user fact); AUTO rows only after HealthKit reported.
    var hasDisplayValue: Bool {
        source == .manual || isAutoValueAvailable
    }
}
