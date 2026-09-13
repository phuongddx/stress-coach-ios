# Plan 02 — Measurement Result Screen (Expansion A)

Wave 2 (runs after Plan 01 tracer is verified; Plan 03 depends on this plan). Builds `design/screens/07-measurement.html` as an immediate post-reading result screen distinct from the retrospective `MeasurementDetailView` (`12-measurement-detail.html`), wired from Home.

## Objective

Add `MeasurementResultView` + `MeasurementResultViewModel`: score hero ring, confidence row, vs-previous delta ribbon, truthful 5-factor breakdown from live `FactorBreakdown`, Ripple takeaway, Breathe/Mini Walk actions, and "View history" CTA. Entry: tapping the Home stress hero pushes it with the live `StressResult`.

## Resolved decisions (conservative / YAGNI)

| Question | Resolution | Justification |
|---|---|---|
| Result identity / "view in history" secondary CTA | Omit identity plumbing; CTA pushes valueless `Route.history` (label **"View history"**, not "Save & view history") | `repository.save` returns `Void` — the reading is already persisted before this screen is reachable; honest label beats plumbing `PersistentIdentifier` (user-resolved). |
| Fifth factor naming | Use production name **"Recovery"**, not designed "Circadian phase" | Persisted source is `recoveryComponent`; don't label data with a name it doesn't have. |
| `60s reading` meta, sleep-debt subtitles (`-42min`), `14h since move`, `morning cortisol`, signed `+38` contributions | Omit all; factor rows show real normalized bars + raw `detailText` ("52 ms", "68 bpm") | Not derivable from `StressResult`/`FactorBreakdown`; never fabricate. |
| Ripple takeaway sentence | Reuse `InsightGenerator.generate(from:history:)` rendered by existing `RippleInsightCard` | Existing local rules engine already produces Ripple-voice copy; no new content pipeline. |
| Share toolbar action | Omit this phase | No existing single-measurement share service; bulk/share scope needs its own decision (research STRIDE note). |
| Delta basis | Latest persisted measurement strictly before `result.timestamp` (7-day lookback window) | Simplest honest "from yesterday"-style comparison without new repository APIs. |

## One-way-door decisions

None. `StressResult`/`FactorBreakdown` gain `Hashable` conformance only (additive; both are all-value structs). No SwiftData schema change, no watch change.

## Xcode project registration

Synchronized root groups (verified — see Plan 01). Create files only under `StressMonitor/StressMonitor/` and `StressMonitor/StressMonitorTests/`; no pbxproj edits.

## Tasks

### 1. Make `StressResult` route-carriable

- `StressMonitor/StressMonitor/Models/StressResult.swift` — conformance list → `struct StressResult: Identifiable, Codable, Hashable, Sendable`.
- `StressMonitor/StressMonitor/Models/FactorBreakdown.swift` — `struct FactorBreakdown: Codable, Hashable, Sendable`.
- Synthesized conformances suffice (all stored fields are `Hashable` value types). Required because `Route: Hashable, Codable` round-trips through `@SceneStorage` path restoration (`AppRouter.decodePath`).

### 2. Add `Route.measurementResult` + destination

- `StressMonitor/StressMonitor/Navigation/Route.swift` — History MARK group:
  ```swift
  /// Immediate post-reading result (`MeasurementResultView`). Carries the live
  /// calculation; the reading is already persisted before this is reachable.
  case measurementResult(StressResult)
  ```
- `StressMonitor/StressMonitor/Navigation/View+NavigationDestinations.swift` — switch case:
  ```swift
  case .measurementResult(let result):
      MeasurementResultView(result: result)
  ```

### 3. Create `MeasurementResultViewModel`

New file `StressMonitor/StressMonitor/Views/History/MeasurementResultViewModel.swift`:

```swift
@MainActor
@Observable
final class MeasurementResultViewModel { ... }
```

- `init(result: StressResult, repository: StressRepositoryProtocol)` — constructor DI.
- State: `private(set) var isLoading`, `private(set) var previousDelta: Int?`, `private(set) var insight: AIInsight?`, `errorMessage: String?`.
- `struct ResultFactorRow: Identifiable, Sendable` — wraps `FactorBreakdownRow.Factor` + `value: Double?` + `detailText: String?`; exposes the five rows **in design order** (`.hrv`, `.heartRate`, `.sleep`, `.activity`, `.recovery`); built from `result.factorBreakdown`; when `factorBreakdown == nil` (legacy reading) expose empty list and let the View show "Breakdown unavailable for this reading".
  - `detailText`: `"\(Int(hrv)) ms"`, `"\(Int(heartRate)) bpm"` from `StressResult`; sleep/activity/recovery → `nil` (row already renders `—` + greyed bar when `value == nil`).
