# Phase 01: Missing Designed Screens — Research

**Researched:** 2026-09-12  
**Domain:** SwiftUI screen implementation, MVVM, SwiftData history queries, value-based navigation, biological-age calculation  
**Confidence:** HIGH for code/design facts; MEDIUM for implementation choices because several designed fields have no persisted source and local simulator test execution is currently unavailable.

<user_constraints>
## User Constraints (from CONTEXT.md)

The phase context is reproduced verbatim below; DEC-1 through DEC-5 are locked.

<!-- DATA_mX3q7L2p_START -->
### Locked Decisions

- **DEC-1:** History Timeline becomes the production entry point for `Route.measurement(id:)` — tapping a timeline entry pushes measurement detail. Fixes the dead route.
- **DEC-2:** Settings "Biological Age" row routes to the new Bio Age screen (not `.about`).
- **DEC-3:** Follow existing app architecture exactly: SwiftUI + MVVM (`@MainActor @Observable` VMs), central `Route` enum + `View+NavigationDestinations.swift` switch, protocol DI, SwiftData repository access.
- **DEC-4:** Match the design system: `docs/design-guidelines*.md`, dual-code stress levels (color + icon/text), `Color.stressColor(for:)`, 44pt touch targets, `.accessibleDynamicType()`, `HapticManager`.
- **DEC-5:** Ship unit tests for new ViewModel/navigation logic (Swift Testing dominant; naming `test[Method]_[Condition]`).

### Codex's Discretion

Not present in CONTEXT.md.

### Constraints

- Real target is `StressMonitor/StressMonitor/` — repo-root `StressMonitor/Views/` etc. are **orphaned** (never build).
- SwiftLint `force_unwrap`/`implicitly_unwrapped_optional` opt-in — no `!` in new code.
- 4-space indentation, `async throws` + `LocalizedError`, no Swift `Result`.
- No speculative abstractions (YAGNI/KISS).
- iOS deployment target 18.6.

### Out of Scope (OUT OF SCOPE)

- Watch redesign (`design/stressmonitor-watch-redesign-index.html`) — separate artifact.
- Widget changes.
- The 2 Home empty-state variants (already implemented as Dashboard branches).
- Visual redesign of existing screens.
<!-- DATA_mX3q7L2p_END -->
</user_constraints>

## Summary

The three prototypes define two history/measurement surfaces and one bio-age analytics surface. Measurement/history can be built almost entirely from the existing `StressResult`, `StressMeasurement`, and `StressRepositoryProtocol` seams: current results already contain score/category/confidence/five component values, and the repository already supports recent, all, and date-range fetches. The existing `MeasurementDetailView` is a strong component/data-pattern exemplar, but it implements the separate `12-measurement-detail.html` retrospective detail rather than the immediate `07-measurement.html` result flow.

The main data gaps are deliberate prototype richness versus the persisted model: history entry context/tags are not stored; the immediate result flow does not retain the saved `StressMeasurement` or its `PersistentIdentifier`; Bio Age only exposes an aggregate result, not the designed per-factor year impacts; and raw sleep/activity inputs used by the Bio Age prototype are normalized or absent in `StressMeasurement`. These gaps should be handled with explicit unavailable states or a narrowly scoped calculator breakdown rather than schema speculation.

**Primary recommendation:** Add three route-driven screens using local ViewModels (`@MainActor @Observable`), repository-backed History grouping and Bio Age aggregation, actual `FactorBreakdown` values for Measurement Result, and explicit empty/unavailable states. Reuse `MeasurementDetailView` for the timeline's detail push; do not duplicate it as the immediate result screen.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Measurement Result rendering | iOS client View/ViewModel | SwiftData repository | `StressResult` supplies the live calculation; repository supplies previous-day delta and saved history navigation. |
| History Timeline grouping/filtering | iOS client ViewModel | SwiftData repository | Grouping and summaries are presentation logic; persistence belongs to `StressRepositoryProtocol`. |
| Measurement detail navigation | iOS client router | SwiftData resolver | `Route.measurement(id:)` stores a `PersistentIdentifier`; `MeasurementDetailDestination` resolves the live model. |
| Bio Age result and trend calculation | iOS algorithm service | ViewModel aggregation | `BioAgeCalculator` owns formulas; the VM owns date grouping, data sufficiency, and display mapping. |
| Settings route correction | iOS client router | Settings view | The existing `navRow` already appends a `Route` to `router.settingsPath`. |
| Automated validation | Active iOS unit-test target | Xcode build system | New tests must live under `StressMonitor/StressMonitorTests/`, not the orphaned root directory. |

## Standard Stack

### Core

| Library / Framework | Version / Mode | Purpose | Evidence |
|----------------------|----------------|---------|----------|
| SwiftUI | Swift 5 language mode, iOS deployment target `18.6` | All new screens/components | `[VERIFIED: StressMonitor/StressMonitor.xcodeproj/project.pbxproj:642-648]` contains `IPHONEOS_DEPLOYMENT_TARGET = 18.6;` and `SWIFT_VERSION = 5.0;` |
| Observation | `@Observable` | New ViewModel state | Existing production pattern is `@Observable` / `@MainActor` in `StressViewModel` `[VERIFIED: StressMonitor/StressMonitor/ViewModels/StressViewModel.swift:8-10]`. |
| SwiftData | App schema and persistence | History/result fetches and route resolution | Repository uses `FetchDescriptor<StressMeasurement>` `[VERIFIED: StressMonitor/StressMonitor/Services/Repository/StressRepository.swift:85-133]`. |
| Swift Testing | Xcode 26 toolchain | New unit tests | Active test documentation says Swift Testing is primary and XCTest is legacy only `[VERIFIED: .planning/codebase/TESTING.md:5-15]`. |

### Supporting

