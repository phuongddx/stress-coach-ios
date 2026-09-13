# Plan Checker Feedback — Phase 1: Missing Designed Screens (v1.3)

Verdict: **PASS** (0 blockers, 1 warning, 2 advisories). Plans are executable after the warning is acknowledged; no revision strictly required.

## Goal-backward coverage — VERIFIED

| Outcome | Plan(s) | Status |
|---|---|---|
| Screen 11 History Timeline built | 01 | Covered (View + VM + entry card + tests) |
| Screen 07 Measurement Result built | 02 | Covered (View + VM + factor rows + tests) |
| Screen 18 Biological Age built | 03 | Covered (View + VM + daily chart + tests) |
| DEC-1: `Route.measurement(id:)` reachable | 01 | Covered — timeline entry → `route(for:)` → `.measurement(id:)`; unit-tested (`testRoute_ReturnsMeasurementPersistentIdentifierRoute`) |
| DEC-2: Settings Bio Age row → Bio Age screen | 03 | Covered — `destination: .about` → `.bioAge` (verified current wrong value at SettingsView.swift:253) |
| DEC-3 architecture (MVVM/DI/Route) | all | Matches actual `Route.swift`, `View+NavigationDestinations.swift`, `@MainActor @Observable` VM convention, `StressRepository(modelContext:)` DI |
| DEC-4 design system / a11y | all | `Color.stressColor`, dual coding, 44pt, `.accessibleDynamicType()`, HapticManager all referenced with exemplar paths |
| DEC-5 unit tests | 01/02/03 | 6 + 6 + 5 focused tests, Swift Testing conventions, in-memory SwiftData fixture with kept-alive container |

## Correctness spot-checks (against live code)

- `Route` is `Hashable, Codable` with exhaustive switch — plans add cases correctly; `boxBreathing`/`miniWalk` cases exist (Plan 02 action links resolve).
- `Route.measurement(id: PersistentIdentifier)` + private `MeasurementDetailDestination` resolver exist exactly as plans assume; plan 01 correctly does not touch it.
- `StressResult: Identifiable, Codable, Sendable` / `FactorBreakdown: Codable, Sendable` — Plan 02's additive `Hashable` is required and sufficient for the new route case.
- `StressCategory.allCases` + `displayName` exist; `StressMeasurement` has `timestamp/stressLevel/hrv/restingHeartRate/category`; `fetchMeasurements(from:to:)` signature matches.
- `NoDataCard(dataType: .timeline)` case exists; `stressDualCoding` modifier exists; `InsightGenerator.generate(from:history:)` exists (Services/InsightGeneratorService.swift).
- `BioAgeCalculator.calculate(chronologicalAge:hrv:restingHeartRate:sleepEfficiency:previousResult:)`, `hasEnoughData(measurements:)`, `minimumDataDays` all match Plan 03 usage; watch copy untouched.
- `HealthKitServiceProtocol.dateOfBirthComponents` default `nil` confirmed (protocol line 28).
- `viewModel.currentStress` exists on StressViewModel (Plan 02 hero wrap is valid); AppRouter injected app-wide via `.environment(appRouter)` (StressMonitorApp.swift:222).
- pbxproj guidance correct: `PBXFileSystemSynchronizedRootGroup` means no pbxproj edits; all new files under real target roots — zero orphaned-dir paths in any plan.
- Verification commands match AGENTS.md CI-parity flags including `-parallel-testing-enabled NO` and single-destination cap.

## Scope discipline — VERIFIED

- No SwiftData schema/migration changes anywhere (all three plans state it; confirmed by task lists).
- No watch/widget edits; `BioAgeCalculator` unmodified.
- No legacy VM refactors; Dashboard changes are additive single-closure wiring.
- YAGNI table resolutions are honest (omit fabricated prototype content; label with real data names; no premium gate without a decision).

## Findings

### W1 — [dependency/wave] Same-wave file overlap: Plans 02 + 03 both edit `Navigation/Route.swift` and `Navigation/View+NavigationDestinations.swift`
- Severity: **warning**
- Evidence: Both Wave-2 plans add cases to the same two files (02: `.measurementResult`; 03: `.bioAge`). Each edit is additive, but true parallel execution would race on the same files / merge-conflict the single exhaustive switch.
- Required property: Same-wave plans either declare their shared-file ordering or are safe to serialize.
- Example fix: Declare `depends_on: ["02"]` on Plan 03 (it touches only 2 shared lines), or note that the executor must serialize 02 → 03 despite both being "Wave 2".

### I1 — [task completeness] Plan 01 Task 4 omits the `StressOverTimeChart` init update
- Severity: **info**
- Evidence: `StressOverTimeChart` has an explicit `init(data:onUpgrade:)` (file lines 21–23); adding `onOpenHistory` also requires extending that init (and DashboardView:197 currently passes `onUpgrade` as a trailing closure).
- Example fix: Add one line to Task 4: "extend `init(data:onUpgrade:onOpenHistory:)`; DashboardView call site switches to labeled `onUpgrade:` closure."

### I2 — [verification] Simulator-runtime caveat is carried, not resolved
- Severity: **info**
- Evidence: All three plans correctly gate local tests on an available iPhone 16 runtime; research notes it is currently unavailable, so VM suites defer to CI with build+lint as local blockers. Acceptable, but phase "tests green" then depends on a CI run outside executor control — track the follow-up explicitly.

## Recommendation

Accept plans. Before execution, apply W1 (one-line wave/depends_on adjustment) and optionally I1. Run `/gsd-execute-phase 1`.
