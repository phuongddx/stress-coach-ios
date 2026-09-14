# Plan 01 — History Timeline + Measurement-Detail Wiring (Tracer)

Wave 1 (run alone). Smallest end-to-end slice: builds the History Timeline screen, gives it a production entry point on Home, and makes `Route.measurement(id:)` reachable (DEC-1). Proves the Route → View → ViewModel → SwiftData pattern the two expansion plans reuse.

## Objective

Implement `design/screens/11-history.html` as `HistoryTimelineView`: filter chips, 7-day summary tiles, reverse-chronological day-grouped timeline, load-earlier pagination, and per-entry push to the existing `MeasurementDetailView` via `Route.measurement(id:)`. Unit-test the new ViewModel. No schema changes, no watch changes.

## Resolved decisions (conservative / YAGNI)

| Question | Resolution | Justification |
|---|---|---|
| Entry context/tags in entry cards | Replace with one factual subtitle `HRV {x} ms · RHR {y} bpm`; omit tags entirely | No persisted source; show only real `StressMeasurement` fields (YAGNI — no schema expansion). |
| Severe filter chip | Include — derive chips from `StressCategory.allCases` + `All` | Simpler code than a hardcoded 4-item subset; severe readings must not be unfilterable. |
| Repository errors vs empty | Treat thrown errors as typed VM error; empty fetch renders empty state | Concrete `StressRepository` currently returns `[]` on SwiftData errors — do not invent new error plumbing; surface what the protocol throws. |
| History entry point before Result exists | "All history" chevron in Home's `StressOverTimeChart` header | Design's only History entry is via screen 07 (built in Plan 02); a screen with no entry would itself be dead code. This entry stays useful after 02 lands. |

## One-way-door decisions

None. All edits additive or single-line; no SwiftData schema, migration, or watch changes.

## Xcode project registration (verified)

`StressMonitor.xcodeproj` uses `PBXFileSystemSynchronizedRootGroup` for both `StressMonitor/StressMonitor/` and `StressMonitor/StressMonitorTests/` (pbxproj lines ~200–232, ~401–450). **Do NOT add PBXBuildFile/PBXFileReference entries** — any new `.swift` file created under those two folders is auto-compiled into the correct target. If a new file fails to compile as "unknown symbol", first confirm it lives under the real target folder, not the orphaned repo-root `StressMonitor/{Views,Services,Models}` or `StressMonitorTests/` directories.

## Tasks

### 1. Add `Route.history` + destination

- `StressMonitor/StressMonitor/Navigation/Route.swift` — in the `// History` MARK group, add valueless case:
  ```swift
  /// History Timeline screen (`HistoryTimelineView`).
  case history
  ```
- `StressMonitor/StressMonitor/Navigation/View+NavigationDestinations.swift` — add to the exhaustive switch (next to `.measurement`):
  ```swift
  case .history:
      HistoryTimelineView()
  ```
- Keep `Route` exhaustive switch compiling — no other cases change. Do NOT touch `MeasurementDetailDestination`; it is reused unchanged (DEC-1).

### 2. Create `HistoryTimelineViewModel`

New file `StressMonitor/StressMonitor/Views/History/HistoryTimelineViewModel.swift` (4-space indent):

```swift
@MainActor
@Observable
final class HistoryTimelineViewModel { ... }
```

Pattern exemplars: `StressMonitor/StressMonitor/Views/Trends/TrendsViewModel.swift` (repository-backed loading, `isLoading` + `defer`, display-ready state) — but use the locked `@MainActor` isolation from `StressMonitor/StressMonitor/ViewModels/StressViewModel.swift:8-10`; do NOT copy Trends' missing-MainActor gap.

API shape:

