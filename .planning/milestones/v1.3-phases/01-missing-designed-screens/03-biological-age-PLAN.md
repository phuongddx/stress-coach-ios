# Plan 03 — Biological Age Screen + Settings Reroute (Expansion B)

Wave 3 (depends_on: 02 — both plans edit `Route.swift` + `View+NavigationDestinations.swift`; serialized to avoid exhaustive-switch merge races). Builds `design/screens/18-bio-age.html` from the existing `BioAgeCalculator`/`BioAgeResult` and fixes the wrong Settings destination (DEC-2).

## Objective

Add `BiologicalAgeView` + `BiologicalAgeViewModel` reachable via `Route.bioAge`, fed by repository history and HealthKit DOB: hero result, honest inputs section, 7-day daily-estimate chart, character insight + disclaimer, and an insufficient-data state. Change the Settings "Biological Age" row destination from `.about` to `.bioAge`.

## Resolved decisions (conservative / YAGNI)

| Question | Resolution | Justification |
|---|---|---|
| Per-factor year impacts (`-1.4 yrs` etc.) | Omit impact chips; "What's driving it" shows only real inputs (7-day avg HRV, 7-day avg RHR) | `BioAgeResult` provides no breakdown; do not extend `BioAgeCalculator` this phase (user-resolved), which also avoids watch mirroring. |
| Sleep consistency / stress load / activity CV driver rows | Omit rows entirely | No persisted source in `StressMeasurement`; current Settings path already passes `sleepEfficiency: nil`. |
| Chart "young/older" reference lines | One reference line only: chronological age | ±4yr young/older bands would be fabricated; actual-age reference is real. |
| Chronological age source | `healthKit.dateOfBirthComponents` → calendar age, explicit fallback `35` | Matches `StressViewModel.calculateBioAge` (:457-488); documented default, not Settings' silent profile default. |
| Premium gating | No gate | Phase scope has no monetization decision; `PaywallReason.bioAgeDetail` stays unused (research A2). |
| Home Bio chip tap | Out of scope | CONTEXT locks only the Settings row (DEC-2); chip is informational today. |
| Overflow `⋯` action | Omit | Undefined in prototype; no speculative menu. |
| Insufficient-data state | Screen-specific unavailable card, not a new `NoDataCard` case | Research permits purpose-specific card; avoids touching the shared component for one screen. |

## One-way-door decisions

None. `BioAgeCalculator` and its watch copy are NOT modified (no algorithm API change → no mirroring). No SwiftData schema change.

## Xcode project registration

Synchronized root groups (verified — see Plan 01). New files under `StressMonitor/StressMonitor/Views/BiologicalAge/` (new folder, still inside the synchronized app root) and `StressMonitor/StressMonitorTests/`; no pbxproj edits.

## Tasks

### 1. Add `Route.bioAge` + destination

- `StressMonitor/StressMonitor/Navigation/Route.swift` — History/Health MARK area:
  ```swift
  /// Biological Age analytics screen (`BiologicalAgeView`).
  case bioAge
  ```
- `StressMonitor/StressMonitor/Navigation/View+NavigationDestinations.swift`:
  ```swift
  case .bioAge:
      BiologicalAgeView()
  ```

### 2. Create `BiologicalAgeViewModel`

New file `StressMonitor/StressMonitor/Views/BiologicalAge/BiologicalAgeViewModel.swift`:

```swift
@MainActor
@Observable
final class BiologicalAgeViewModel { ... }
```

Constructor injection with production defaults (repo DI convention): `init(repository: StressRepositoryProtocol, healthKit: HealthKitServiceProtocol = HealthKitManager(), calculator: BioAgeCalculator = BioAgeCalculator())`.

- `struct DailyBioAgeEstimate: Identifiable, Sendable` — `let day: Date; let estimatedAge: Int`; `id` = `day`.
- State: `private(set) var isLoading`, `private(set) var result: BioAgeResult?`, `private(set) var hasSufficientData = false`, `private(set) var chronologicalAge = 35`, `private(set) var hrvAverage: Double?`, `private(set) var restingHRAverage: Double?`, `private(set) var dailyEstimates: [DailyBioAgeEstimate] = []`, `errorMessage: String?`.
- `func load() async`:
  1. `isLoading = true; defer { isLoading = false }`.
  2. Resolve age: `Calendar.current.date(from: healthKit.dateOfBirthComponents)` → year components → assign; else keep `35`.
  3. `let measurements = (try? await repository.fetchMeasurements(from: now-7d, to: now)) ?? []`.
  4. `hasSufficientData = calculator.hasEnoughData(measurements: measurements)`; if false → clear result/daily/averages and return (View shows insufficient state).
  5. Averages over the fetched set → `hrvAverage`, `restingHRAverage` (skip zero values).
  6. `result = calculator.calculate(chronologicalAge:hrv:restingHeartRate:sleepEfficiency:nil, previousResult: nil)`.
  7. Daily estimates: group measurements by `Calendar.current.startOfDay`; per-day avg HRV/RHR → `calculator.calculate(...)`; keep non-nil results only; sort old→new.

