import Observation
import SwiftData
import SwiftUI
import WidgetKit

@MainActor
@Observable
final class CharacterCollectionViewModel {
    var unlocks: [CharacterUnlock] = []
    var activeCharacterId: String?
    var currentStressLevel: Double = 0

    private var modelContext: ModelContext?
    private let characterSync = CharacterSelectionSync.shared

    /// Mood derived from the latest stress reading — drives character facial expression.
    var currentMood: RippleMood {
        RippleMood.from(stressLevel: currentStressLevel)
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        seedDefaultUnlocksIfNeeded(in: modelContext)
        Self.syncProgress(in: modelContext)
        fetchUnlocks()
        fetchLatestStressLevel()
    }

    func fetchUnlocks() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<CharacterUnlock>(sortBy: [SortDescriptor(\.characterId)])
        unlocks = (try? ctx.fetch(descriptor)) ?? []
        activeCharacterId = unlocks.first(where: { $0.isActive })?.characterId
    }

    func unlockStatus(for characterId: String) -> CharacterUnlock? {
        unlocks.first(where: { $0.characterId == characterId })
    }

    func selectCharacter(_ characterId: String) {
        guard let selected = unlockStatus(for: characterId), selected.isUnlocked else { return }

        for unlock in unlocks {
            unlock.isActive = (unlock.characterId == characterId)
        }
        activeCharacterId = characterId
        try? modelContext?.save()
        characterSync.saveActiveCharacter(characterId: characterId, evolution: selected.evolutionStage)
    }

    /// Fetch the latest stress reading so character mood reflects the user's actual state.
    private func fetchLatestStressLevel() {
        guard let ctx = modelContext else { return }
        var descriptor = FetchDescriptor<StressMeasurement>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let latest = try? ctx.fetch(descriptor).first {
            currentStressLevel = latest.stressLevel
        }
    }

    private func seedDefaultUnlocksIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<CharacterUnlock>()
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        for creature in CharacterCreature.allCharacters {
            let isFree = creature.unlockType == .free
            let unlock = CharacterUnlock(
                characterId: creature.id,
                isUnlocked: isFree,
                currentEvolution: .droplet,
                isActive: creature.id == "ripple"
            )
            context.insert(unlock)
        }

        try? context.save()
    }

    /// Writes the real measurement streak onto every `CharacterUnlock`, then applies
    /// the unlock and evolution rules against it. Unlocks and evolutions are
    /// permanent: a later streak break never reverts them.
    @MainActor
    static func syncProgress(in context: ModelContext, now: Date = Date(), calendar: Calendar = .current) {
        guard let unlocks = try? context.fetch(FetchDescriptor<CharacterUnlock>()) else { return }

        let streak = currentMeasurementStreak(in: context, now: now, calendar: calendar)
        var activeEvolved: CharacterUnlock?

        for unlock in unlocks {
            unlock.streakDays = streak

            if !unlock.isUnlocked,
               let creature = CharacterCreature.find(by: unlock.characterId),
               creature.unlockType == .streakGated,
               streak >= creature.streakRequired {
                unlock.isUnlocked = true
                unlock.unlockedAt = now
            }

            if unlock.isUnlocked, unlock.canEvolve,
               let next = EvolutionStage.allCases.first(where: { $0.sortOrder == unlock.evolutionStage.sortOrder + 1 }) {
                unlock.evolutionStage = next
                unlock.lastEvolvedAt = now
                if unlock.isActive { activeEvolved = unlock }
            }
        }

        try? context.save()

        if let activeEvolved {
            CharacterSelectionSync.shared.saveActiveCharacter(
                characterId: activeEvolved.characterId,
                evolution: activeEvolved.evolutionStage
            )
        }
    }

    /// Counts a completed breathing session toward the active character's evolution.
    @MainActor
    static func recordBreathingSession(in context: ModelContext, now: Date = Date()) {
        let descriptor = FetchDescriptor<CharacterUnlock>(predicate: #Predicate { $0.isActive })
        guard let active = (try? context.fetch(descriptor))?.first else { return }
        active.sessionsCompleted += 1
        try? context.save()
        syncProgress(in: context, now: now)
    }

    private static func currentMeasurementStreak(in context: ModelContext, now: Date, calendar: Calendar) -> Int {
        guard let start = calendar.date(byAdding: .day, value: -MeasurementStreak.lookbackDays, to: calendar.startOfDay(for: now)) else {
            return 0
        }
        let descriptor = FetchDescriptor<StressMeasurement>(predicate: #Predicate { $0.timestamp >= start })
        let measurements = (try? context.fetch(descriptor)) ?? []
        return MeasurementStreak.days(from: measurements.map(\.timestamp), calendar: calendar, now: now)
    }

    /// Reconciles premium-character unlocks with live subscription status.
    /// Premium unlocks are one-time-permanent: subscribing grants them, but a
    /// subscription lapse does NOT re-lock them. Active selection of a premium
    /// character falls back to Ripple on lapse so the user lands on a free char.
    @MainActor
    static func syncPremiumCharacterEntitlement(isPremium: Bool, in context: ModelContext) {
        let descriptor = FetchDescriptor<CharacterUnlock>()
        let unlocks = (try? context.fetch(descriptor)) ?? []

        let premiumIds = Set(CharacterCreature.allCharacters.filter { $0.unlockType == .premium }.map(\.id))

        var activeReLocked = false
        for unlock in unlocks where premiumIds.contains(unlock.characterId) {
            if isPremium {
                unlock.isUnlocked = true
            }
            if !isPremium && unlock.isActive {
                unlock.isActive = false
                activeReLocked = true
            }
        }

        if activeReLocked, let ripple = unlocks.first(where: { $0.characterId == "ripple" }) {
            ripple.isActive = true
            CharacterSelectionSync.shared.saveActiveCharacter(characterId: ripple.characterId, evolution: ripple.evolutionStage)
        }

        try? context.save()
    }
}

/// Syncs active character selection to the App Group used by Watch complications.
struct CharacterSelectionSync {
    static let shared = CharacterSelectionSync()

    private let suiteName = "group.stress.ai.com"

    private enum Keys {
        static let activeCharacterId = "activeCharacterId"
        static let activeCharacterEvolution = "activeCharacterEvolution"
    }

    /// XCTest sets this on every test-host launch. WidgetCenter's reload call is an
    /// XPC round-trip to a system daemon that has nothing to reload in a unit-test
    /// host (no widget extension is actually installed there) and can back up badly
    /// when called repeatedly across a test run, so it's skipped under XCTest.
    private var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func saveActiveCharacter(characterId: String, evolution: EvolutionStage) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(characterId, forKey: Keys.activeCharacterId)
        defaults.set(evolution.rawValue, forKey: Keys.activeCharacterEvolution)
        defaults.synchronize()

        guard !isRunningUnitTests else { return }

        WidgetCenter.shared.reloadTimelines(ofKind: "CircularComplication")
        WidgetCenter.shared.reloadTimelines(ofKind: "RectangularComplication")
        WidgetCenter.shared.reloadTimelines(ofKind: "InlineComplication")
    }
}