- `enum HistoryFilter: String, CaseIterable, Sendable` — `all` + one case per `StressCategory`; `title` = `All` or `category.displayName`.
- `struct HistoryDayGroup: Identifiable, Sendable` — `let date: Date; let entries: [StressMeasurement]`; `id` = `date`.
- `struct HistorySummary: Sendable` — `sevenDayAverage: Int?`, `best: Int?` (lowest score), `peak: Int?` (highest score).
- State: `private(set) var isLoading`, `selectedFilter: HistoryFilter = .all`, `private(set) var dayGroups: [HistoryDayGroup] = []`, `private(set) var summary: HistorySummary?`, `private(set) var canLoadMore = true`, `errorMessage: String?`.
- `private var allMeasurements: [StressMeasurement] = []` (newest-first), `private var oldestLoadedDate: Date`.
- `init(repository: StressRepositoryProtocol)` (constructor DI; no container/protocol invention).
- `func loadInitial() async` — set `isLoading`, `defer { isLoading = false }`; fetch `fetchMeasurements(from: now-7d, to: now)`; sort newest-first; set `oldestLoadedDate = results.min(by: timestamp)?.timestamp ?? windowStart`; recompute groups/summary; `canLoadMore = !results.isEmpty`.
- `func loadEarlier() async` — fetch `[oldestLoadedDate-7d, oldestLoadedDate)`; merge, dedupe by `persistentModelID`, drop older-window duplicates at the boundary; set `canLoadMore = false` when a window yields zero new records; recompute groups (summary unchanged — it stays 7-day scoped).
- `func selectFilter(_ filter: HistoryFilter)` — pure recompute of `dayGroups` from cached `allMeasurements` (no refetch); `All` shows every cached record.
- `func route(for measurement: StressMeasurement) -> Route` — returns `.measurement(id: measurement.persistentModelID)`. This is the DEC-1 seam and the unit-test target.
- Grouping: `Calendar.current.startOfDay(for:)`, newest day first, entries newest-first within day. Filtering happens before grouping. Summary computed from unfiltered measurements in the last 7 calendar days (rounded `Int` average; best = min; peak = max).

### 3. Create `HistoryTimelineView` + entry card

New files:
- `StressMonitor/StressMonitor/Views/History/HistoryTimelineView.swift`
- `StressMonitor/StressMonitor/Views/History/Components/HistoryTimelineEntryCard.swift`

View exemplar: `StressMonitor/StressMonitor/Views/Trends/TrendsView.swift` (chip row, NoDataCard fallback, `.accessibleDynamicType()`, inline nav title, explicit sections). VM ownership exemplar: `StressMonitor/StressMonitor/Views/History/MeasurementDetailView.swift:9-17,64-67` creates its VM in `.task` — copy that instead of Trends' `container!` placeholder-context pattern (lint bans `!`).

- `@Environment(\.modelContext)` + `@State private var viewModel: HistoryTimelineViewModel?`; build it in `.task` with `StressRepository(modelContext: modelContext)` then `await vm.loadInitial()`; render skeleton (`SkeletonBlock`) while nil.
- Nav: `.navigationTitle("Stress History")`, `.navigationBarTitleDisplayMode(.inline)`. Omit the prototype's toolbar "Filter" text button — chips already cover it (YAGNI).
- Filter chip row: `TrendsView.chipView` pattern; each chip a `Button` with `.minimumTouchTarget(DesignTokens.Layout.minTouchTarget)`, `HapticManager.shared.buttonPress()`, calling `viewModel.selectFilter`.
- Summary tiles: 3 compact cards — `avg · 7d`, `best`, `peak`; value color via `Color.stressColor(for: StressResult.category(for: Double(value)))`; `nil` field renders `—`.
- Day group header: formatted date (`Today`/`Yesterday`/`E d MMM`), `{n} readings`.
- Entry rows: `NavigationLink(value: viewModel.route(for: measurement)) { HistoryTimelineEntryCard(measurement:) }`.
  - Card: 4pt leading color bar (`Color.stressColor(for: measurement.category)`), score `Int(measurement.stressLevel.rounded())`, `measurement.category.displayName`, trailing time (`DateFormatter` short time), subtitle `HRV {Int(hrv)} ms · RHR {Int(restingHeartRate)} bpm` (omit subtitle fields showing 0 → `—`). No tags row.
  - Dual coding: `.stressDualCoding(...)` style combined accessibility label ("Mild, 42, 9:32 AM") — see `StressMonitor/StressMonitor/Utilities/AccessibilityModifiers.swift:6-44`; never color-only.