| Existing helper | Purpose | When to Use |
|-----------------|---------|-------------|
| `Color.stressColor(for:)` / `StressCategory` | Stress color, icon, label | Every stress-coded number, bar, or badge. |
| `.stressDualCoding(_:showsCaption:)` | Combined visible/accessibility dual coding | Where a category label is already visible, pass `showsCaption: false`. |
| `.minimumTouchTarget()` and `.accessibleDynamicType()` | Accessibility/layout gates | Every interactive row/chip/button and every new scroll screen. |
| `NoDataCard` | Existing empty state | History can reuse `.timeline`; Bio Age needs either a new case or a purpose-specific unavailable card. |
| `FactorBreakdownRow` | Five-factor row | Measurement Result/detail factor lists; it already renders nil as unavailable. |
| `accessibilityChart(description:summary:points:)` | Chart VoiceOver contract | Bio Age day chart and any new fixed-size chart. |

**Installation:** None. This phase adds no external package. The app's synchronized Xcode groups automatically include new files under `StressMonitor/StressMonitor/` and `StressMonitor/StressMonitorTests/` `[VERIFIED: StressMonitor/StressMonitor.xcodeproj/project.pbxproj:200-231,409-427]`.

## Package Legitimacy Audit

Not applicable — no npm/PyPI/crates or SPM package is installed or recommended by this phase.

## Architecture Patterns

### System Architecture Diagram

```text
Home measurement path
  HealthKit -> StressViewModel / MultiFactorStressCalculator
      -> StressResult (live score + FactorBreakdown)
      -> Measurement Result screen
      -> StressRepository.save -> StressMeasurement (SwiftData)
      -> History Timeline route

History Timeline path
  StressRepository.fetchRecent / fetchMeasurements(from:to:)
      -> HistoryTimelineViewModel grouping/filter/summaries
      -> timeline entry tap
      -> Route.measurement(id: StressMeasurement.persistentModelID)
      -> MeasurementDetailDestination fetch
      -> MeasurementDetailView

Biological Age path
  Settings row (and prototype Home bio chip)
      -> Route.bioAge
      -> BioAgeViewModel
           -> repository measurements / date grouping
           -> HealthKit DOB or explicit age source
           -> BioAgeCalculator
      -> Biological Age screen
```

### Recommended Project Structure

```text
StressMonitor/StressMonitor/
├── Navigation/
│   ├── Route.swift                       # add result/history/bio-age cases
│   └── View+NavigationDestinations.swift # add exhaustive switch cases
├── Views/
│   ├── History/
│   │   ├── MeasurementResultView.swift
│   │   ├── HistoryTimelineView.swift
│   │   ├── HistoryTimelineViewModel.swift
│   │   └── Components/                   # only screen-specific rows/charts
│   └── BiologicalAge/
│       ├── BiologicalAgeView.swift
│       ├── BiologicalAgeViewModel.swift
│       └── Components/
└── Models/                               # only if a narrow display model is needed

StressMonitor/StressMonitorTests/
├── MeasurementResultViewModelTests.swift
├── HistoryTimelineViewModelTests.swift
└── BiologicalAgeViewModelTests.swift
```

No `project.pbxproj` edit should be needed for ordinary Swift files because these directories are synchronized root groups.

## Design Specs

### 1. Measurement Result — `design/screens/07-measurement.html`

**Layout order**

1. Navigation bar: back, `Result`, `Share` `[VERIFIED: design/screens/07-measurement.html:141-147]`.
2. Circular 200px score ring with score `42`, state `Mild · Focused`, and `9:32 AM · 60s reading` `[VERIFIED: design/screens/07-measurement.html:149-163]`.
3. Confidence row: `96% confidence · 5-factor analysis` `[VERIFIED: design/screens/07-measurement.html:162-163]`.
4. Delta ribbon: `Down 16 pts from yesterday` `[VERIFIED: design/screens/07-measurement.html:165-168]`.
5. Five factor rows: HRV balance, Resting HR, Sleep debt, Activity load, Circadian phase; each has name/subtitle, progress bar, and signed contribution `[VERIFIED: design/screens/07-measurement.html:170-214]`.
6. Ripple takeaway: `Ripple noticed:` plus a recovery recommendation `[VERIFIED: design/screens/07-measurement.html:217-233]`.
7. Two action buttons: `Breathe 2min`, `Mini Walk`; then `Save & view history` `[VERIFIED: design/screens/07-measurement.html:235-240]`.

**Stress/color coding**

- The hero uses prototype `--stress-mild` / `#007AFF`; shared CSS defines the five values `#34C759`, `#007AFF`, `#FFD60A`, `#FF9500`, `#FF3B30` `[VERIFIED: design/css/app.css:28-33]`.
- Production must not hard-code those hex values. DEC-4 selects `Color.stressColor(for:)`, which delegates to `StressCategory.color` `[VERIFIED: StressMonitor/StressMonitor/Theme/Color+Extensions.swift:198-208]`.

**Navigation/actions**

- `Breathe` maps to existing `Route.boxBreathing`; `Mini Walk` maps to existing `Route.miniWalk` `[VERIFIED: StressMonitor/StressMonitor/Navigation/Route.swift:32-41]`.
- `Save & view history` should push the new History route. The prototype then treats History as the back destination for the separate detail screen `[VERIFIED: design/screens/12-measurement-detail.html:65-87]`.

**States**

- No explicit loading, empty, or error markup exists in the supplied 07 prototype (full body reviewed at `design/screens/07-measurement.html:119-249`).
- Recommended state contract: loading skeleton while repository/history delta loads; unavailable row for each nil factor; empty delta text when there is no prior measurement; existing alert pattern for calculation failure.

**Data needs**

- Directly available from `StressResult`: level, category, confidence, HRV, heart rate, timestamp, and optional five-factor breakdown `[VERIFIED: StressMonitor/StressMonitor/Models/StressResult.swift:3-12]`.
- Available after persistence: previous reading score, saved timestamp/category, and `PersistentIdentifier`.
- Not available verbatim: `60s reading`, `Sleep debt last night -42min`, `14h since move`, `morning cortisol`, and the designed Ripple sentence. These must be derived or explicitly omitted; do not fabricate them.