### 3. Create `BiologicalAgeView` + daily chart

New files:
- `StressMonitor/StressMonitor/Views/BiologicalAge/BiologicalAgeView.swift`
- `StressMonitor/StressMonitor/Views/BiologicalAge/Components/BioAgeDailyChart.swift`

Exemplars: `TrendsView.swift` (root modifiers, explicit sections, `.task` VM construction — use optional-VM + skeleton like Plans 01/02, not Trends' `container!`), `MeasurementDetailView.swift:183-225` (graceful `—` rows), chart accessibility from `StressMonitor/StressMonitor/Views/Trends/Components/HRVTrendChart.swift:18-68` + `.accessibilityChart(description:summary:points:)`.

- Hero: `result.estimatedAge` + "yrs", `result.differenceLabel`, trend `label` + `icon` (`BioAgeResult.swift:37-57`), subtitle `Chronological {chronologicalAge}`. Dual-code the trend (icon + text), `.stressColor`-style adaptive tinting via existing `Color.primaryGreen` family — no hard-coded prototype purples.
- "What's driving it": exactly two rows — `HRV · 7-day avg` with `"{Int} ms"` and `Resting heart rate · 7-day avg` with `"{Int} bpm"` (`nil` → `—`). No impact chips, no sleep/stress/activity rows.
- `BioAgeDailyChart(estimates: [DailyBioAgeEstimate], chronologicalAge: Int)`: simple bar chart (SwiftUI `Rectangle`/`Capsule` bars), one dashed reference line at chronological age, start/mid/today legend. Empty-safe (zero bars → hidden chart section). Accessibility: `.accessibilityChart(description:summary:points:)` with a purpose-built summary string ("Bio age ranged {min} to {max} over the last 7 days") — pure formatter tested below.
- Insight card: `result.characterExpression` (`BioAgeResult.swift:61-99`) in a card matching `RippleInsightCard` visual weight.
- Disclaimer footnote (static text): "Biological age is an estimate based on HRV and resting heart rate. Not a medical diagnosis."
- Insufficient-data state (when `!hasSufficientData && !isLoading`): screen-specific card — icon `leaf.circle`, title "Not enough data yet", copy "Take stress readings for at least \(BioAgeCalculator.minimumDataDays) days to see your biological age." No retry button needed (data accrues passively).
- Root: `.accessibleDynamicType()`, `.navigationTitle("Biological Age")`, `.navigationBarTitleDisplayMode(.inline)`.

### 4. Reroute Settings row (DEC-2)

`StressMonitor/StressMonitor/Views/Settings/SettingsView.swift` (~line 247): in the Biological Age `navRow`, change `destination: .about` → `destination: .bioAge`. Nothing else in the row changes — `navRow` already haptics + appends to `router.settingsPath` (:565-604). The trailing `bioAgeText` value stays as-is (Settings' own preview computation).

### 5. Unit tests

New file `StressMonitor/StressMonitorTests/BiologicalAgeViewModelTests.swift`. Conventions as Plans 01/02 (`@MainActor` Swift Testing suite, private fakes for `StressRepositoryProtocol` and `HealthKitServiceProtocol` inside the test file, `test[Method]_[Condition]`, float tolerance):

- Fake health kit: `dateOfBirthComponents` returns a fixed DOB (or nil for fallback test) — the protocol's default is `nil` (`HealthKitServiceProtocol.swift:28`), so a minimal fake only needs this property plus any members the protocol requires.
- `testLoad_InsufficientDataClearsResultAndShowsInsufficientState` (< 7 recent readings)
- `testLoad_ComputesResultFromSevenDayAverages` (assert estimatedAge/chronologicalAge/difference; calculator inputs recorded via known fixture values)
- `testLoad_UsesHealthKitDateOfBirthWithExplicitFallback` (DOB case + nil-DOB → 35)
- `testDailyEstimates_OrderedOldToNewAndOmitDaysWithoutResult`
- `testDailyChartSummary_DescribesRangeWithoutFabrication` (pure formatter test)

### 6. Verification

Same commands as Plan 01 with `-only-testing:StressMonitorTests/BiologicalAgeViewModelTests` (combine suites if Plans 02+03 land together). Build + lint local blockers; simulator-dependent test runs defer to CI when no runtime is installed (record follow-up).

## Success criteria

- Build green; new suite green (locally or CI).
- Settings → "Biological Age" row pushes `BiologicalAgeView` (not `AboutView`) — DEC-2.
- With <7 days data: honest insufficient-data card, no fake age. With sufficient data: hero shows real `BioAgeResult` fields; drivers show only HRV/RHR averages; chart bars match per-day calculator outputs with the chronological reference line.
- No `BioAgeCalculator`/watch changes; no `!`/IUO; 4-space indent; dual-coded trend; ≥44pt targets; `.accessibleDynamicType()`.

## Rollback notes

Delete `BiologicalAge/` folder + `BiologicalAgeViewModelTests.swift`; revert `Route` case + switch case; revert Settings row destination back to `.about`. No persisted data or calculator behavior changes.
