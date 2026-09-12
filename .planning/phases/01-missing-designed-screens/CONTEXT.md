# Context — Phase 1: Missing Designed Screens

## Objective

Implement the three designed-but-unbuilt iOS screens from `design/screens/` so the app matches the 27-surface design prototype:

1. **Measurement Result** — `design/screens/07-measurement.html`
2. **History Timeline** — `design/screens/11-history.html`
3. **Biological Age** — `design/screens/18-bio-age.html`

## Background

Screen census (2026-09-12, `/gsd-explore`, 4 parallel research agents): 28 iOS screens implemented vs 27 designed surfaces (25 primary + 2 Home states). 22/27 direct standalone matches; the 2 Home states exist as Dashboard branches; **07/11/18 are the only designed screens with no standalone implementation.**

Known wiring gaps discovered in the same census:

- `Route.measurement(id:)` → `MeasurementDetailView` exists and resolves but has **no production entry point** (declared + resolver only).
- Settings has a Biological Age row, but it routes to `.about` (wrong destination).
- `BioAgeCalculator` + `BioAgeResult` already exist (app target; duplicated simplified copy in watch target).
- `MeasurementDetailView` exists at `Views/History/MeasurementDetailView.swift`.

## Decisions

- **DEC-1:** History Timeline becomes the production entry point for `Route.measurement(id:)` — tapping a timeline entry pushes measurement detail. Fixes the dead route.
- **DEC-2:** Settings "Biological Age" row routes to the new Bio Age screen (not `.about`).
- **DEC-3:** Follow existing app architecture exactly: SwiftUI + MVVM (`@MainActor @Observable` VMs), central `Route` enum + `View+NavigationDestinations.swift` switch, protocol DI, SwiftData repository access.
- **DEC-4:** Match the design system: `docs/design-guidelines*.md`, dual-code stress levels (color + icon/text), `Color.stressColor(for:)`, 44pt touch targets, `.accessibleDynamicType()`, `HapticManager`.
- **DEC-5:** Ship unit tests for new ViewModel/navigation logic (Swift Testing dominant; naming `test[Method]_[Condition]`).

## Constraints

- Real target is `StressMonitor/StressMonitor/` — repo-root `StressMonitor/Views/` etc. are **orphaned** (never build).
- SwiftLint `force_unwrap`/`implicitly_unwrapped_optional` opt-in — no `!` in new code.
- 4-space indentation, `async throws` + `LocalizedError`, no Swift `Result`.
- No speculative abstractions (YAGNI/KISS).
- iOS deployment target 18.6.

## Out of Scope

- Watch redesign (`design/stressmonitor-watch-redesign-index.html`) — separate artifact.
- Widget changes.
- The 2 Home empty-state variants (already implemented as Dashboard branches).
- Visual redesign of existing screens.