### 2. History Timeline — `design/screens/11-history.html`

**Layout order**

1. Navigation bar: back to Home, `Stress History`, `Filter` `[VERIFIED: design/screens/11-history.html:78-83]`.
2. Filter chips: `All · 24`, `Relaxed`, `Mild`, `Moderate`, `High` `[VERIFIED: design/screens/11-history.html:85-91]`. The prototype omits a Severe chip even though the app has a severe category.
3. Three summary tiles: average for 7 days, best, and peak `[VERIFIED: design/screens/11-history.html:93-97]`.
4. Day groups with date, reading count, and entry cards in reverse-chronological order `[VERIFIED: design/screens/11-history.html:99-188]`.
5. Entry card: colored vertical bar, score/state, context line, tags, and time `[VERIFIED: design/screens/11-history.html:31-54,99-109]`.
6. Footer: `Load earlier · 7 weeks of history` `[VERIFIED: design/screens/11-history.html:188-189]`.

**Stress/color coding**

- Entry card class controls the bar color: `.relaxed`, `.mild`, `.moderate`, `.high`; CSS values map to the same five-level stress palette `[VERIFIED: design/screens/11-history.html:43-48]`.
- Score plus state text supplies the non-color channel. Add `stressDualCoding` or an equivalent hidden symbol/combined label so the row is not color-only.

**Navigation/actions**

- Every entry links to the separate measurement-detail prototype `[VERIFIED: design/screens/11-history.html:102-110,124-132,137-145]`.
- Production mapping is locked by DEC-1: tap pushes `Route.measurement(id: measurement.persistentModelID)`.
- Filter and Load Earlier should be ViewModel operations; avoid putting grouping/filter logic in the View.

**States**

- No explicit empty/loading markup exists in the supplied prototype (body reviewed at `design/screens/11-history.html:57-197`).
- Use `NoDataCard(dataType: .timeline)` or a purpose-specific equivalent when the selected filter has no results. Existing `.timeline` copy is `No Timeline Data` / `Timeline will populate as you take measurements.` `[VERIFIED: StressMonitor/StressMonitor/Views/Dashboard/Components/NoDataCard.swift:9-52]`.

**Data needs**

- Directly available: `stressLevel`, `category`, `timestamp`, HRV, RHR, factor components, confidence.
- Computable in VM: day grouping, counts, 7-day average, best/minimum, peak/maximum, category filter counts, load-more windows.
- Not persisted: free-text context (`After shower · 6h 18m sleep`) and tags (`post-shower`, `morning`). Do not invent a tagging subsystem; hide the row section when unavailable or show a generic available summary.

### 3. Biological Age — `design/screens/18-bio-age.html`

**Layout order**

1. Navigation bar: back to Settings, `Biological Age`, overflow action `[VERIFIED: design/screens/18-bio-age.html:139-144]`.
2. Purple gradient hero: `your bio age`, `26`, `yrs`, and `2 years younger · chronological 28` `[VERIFIED: design/screens/18-bio-age.html:146-157]`.
3. `What's driving it`: HRV, Resting heart rate, Sleep consistency, Stress load, Activity variability; each shows input detail and signed year impact `[VERIFIED: design/screens/18-bio-age.html:159-211]`.
4. `7-day range` / `Day-by-day estimate` bar chart with young/actual/older reference lines and start/mid/today legend `[VERIFIED: design/screens/18-bio-age.html:215-236]`.
5. Insight card and disclaimer: `Best in 3 weeks.` and `Biological age is an estimate... Not a medical diagnosis.` `[VERIFIED: design/screens/18-bio-age.html:239-248]`.

**State and actions**

- No explicit loading, insufficient-data, or error markup exists in the supplied prototype (body reviewed at `design/screens/18-bio-age.html:118-257`).
- Production must add an insufficient-data state. `BioAgeCalculator.minimumDataDays` is exactly `7` `[VERIFIED: StressMonitor/StressMonitor/Services/Algorithm/BioAgeCalculator.swift:47-60]`.
- The overflow `⋯` action is undefined in the prototype; omit it unless a concrete action is required. Do not add a speculative menu.

**Data needs**

- Directly available from `BioAgeResult`: estimated age, chronological age, signed difference, trend, and confidence `[VERIFIED: StressMonitor/StressMonitor/Models/BioAgeResult.swift:7-32]`.
- Existing presentation helpers provide `Getting younger`, `Aging faster`, `Holding steady`, `5 years younger`, and character copy `[VERIFIED: StressMonitor/StressMonitor/Models/BioAgeResult.swift:37-57,61-99]`.
- 7-day daily estimates can be computed by grouping measurements by day and calling the calculator on daily HRV/RHR aggregates.
- Not currently available: per-factor signed year impacts; sleep consistency percentage/duration; stress spike count; activity CV. The calculator computes aggregate deltas internally but returns only `BioAgeResult` `[VERIFIED: StressMonitor/StressMonitor/Services/Algorithm/BioAgeCalculator.swift:83-129]`.

## Data Map