- `func load() async` — `isLoading` + `defer`; `let history = try? await repository.fetchMeasurements(from: result.timestamp - 7d, to: result.timestamp)`; prior = max `timestamp` entry; `previousDelta = Int((result.level - prior.stressLevel).rounded())`, else `nil` (nil → View hides ribbon). `insight = InsightGenerator.generate(from: result, history: history ?? [])`. Swallow fetch failure with `previousDelta = nil` (honest degraded state; repo already returns `[]` on SwiftData errors).
- `var confidenceLabel: String` — `"\(Int(confidence * 100))% confidence"` + `" · 5-factor analysis"` when breakdown exists, else `" · 2-factor analysis"`.
- `var deltaLabel: String?` — `"Down \(n) pts from your last reading"` / `"Up \(n) pts..."`; nil when `previousDelta == nil`.
- Route outputs as plain constants (`Route.boxBreathing`, `Route.miniWalk`, `Route.history`) used by NavigationLinks — no methods needed.

### 4. Create `MeasurementResultView`

New file `StressMonitor/StressMonitor/Views/History/MeasurementResultView.swift`.

Exemplars: `MeasurementDetailView.swift:19-68` (section order, hero → breakdown → takeaway → actions; `FactorBreakdownRow` usage at :143-175; `HapticManager` + card buttons at :243-272), `TrendsView.swift` (root modifiers), ring styling from Dashboard `StressHeroCard`. Reuse `FactorBreakdownRow` and `RippleInsightCard` components unchanged.

- `@State private var viewModel: MeasurementResultViewModel?`; build in `.task` with `StressRepository(modelContext: modelContext)` (`.environment(\.modelContext)`), then `await vm?.load()`.
- Sections (top→bottom):
  1. Score ring: `Int(result.level.rounded())`, `result.category.displayName` (dual-coded via `Color.stressColor(for:)` + symbol from `StressCategory`), timestamp line (`result.timestamp`, short time). No "60s reading".
  2. Confidence row: `viewModel?.confidenceLabel`.
  3. Delta ribbon only when `deltaLabel != nil`.
  4. "5-factor breakdown": `ForEach` of `ResultFactorRow`s → `FactorBreakdownRow(factor:value:detailText:)`; empty → one-line unavailable note.
  5. Ripple takeaway: `RippleInsightCard(insight: insight, onAskRipple: nil)` when non-nil; omit section when nil.
  6. Action row: `NavigationLink(value: Route.boxBreathing)` "Breathe 2min" (secondary style) + `NavigationLink(value: Route.miniWalk)` "Mini Walk" (primary style); both `.minimumTouchTarget(DesignTokens.Layout.minTouchTarget)` + `HapticManager.shared.buttonPress()`.
  7. Text CTA centered: `NavigationLink(value: Route.history) { Text("View history") }`.
- Root: `.accessibleDynamicType()`, `.navigationTitle("Result")`, `.navigationBarTitleDisplayMode(.inline)`, home background (`HomeCharacterDesignTokens.homeBackground`) matching sibling screens. Loading state: skeleton ring + rows while `viewModel == nil || isLoading`.

### 5. Wire Home entry

`StressMonitor/StressMonitor/Views/DashboardView.swift` (~line 126, `StressHeroCard` in section 2):

- Wrap the card in a `Button` enabled only when `viewModel.currentStress != nil`; action `router.homePath.append(.measurementResult(stress))` (`@Environment(AppRouter.self)` already added by Plan 01; add it if this plan lands first).
- Preserve the existing `.opacity(appearAnimation ? 1 : 0)` and layout; add accessibility label `"View full result"` on the button so the hero isn't re-labeled wholesale.
- Keep `ServerScoreCard` and all other Dashboard sections untouched.

### 6. Unit tests

New file `StressMonitor/StressMonitorTests/MeasurementResultViewModelTests.swift`. Same conventions as Plan 01 (`@MainActor` Swift Testing suite, private `StressRepositoryProtocol` fake, `test[Method]_[Condition]`, tolerance for floats):

- `testLoad_ComputesPreviousDeltaFromLatestPriorMeasurement`
- `testLoad_HidesDeltaWhenNoPriorReading`
- `testFactorRows_MapAllFiveComponentsAndPreserveNilAsUnavailable`
- `testFactorRows_EmptyWhenBreakdownMissing` (legacy result)
- `testConfidenceLabel_ReflectsFactorCount`
- `testLoad_SurfacesInsightFromHistory` (or `nil`-insight case if generator returns none — assert either deterministic fixture outcome)

### 7. Verification

Same commands as Plan 01, replacing the `-only-testing` filter with `-only-testing:StressMonitorTests/MeasurementResultViewModelTests` (plus `HistoryTimelineViewModelTests` if both plans landed together). Build + lint must pass; tests run locally when a simulator runtime exists, otherwise defer to CI and record the follow-up.

## Success criteria

- Build green; new suite green (locally or CI).
- Home hero tap pushes `MeasurementResultView` with the live score/category/confidence.
- Nil factor components render `—` + greyed bar via `FactorBreakdownRow`; no fabricated subtitles or contributions.
- Delta ribbon appears only with a prior reading; CTA label is "View history" and pushes `Route.history`.
- Breathe/Mini Walk links resolve to existing screens. No `!`/IUO; 4-space indent; dual-coded hero; ≥44pt targets.

## Rollback notes

Delete `MeasurementResultView.swift`, `MeasurementResultViewModel.swift`, `MeasurementResultViewModelTests.swift`; revert `Route` case + switch case; revert `Hashable` conformances; revert the Dashboard hero Button wrap. Nothing persisted changes.
