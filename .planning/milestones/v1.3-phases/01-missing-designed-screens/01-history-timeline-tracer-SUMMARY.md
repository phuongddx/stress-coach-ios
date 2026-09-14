# Summary — Plan 01: History Timeline Tracer (Wave 1)

## Objective
History Timeline screen (`design/screens/11-history.html`) + production Home entry point + per-entry push to existing `MeasurementDetailView` via `Route.measurement(id:)` — fixes the previously-dead route (DEC-1).

## What Changed
| Commit | Change | Files |
|---|---|---|
| 031c5ba | Add `.history` route case + destination | `Navigation/Route.swift`, `Navigation/View+NavigationDestinations.swift` |
| 764e049 | `HistoryTimelineViewModel` (`@MainActor @Observable`) | `ViewModels/HistoryTimelineViewModel.swift` |
| fc595df | History screen + entry card | `Views/History/HistoryTimelineView.swift`, `Views/History/HistoryTimelineEntryCard.swift` |
| 8024a96 | Wire Home entry (chart tap → history) | `Views/Components/StressOverTimeChart.swift`, `Views/DashboardView.swift` |
| 7eb228e | VM unit tests (Swift Testing) | `StressMonitorTests/HistoryTimelineViewModelTests.swift` |
| 0f72225 | Fix preview model container | `HistoryTimelineView.swift` |
| c6e4362 | Qualify `Route.history` append (NavigationPath type inference) | `Views/DashboardView.swift` |

All commits authored `Phuong Doan`; no AI attribution.

## Verification
- Build: **BUILD SUCCEEDED** (CI-parity generic iOS Simulator, signing off) — after environment repair (iOS 26.5 + watchOS 26.5 simulator platforms installed; iPhone 16 (iOS 26.5) device created).
- Tests: **306 tests / 52 suites passed** after target-registration fix (see below). Initial 294/50 run predated registration — the test target uses explicit pbxproj refs (not a synchronized group), so new test files need explicit registration (fixed in `d28a46b`).
- SwiftLint: new files clean; changed files only pre-existing warnings.
- Known toolchain quirk: `-only-testing:Target/SuiteName` matches 0 Swift Testing tests on this Xcode (display-name suites) — run the full target instead; CI is unfiltered.

## Deviations
- Executor initially blocked: no simulator platforms installed (exit 70). Orchestrator installed iOS 26.5 + watchOS 26.5 platforms (~12.5 GB), created iPhone 16 device, fixed one-line `Route.history` qualification (c6e4362), reran gates.
- History context lines/tags (prototype-only, no persisted source) omitted per plan YAGNI resolution; factual HRV/RHR subtitle used.

## Deferred
- Wave-1 `HistoryTimelineViewModelTests` initially not compiled (test-target registration gap, discovered in Wave 2); fixed in `d28a46b` — final full-suite run 306/52 green.