| Screen need | Exact current source | Status / gap |
|-------------|----------------------|---------------|
| Result score/category/confidence/time | `StressResult.level/category/confidence/timestamp` | Available `[VERIFIED: StressMonitor/StressMonitor/Models/StressResult.swift:3-12]`. |
| Result HRV/RHR | `StressResult.hrv`, `StressResult.heartRate` | Available `[VERIFIED: StressMonitor/StressMonitor/Models/StressResult.swift:8-10]`. |
| Five normalized result factors | `FactorBreakdown` | Available for new calculations; nil means unavailable `[VERIFIED: StressMonitor/StressMonitor/Models/FactorBreakdown.swift:3-15]`. |
| Persisted result fields | `StressMeasurement` fields | Score/HRV/RHR/category/confidences and optional five components are stored `[VERIFIED: StressMonitor/StressMonitor/Models/StressMeasurement.swift:5-20]`. |
| Save-to-detail identity | `StressMeasurement.persistentModelID` | Resolvable, but `StressViewModel` creates the measurement locally and `StressRepository.save` returns `Void`; no last-saved ID is exposed `[VERIFIED: StressMonitor/StressMonitor/ViewModels/StressViewModel.swift:182-192,293-315]`. |
| Previous-day delta | Repository fetches | Compute from `fetchMeasurements(from:to:)`; no prebuilt delta method. |
| History initial page | `fetchRecent(limit:)` | Available, newest-first `[VERIFIED: StressMonitor/StressMonitor/Services/Repository/StressRepository.swift:85-96]`. |
| History range/load-more | `fetchMeasurements(from:to:)` | Available, newest-first `[VERIFIED: StressMonitor/StressMonitor/Services/Repository/StressRepository.swift:123-134]`; no cursor/offset API, so implement date-window loading. |
| History all records | `fetchAll()` | Available, newest-first `[VERIFIED: StressMonitor/StressMonitor/Services/Repository/StressRepository.swift:98-108]`. |
| History context/tags | No `StressMeasurement` field | Gap. Only normalized components exist; omit/unavailable rather than adding schema speculatively. |
| Bio hero/trend | `BioAgeResult` | Available `[VERIFIED: StressMonitor/StressMonitor/Models/BioAgeResult.swift:7-32]`. |
| Bio data sufficiency | `BioAgeCalculator.hasEnoughData(measurements:)` | Available; requires at least seven recent readings `[VERIFIED: StressMonitor/StressMonitor/Services/Algorithm/BioAgeCalculator.swift:148-156]`. |
| Bio chronological age | StressViewModel uses HealthKit DOB; SettingsViewModel uses `userProfile.age ?? 35` | Inconsistent sources. New VM should use the HealthKit/DOB path and an explicit fallback, not silently copy Settings' default `[VERIFIED: StressMonitor/StressMonitor/ViewModels/StressViewModel.swift:453-488; StressMonitor/StressMonitor/Views/Settings/SettingsViewModel.swift:75-85]`. |
| Bio per-factor year impacts | Internal local variables only | Gap. Refactor narrowly to expose contributions if the designed rows must be truthful; mirror the watch calculator copy if its algorithm API changes. |
| Bio daily chart | Persisted `timestamp/hrv/restingHeartRate` | Available as HRV/RHR-only daily estimates; sleep/activity-rich estimates are not reconstructible. |
| Bio sleep consistency/activity CV | Raw `SleepData`/`ActivityData` are transient HealthKit context | Not persisted in `StressMeasurement`; current Settings calculation passes `sleepEfficiency: nil` `[VERIFIED: StressMonitor/StressMonitor/Views/Settings/SettingsViewModel.swift:75-85]`. |

### Repository API — verbatim source anchor

<!-- DATA_rT5wN8cQ_START -->
```swift
protocol StressRepositoryProtocol: Sendable {
    func save(_ measurement: StressMeasurement) async throws
    func fetchRecent(limit: Int) async throws -> [StressMeasurement]
    func fetchAll() async throws -> [StressMeasurement]
    func deleteOlderThan(_ date: Date) async throws
    func getBaseline() async throws -> PersonalBaseline
    func updateBaseline(_ baseline: PersonalBaseline) async throws
    func fetchMeasurements(from: Date, to: Date) async throws -> [StressMeasurement]
    func delete(_ measurement: StressMeasurement) async throws
    func fetchAverageHRV(hours: Int) async throws -> Double
    func fetchAverageHRV(days: Int) async throws -> Double
    func deleteAllMeasurements() async throws
}
```
<!-- DATA_rT5wN8cQ_END -->

`[VERIFIED: StressMonitor/StressMonitor/Services/Protocols/StressRepositoryProtocol.swift:5-17]`

Implementation detail: recent/all/range fetch catches SwiftData errors and returns `[]` instead of throwing `[VERIFIED: StressMonitor/StressMonitor/Services/Repository/StressRepository.swift:85-134]`. A ViewModel therefore cannot reliably distinguish repository fetch failure from a genuinely empty history with the current concrete implementation.

## Routing Integration

### Existing route contract

`Route` is the sole push-value enum and is declared `Hashable, Codable`. The current history case is:

<!-- DATA_vJ62bK9F_START -->
```swift
enum Route: Hashable, Codable {
    // ...
    // History
    case measurement(id: PersistentIdentifier)
    // ...
}
```
<!-- DATA_vJ62bK9F_END -->

`[VERIFIED: StressMonitor/StressMonitor/Navigation/Route.swift:4-30]`

The destination resolver is one exhaustive switch:

<!-- DATA_Lp84mQz7_START -->
```swift
self.navigationDestination(for: Route.self) { route in
    switch route {
    // ...
    case .measurement(let id):
        MeasurementDetailDestination(id: id)
    // ...
    }
}
```
<!-- DATA_Lp84mQz7_END -->

`[VERIFIED: StressMonitor/StressMonitor/Navigation/View+NavigationDestinations.swift:4-54]`

### Measurement ID resolution

`MeasurementDetailDestination` fetches by `persistentModelID`, renders the live detail, and shows `ContentUnavailableView` when the record is gone:

<!-- DATA_qW36ZcH2_START -->
```swift
private var resolved: StressMeasurement? {
    let descriptor = FetchDescriptor<StressMeasurement>(
        predicate: #Predicate<StressMeasurement> { $0.persistentModelID == id }
    )
    return try? modelContext.fetch(descriptor).first
}
```
<!-- DATA_qW36ZcH2_END -->