- Empty state (selected filter or all empty, not loading): `NoDataCard(dataType: .timeline)` with retry `Task { await viewModel?.loadInitial() }` (case + copy already exist — `NoDataCard.swift:9-52`).
- Footer: `Load earlier` `Button` visible only when `canLoadMore` and not loading; disabled while loading.

### 4. Wire Home entry

- `StressMonitor/StressMonitor/Views/Dashboard/Components/StressOverTimeChart.swift` — add `var onOpenHistory: (() -> Void)? = nil` (keep `onUpgrade`); in `header`, when non-nil render a trailing chevron `Button` (`Image(systemName: "chevron.right")` + `"All history"` accessibility label, `.minimumTouchTarget(44)`, `HapticManager.shared.buttonPress()`), placed after the `LAST 7 DAYS` caption. Keep default-nil so the `#Preview` at line ~253 is unaffected.
- `StressMonitor/StressMonitor/Views/DashboardView.swift` — add `@Environment(AppRouter.self) private var router`; pass `onOpenHistory: { router.homePath.append(.history) }` at the `StressOverTimeChart` call site (line ~197). No other Dashboard changes.

### 5. Unit tests

New file `StressMonitor/StressMonitorTests/HistoryTimelineViewModelTests.swift`.

Conventions (exemplars): `AccountViewModelTests.swift:5-24` (`@MainActor struct` suite, `#expect`), `DataDeletionConsolidationTests.swift:243-259` (in-memory `ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)` fixture returning `(ModelContainer, ModelContext)` — **keep container alive in a stored property for the whole test**). Define a `private final class FakeStressRepository: StressRepositoryProtocol` inside the test file (records requested date windows + returns fixture arrays); never import app-target `MockStressRepository` (`.planning/codebase/TESTING.md:113-117`).

Fixture: insert `StressMeasurement`s with explicit `timestamp`/`stressLevel`/`hrv`/`restingHeartRate` into the in-memory context so `persistentModelID` is stable. Required tests (`test[Method]_[Condition]`):

- `testLoadInitial_GroupsByLocalDayNewestFirst`
- `testSelectFilter_SevereKeepsSevereRecordsOnly`
- `testSummary_ComputesRoundedAverageBestAndPeak` (float/rounding with explicit tolerance)
- `testLoadEarlier_AppendsOlderRecordsWithoutDuplicates`
- `testLoadEarlier_StopsWhenWindowIsEmpty` (`canLoadMore == false`)
- `testRoute_ReturnsMeasurementPersistentIdentifierRoute`

### 6. Verification

```bash
# Build gate (must pass)
xcodebuild build -project StressMonitor/StressMonitor.xcodeproj \
  -scheme StressMonitor -destination 'generic/platform=iOS Simulator' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# Focused tests (CI parity; run when a simulator runtime is available)
xcodebuild test \
  -project StressMonitor/StressMonitor.xcodeproj \
  -scheme StressMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -derivedDataPath build \
  -resultBundlePath TestResults.xcresult \
  -skipPackagePluginValidation \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:StressMonitorTests/HistoryTimelineViewModelTests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

swiftlint lint   # advisory — must not regress on new/changed files
```

Local simulator runtime is currently unavailable (research 2026-09-12). If the test destination fails for that reason, record it as an unresolved follow-up and let CI run the suite; the build + lint are the local blockers. No visual/simulator checks in this plan.

## Success criteria

- Build green; focused suite green (locally or in CI).
- Tapping Home "Stress over time" → All history pushes `HistoryTimelineView`.
- Chips filter without losing records; summary tiles match fixtures; Load earlier appends without duplicates; empty/filtered-empty shows `NoDataCard(.timeline)`.
- Timeline tap pushes the existing `MeasurementDetailView`; `Route.measurement(id:)` is no longer dead (DEC-1).
- New code: no `!`, no IUO, 4-space indent, dual-coded rows, ≥44pt targets, `.accessibleDynamicType()`.

## Rollback notes

Delete `HistoryTimelineView.swift`, `HistoryTimelineViewModel.swift`, `Components/HistoryTimelineEntryCard.swift`, `HistoryTimelineViewModelTests.swift`; revert the additive `Route.history` case + switch case; revert `StressOverTimeChart.onOpenHistory` + Dashboard call-site/env line. No persisted data, schema, or settings are touched.