`[VERIFIED: StressMonitor/StressMonitor/Navigation/View+NavigationDestinations.swift:58-85]`

This resolver is correct for DEC-1 and should be reused unchanged.

### Where to add routes

1. Add valueless cases such as `case measurementResult`, `case history`, and `case bioAge` to `Route` in appropriate MARK groups.
2. Add them to the exhaustive switch in `View+NavigationDestinations.swift`.
3. Update the Settings Biological Age row destination from `.about` to `.bioAge`.
4. Push History entries with `Route.measurement(id: measurement.persistentModelID)`.
5. Do not put `navigationDestination` modifiers in leaf views; `MainTabView` already attaches `.stressNavigationDestinations()` once to each tab's root `[VERIFIED: StressMonitor/StressMonitor/Views/MainTabView.swift:30-74]`.

### Settings row integration

Current wrong destination:

<!-- DATA_yB4nRw7K_START -->
```swift
navRow(
    icon: AppIconSystem.Setting.biologicalAge.sfSymbol,
    setting: .biologicalAge,
    tint: .primaryGreen,
    title: "Biological Age",
    value: bioAgeText,
    destination: .about
)
```
<!-- DATA_yB4nRw7K_END -->

`[VERIFIED: StressMonitor/StressMonitor/Views/Settings/SettingsView.swift:247-254]`

`navRow` already performs the desired interaction behavior: haptic then `router.settingsPath.append(destination)` `[VERIFIED: StressMonitor/StressMonitor/Views/Settings/SettingsView.swift:565-604]`. Only the destination value should change.

### Additional navigation observations

- The Home prototype makes its Bio chip a link to `18-bio-age.html` `[VERIFIED: design/screens/04-home.html:626-637]`.
- The production `HomeHeaderBar` chip is informational and has no Button/action `[VERIFIED: StressMonitor/StressMonitor/Views/Dashboard/Components/HomeHeaderBar.swift:20-29,56-75]`.
- Context only locks the Settings route. Whether to make the Home Bio chip tappable is an open scope question.
- Path restoration is defensive: `AppRouter.decodePath` returns an empty `NavigationPath` on decode failure `[VERIFIED: StressMonitor/StressMonitor/Navigation/AppRouter.swift:54-78]`. New route associated values should remain small and `Codable`; valueless cases avoid this concern.

## Exemplar Patterns

### Trends screen/ViewModel pattern

**View construction**

- `TrendsView` owns `@State private var viewModel`, initializes with a static placeholder in-memory context, then swaps in the environment `modelContext` in `.task` before loading `[VERIFIED: StressMonitor/StressMonitor/Views/Trends/TrendsView.swift:14-30,58-61]`.
- Empty state condition is `weeklyMeasurements.isEmpty && !isLoading`; it invokes `NoDataCard(dataType: .trends)` and retries through the VM `[VERIFIED: StressMonitor/StressMonitor/Views/Trends/TrendsView.swift:32-48]`.
- Chips mutate `selectedTimeRange` and launch `loadTrendData`; each chip uses `.minimumTouchTarget(DesignTokens.Layout.minTouchTarget)` `[VERIFIED: StressMonitor/StressMonitor/Views/Trends/TrendsView.swift:64-101]`.
- Root view applies `.accessibleDynamicType()`, sets navigation title/display mode, and composes six explicit sections rather than a generic renderer `[VERIFIED: StressMonitor/StressMonitor/Views/Trends/TrendsView.swift:32-61,103-223]`.

**ViewModel loading**

- `TrendsViewModel` stores `StressRepositoryProtocol`, builds `StressRepository` from a `ModelContext`, exposes `isLoading`, and mutates only display-ready state `[VERIFIED: StressMonitor/StressMonitor/Views/Trends/TrendsViewModel.swift:38-59,229-268]`.
- Loading uses `isLoading = true`, `defer { isLoading = false }`, computes a start date by selected range, fetches with `fetchMeasurements(from: startDate, to: now)`, then derives all aggregates `[VERIFIED: StressMonitor/StressMonitor/Views/Trends/TrendsViewModel.swift:266-313]`.
- Existing error handling sets `hrvData = []`; do not copy this silent-error behavior if a new VM can surface a typed error state.
- Existing `TrendsViewModel` is only `@Observable`, not `@MainActor`. New VMs must follow the locked app/`StressViewModel` pattern instead: `@Observable` and `@MainActor` `[VERIFIED: StressMonitor/StressMonitor/ViewModels/StressViewModel.swift:8-10]`.

### Measurement detail pattern

- `MeasurementDetailView` receives a live `StressMeasurement`, creates `DetailViewModel` in `.task` with the environment context, and calls `loadData()` `[VERIFIED: StressMonitor/StressMonitor/Views/History/MeasurementDetailView.swift:9-17,64-67]`.
- Screen order is score hero → stress-scale bar → factor breakdown → context → recommendations → action bar `[VERIFIED: StressMonitor/StressMonitor/Views/History/MeasurementDetailView.swift:19-68]`.
- Factor rows use actual optional persisted components and explicitly show an unavailable note when `dataCompleteness < 1.0` `[VERIFIED: StressMonitor/StressMonitor/Views/History/MeasurementDetailView.swift:143-175]`.
- Context rows display HR, HRV, sleep quality, and average confidence with graceful `—` placeholders `[VERIFIED: StressMonitor/StressMonitor/Views/History/MeasurementDetailView.swift:183-225,315-325]`.
- Actions use `HapticManager.shared.buttonPress()` and card-style buttons `[VERIFIED: StressMonitor/StressMonitor/Views/History/MeasurementDetailView.swift:243-272]`. New buttons should additionally call `.minimumTouchTarget()` explicitly.
- `DetailViewModel.loadData` uses `async let` for baseline and HRV averages `[VERIFIED: StressMonitor/StressMonitor/Views/History/DetailViewModel.swift:15-38]`.
- **Do not reuse its `ContributingFactor` generation as truthful result data:** it hard-codes `0.45`, `0.60`, `0.30`, and sample labels `[VERIFIED: StressMonitor/StressMonitor/Views/History/DetailViewModel.swift:80-106]`. Use persisted `FactorBreakdown` for the new result screen.

### Stress coding and accessibility helpers

The production category values are:

<!-- DATA_nF7xWq3B_START -->
```swift
public enum StressCategory: String, CaseIterable, Codable, Sendable {
    case relaxed
    case mild
    case moderate
    case high
    case severe
}
```
<!-- DATA_nF7xWq3B_END -->

`[VERIFIED: StressMonitor/StressMonitor/Models/StressCategory.swift:3-8]`

Thresholds are exactly:

<!-- DATA_kM9vT4rD_START -->
```swift
case 0..<25: return .relaxed
case 25..<50: return .mild
case 50..<75: return .moderate
case 75..<90: return .high
default: return .severe
```
<!-- DATA_kM9vT4rD_END -->

`[VERIFIED: StressMonitor/StressMonitor/Models/StressResult.swift:33-40]`

Each category supplies adaptive color, SF Symbol, pattern, accessibility description, and display name `[VERIFIED: StressMonitor/StressMonitor/Models/StressCategory.swift:10-38,73-88]`. `.stressDualCoding` combines content, symbol, optional caption, and one accessibility label `[VERIFIED: StressMonitor/StressMonitor/Utilities/AccessibilityModifiers.swift:6-44]`.

### Reusable chart components

| Component | Input contract | Fit |
|-----------|----------------|-----|
| `StressBarChartView` | `[DailyStressData]`, `averageValue: Int` | Good reference for daily stress bars and chart accessibility; assumes 0–100 stress semantics. |
| `HRVTrendChart` | `[ChartDataPoint]`, `referenceValue: Double`, `deltaText: String?` | Not a direct Bio Age chart (different domain/range), but the best accessibility/custom Path chart pattern. |
| `DistributionBar` | relaxed/mild/moderate/high day counts + comment | Could inspire filter distribution, but History prototype does not specify a distribution bar. |
| `MonthlyCalendarHeatmap` | `[Date: Double]` daily averages | Calendar heatmap only; do not force it into the linear History timeline. |

Both fixed-size chart exemplars call `.accessibilityChart(description:summary:points:)` and build summaries through `VoiceOverLabels.trendSummary` `[VERIFIED: StressMonitor/StressMonitor/Views/Trends/Components/StressBarChartView.swift:31-57; StressMonitor/StressMonitor/Views/Trends/Components/HRVTrendChart.swift:18-68]`.

## Don't Hand-Roll

| Problem | Don't build | Use instead | Why |
|---------|-------------|-------------|-----|
| Stress category/color/icon | bespoke threshold and hex maps | `StressResult.category(for:)`, `StressCategory`, `Color.stressColor(for:)` | Existing thresholds, adaptive colors, and accessibility metadata are already project conventions. |
| Five-factor unavailable state | hidden rows or fake labels | `FactorBreakdown` optionals + `FactorBreakdownRow` | The component already renders nil as `—` and a greyed bar. |
| History persistence/pagination | direct `@Query` or custom SQL | `StressRepositoryProtocol` date-window fetches | The central repository owns SwiftData and CloudKit behavior. |
| Navigation destination registry | leaf-view `navigationDestination` switches | `Route` + `.stressNavigationDestinations()` | One registry is already attached to every tab and restoration-friendly. |
| Bio age formulas | duplicate norm tables/formulas in a ViewModel | `BioAgeCalculator` | Formula and confidence weighting are algorithm concerns and have existing tests. |
| Empty state | ad-hoc copy per row | `NoDataCard` where an appropriate case exists, otherwise one screen-specific unavailable card | Keeps icon/title/action/accessibility contract consistent. |

## Common Pitfalls

1. **Editing orphaned files.** Only `StressMonitor/StressMonitor/` and `StressMonitor/StressMonitorTests/` are target members; repo-root equivalents never build.
2. **Duplicating Measurement Detail as Result.** `07-measurement.html` is an immediate result flow; `12-measurement-detail.html` is retrospective detail. Share row components, not the full screen contract.
3. **Inventing History metadata.** Context/tags are not stored. A speculative schema change is outside the phase's simplicity constraint.
4. **Faking Bio Age driver rows.** Current `BioAgeResult` has no per-factor impacts. Either expose a real breakdown from the calculator or render an explicit partial-data state.
5. **Copying Trends VM isolation.** Trends and Detail VMs lack `@MainActor`; locked DEC-3 requires new VMs to be `@MainActor @Observable`.
6. **Forgetting watch mirroring.** If `BioAgeCalculator`'s algorithm API changes, semantically mirror it into `StressMonitor/StressMonitorWatch Watch App/Services/BioAgeCalculator.swift`; the app and watch copies currently contain the same delta formulas `[VERIFIED: StressMonitor/StressMonitor/Services/Algorithm/BioAgeCalculator.swift:83-129; StressMonitor/StressMonitorWatch Watch App/Services/BioAgeCalculator.swift:83-129]`.
7. **Assuming local tests can run.** Xcode is installed, but no iOS simulator runtime is currently available.

## Test Strategy

### Framework and conventions

- Use Swift Testing for all new suites.
- Honor CONTEXT's locked naming rule despite older Swift Testing examples using lowerCamelCase: name tests `test[Method]_[Condition]`.
- Mark suites `@MainActor` when exercising MainActor VMs or SwiftData contexts, following `AccountViewModelTests` and project testing guidance `[VERIFIED: StressMonitor/StressMonitorTests/AccountViewModelTests.swift:5-24; .planning/codebase/TESTING.md:72-80]`.
- Use `#expect`, `#require`, `Issue.record`, and explicit tolerance for rounded floating-point comparisons.

### Exemplar 1 — protocol fake / ViewModel arrange-act-assert

`AccountViewModelTests` injects `MockAuthService`, awaits the VM operation, then asserts VM state and call counts `[VERIFIED: StressMonitor/StressMonitorTests/AccountViewModelTests.swift:5-35]`. The shared fake itself is deliberately compiled into the test target, records calls, and does not ship in Release `[VERIFIED: StressMonitor/StressMonitorTests/StressAPIClientTests.swift:6-54]`.

For this phase, create a private `StressRepositoryProtocol` fake in each consuming test file (or one intentionally shared test-target provider) rather than using `MockStressRepository` from the app target. Project guidance explicitly says not to place mocks in `Services/MockServices.swift` merely for tests `[VERIFIED: .planning/codebase/TESTING.md:113-117]`.

### Exemplar 2 — SwiftData fixture and container lifetime

The safest fixture pattern returns both container and context:

<!-- DATA_zR8mQv5N_START -->
```swift
private func makeContextWithOneMeasurement() throws -> (ModelContainer, ModelContext) {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: StressMeasurement.self, configurations: config)
    let ctx = container.mainContext
    ctx.insert(StressMeasurement(timestamp: Date(), stressLevel: 50, hrv: 40, restingHeartRate: 65))
    try ctx.save()
    return (container, ctx)
}
```
<!-- DATA_zR8mQv5N_END -->

`[VERIFIED: StressMonitor/StressMonitorTests/DataDeletionConsolidationTests.swift:243-259]`

Keep the container alive for the entire test; the source comment documents the historical orphaned-context trap.

### Required test coverage

| Scope ID | Behavior | Test type | Suggested file / test |
|----------|----------|-----------|------------------------|
| MR-01 | Result maps score/category/confidence and all five optional factors; nil factors become unavailable rows | unit | `MeasurementResultViewModelTests.testLoad_[Condition]` |
| MR-02 | Previous-day delta handles prior reading, same-day-only, and missing history | unit | `MeasurementResultViewModelTests.testPreviousDelta_[Condition]` |
| HT-01 | Measurements group by local calendar day, newest day first, count per day | unit | `HistoryTimelineViewModelTests.testGroupMeasurements_[Condition]` |
| HT-02 | All/category filters and severe filtering do not lose records | unit | `HistoryTimelineViewModelTests.testApplyFilter_[Condition]` |
| HT-03 | Summary computes rounded 7-day average, best, and peak | unit | `HistoryTimelineViewModelTests.testSummary_[Condition]` |
| HT-04 | Load-earlier appends only older, non-duplicate records | unit with fake repository | `HistoryTimelineViewModelTests.testLoadEarlier_[Condition]` |
| BA-01 | Fewer than seven recent readings yields insufficient-data state, not a result | unit | `BiologicalAgeViewModelTests.testLoadData_[Condition]` |
| BA-02 | Chronological age/DOB fallback and 7-day HRV/RHR averages feed calculator | unit | `BiologicalAgeViewModelTests.testCalculateBioAge_[Condition]` |
| BA-03 | Daily estimates are ordered old-to-new and omit empty days or expose them explicitly | unit | `BiologicalAgeViewModelTests.testDailyEstimates_[Condition]` |
| NAV-01 | Settings destination compiles as Bio Age and History output route uses measurement IDs | unit/compile smoke | ViewModel route-output tests plus build gate |

### Chart/accessibility tests

- Pin any generated chart summary with `VoiceOverLabels.trendSummary` or a purpose-built pure formatter; `ChartAccessibilityTests` demonstrates pure copy contracts `[VERIFIED: StressMonitor/StressMonitorTests/ChartAccessibilityTests.swift:3-50]`.
- Float assertions must use tolerance; this is an existing project rule `[VERIFIED: .planning/codebase/TESTING.md:76-80]`.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing dominant; two legacy XCTest files remain |
| Config file | No `.xctestplan`; workflow `.github/workflows/_test.yml` is CI truth `[VERIFIED: .planning/codebase/TESTING.md:5-24]` |
| Quick run command | `xcodebuild test -project StressMonitor/StressMonitor.xcodeproj -scheme StressMonitor -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' -only-testing:StressMonitorTests/HistoryTimelineViewModelTests -parallel-testing-enabled NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO` |
| Full suite command | `xcodebuild test -project StressMonitor/StressMonitor.xcodeproj -scheme StressMonitor -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' -derivedDataPath build -resultBundlePath TestResults.xcresult -skipPackagePluginValidation -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO` |

### Sampling Rate

- **Per task commit:** Run the narrow `-only-testing` command(s) for the new suite, then `swiftlint lint` for changed files.
- **Per wave merge:** Run the full iOS suite with the CI-parity flags above.
- **Phase gate:** Full suite green, generic iOS build green, and accessibility checks for the three new screens before `/gsd-verify-work`.

### Wave 0 Gaps

- [ ] `StressMonitor/StressMonitorTests/MeasurementResultViewModelTests.swift`
- [ ] `StressMonitor/StressMonitorTests/HistoryTimelineViewModelTests.swift`
- [ ] `StressMonitor/StressMonitorTests/BiologicalAgeViewModelTests.swift`
- [ ] Local iOS simulator runtime installation/repair — currently no available runtime or device.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build/tests | ✓ | `Xcode 26.6`, `Build version 17F113` `[VERIFIED: local xcodebuild -version probe, 2026-09-12]` | — |
| SwiftLint | Lint gate | ✓ | `0.65.1` `[VERIFIED: local swiftlint version probe, 2026-09-12]` | Advisory only; do not regress |
| iOS Simulator runtime | Unit/UI validation | ✗ | `xcrun simctl list runtimes` returned an empty runtime list `[VERIFIED: local CoreSimulator probe, 2026-09-12]` | Generic build only; no local test substitute |
| iPhone 16 / iPhone 17 simulator | Configured test destinations | ✗ | Devices are listed as `unavailable, runtime profile not found` `[VERIFIED: local simctl device probe, 2026-09-12]` | CI may provide one; local runtime must be installed |

**Missing dependencies with no viable local fallback:**

- An installed/available iOS simulator runtime. `xcrun simctl list devices` shows iPhone 16/17 devices only under an unavailable iOS 26.3 runtime, and the runtime list is empty. `scripts/run-tests.py` exits with `No available iPhone simulator found` in this state `[VERIFIED: scripts/run-tests.py:85-129]`.

## Security Domain

`security_enforcement` is enabled by `.planning/config.json`; this phase introduces no network endpoint, authentication change, cryptography, or user text input.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | No | No new authentication surface. |
| V3 Session Management | No | No session changes. |
| V4 Access Control | Conditional | If Bio Age is premium-gated, reuse `PaywallController`; otherwise no new access decision. |
| V5 Input Validation | Yes | Treat restored navigation paths and SwiftData IDs as potentially stale/corrupt; existing resolver/decoder already fail closed to unavailable/empty states. |
| V6 Cryptography | No | No cryptographic change. |

### Threat patterns

| Pattern | STRIDE | Mitigation |
|---------|--------|------------|
| Restored/deleted measurement ID | Tampering/DoS | `MeasurementDetailDestination` resolves live and shows unavailable content rather than forcing or using a stale object. |
| Corrupt/schema-shifted navigation restoration | Tampering/DoS | `AppRouter.decodePath` drops bad data to an empty path. |
| Accidental health-data export | Information disclosure | Keep sharing user-initiated and scoped to the selected measurement; do not add bulk export from History without a separate decision. |
| Test/preview fake shipping in Release | Supply chain | Put new repository fakes in the active test target, not app production code. |

## Assumptions Log

| # | Claim | Section | Risk if wrong |
|---|-------|---------|---------------|
| A1 | `[ASSUMED]` The phase should add a distinct immediate `MeasurementResultView` rather than redesign `MeasurementDetailView` as 07. | Summary / Design Specs | Unnecessary duplicate or missing designed flow. |
| A2 | `[ASSUMED]` No premium gate is intended for the new Bio Age screen even though `PaywallReason.bioAgeDetail` exists and is currently unused (`case bioAgeDetail` `[VERIFIED: StressMonitor/StressMonitor/Services/Premium/PaywallController.swift:6-17]`). | Security / Open Questions | Free users may see a premium-designed surface, or a locked surface may violate phase intent. |
| A3 | `[ASSUMED]` Missing prototype-only context/tags and raw sleep/activity details should render as unavailable/hidden rather than trigger schema expansion. | Data Map | Visual parity gap if user expects exact rows. |

## Open Questions

1. **Measurement Result identity:** Should `StressViewModel` expose the last saved `StressMeasurement`/ID after `repository.save`, or should Result operate only on `StressResult` and navigate to History without a detail identity?
2. **Fifth result factor naming:** The design says `Circadian phase`; the persisted factor is `recovery`. Should the UI preserve production terminology (`Recovery`) or adopt design terminology without a matching source?
3. **Bio Age truthfulness:** Is a real per-factor year-impact breakdown required, or are unavailable rows acceptable until raw sleep/activity history is persisted?
4. **Bio Age calculator change:** If a breakdown is required, should the API change be mirrored into the watch target even though the watch redesign is out of scope?
5. **Home Bio chip:** The prototype links it to Bio Age, but CONTEXT only locks the Settings row. Should Home navigation also be wired?
6. **Premium gating:** Should `BiologicalAgeView` invoke `PaywallController.present(reason: .bioAgeDetail)` for non-premium users?
7. **Severe history filter:** Should the filter list include Severe even though the prototype only shows Relaxed/Mild/Moderate/High?
8. **Local test execution:** Who installs/repairs the iOS simulator runtime before execution?

## Sources

### Primary (HIGH confidence)

- `design/screens/07-measurement.html`, `design/screens/11-history.html`, `design/screens/18-bio-age.html` — layout/actions/data fields.
- `design/css/app.css` — prototype stress palette and factor tints.
- `StressMonitor/StressMonitor/Models/{StressMeasurement,StressResult,FactorBreakdown,BioAgeResult,StressCategory}.swift` — exact persisted/display types.
- `StressMonitor/StressMonitor/Services/Repository/StressRepository.swift` and `Services/Protocols/StressRepositoryProtocol.swift` — fetch contracts and behavior.
- `StressMonitor/StressMonitor/Services/Algorithm/{BioAgeCalculator,MultiFactorStressCalculator}.swift` — result and breakdown calculations.
- `StressMonitor/StressMonitor/Navigation/{Route,AppRouter,View+NavigationDestinations}.swift` — routing and restoration behavior.
- `StressMonitor/StressMonitor/Views/Trends/*`, `Views/History/*`, `Views/Settings/*`, `Views/Dashboard/Components/*` — exemplar screen, empty-state, chart, and accessibility patterns.
- `StressMonitor/StressMonitorTests/*` and `.planning/codebase/TESTING.md` — active test conventions and fixtures.

### Secondary (MEDIUM confidence)

- `docs/design-guidelines*.md` — accessibility, dual-coding, empty-state, and touch-target requirements; production Swift helpers were preferred for exact implementation truth.

## Metadata

**Confidence breakdown:**

- Design specs: HIGH — all three HTML files were read directly and cited by line.
- Data availability: HIGH — model, calculator, and repository source files were opened; gaps are grounded in missing fields/APIs.
- Routing: HIGH — route enum, destination switch, resolver, Settings row, and per-tab stacks were opened.
- Testing: HIGH for patterns; MEDIUM for executable status because no simulator runtime is available.

**Research date:** 2026-09-12  
**Valid until:** 2026-10-12 or until the referenced Swift files change.
