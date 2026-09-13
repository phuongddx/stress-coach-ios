---
phase: quick-260901-vfd
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - StressMonitor/StressMonitor/Theme/Color+Extensions.swift
autonomous: true
requirements: [QUICK-260901-vfd]

estimate:
  tokens: 12000
  raw_tokens: 12000
  tasks: 1
  confidence: low

must_haves:
  truths:
    - "A fractional stress level in a former gap band (e.g. 25.4, 50.7, 75.5) renders its category color in StressProgressRing instead of falling through to gray .secondary."
    - "A stress level of 90 or above renders the severe (red) color, not the high (orange) color."
    - "Color.stressColor(for: Double) and StressResult.category(for:) agree on every boundary value — 25.0 is mild, 50.0 is moderate, 75.0 is high, 90.0 is severe."
    - "The rendered palette is unchanged for levels that already resolved correctly — the legacy Color.stress* constants are hex-identical to StressCategory.color."
  artifacts:
    - "StressMonitor/StressMonitor/Theme/Color+Extensions.swift — stressColor(for level: Double) delegates to StressResult.category(for:).color"
  key_links:
    - "Color.stressColor(for: Double) -> StressResult.category(for:) -> StressCategory.color — one threshold table, one palette, consumed by StressProgressRing (ProgressRing.swift:42)"
---

<objective>
Fix `Color.stressColor(for level: Double)` so it resolves stress-level colors through the canonical tier resolver instead of its own drifted integer-range switch.

Purpose: The current switch uses closed integer ranges `0...25 / 26...50 / 51...75 / 76...100`. Three defects follow:
1. **Gray gaps.** Any fractional level in `(25, 26)`, `(50, 51)`, `(75, 76)` — or any level `> 100` — matches no case and falls to `default: return .secondary`, rendering the progress ring gray. `MultiFactorStressCalculator` emits fractional weighted composites, so this path is live, not theoretical.
2. **Missing severe tier.** `76...100` returns `.stressHigh`, so a level of 90+ renders orange where the canonical resolver says severe (red). `.stressSevere` is never returned by this function at all.
3. **Boundary disagreement.** The canonical `StressResult.category(for:)` uses half-open ranges `0..<25 / 25..<50 / 50..<75 / 75..<90 / default .severe`. At 25.0 this function says relaxed, canonical says mild; same class of mismatch at 50.0 and 75.0.

Grounding fact that makes this a pure behavior fix: the legacy constants at `Color+Extensions.swift:36-40` are hex-identical to `StressCategory.color` (`StressCategory.swift:13-26`) — `#34C759/#30D158`, `#007AFF/#0A84FF`, `#FFD60A`, `#FF9500/#FF9F0A`, `#FF3B30/#FF453A`. Delegation changes which tier is chosen, never the palette.

Output: One modified function in one file. Sole consumer is `StressProgressRing` (`Views/DesignSystem/Components/ProgressRing.swift:42`).
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/STATE.md

@StressMonitor/StressMonitor/Theme/Color+Extensions.swift
@StressMonitor/StressMonitor/Models/StressResult.swift
@StressMonitor/StressMonitor/Models/StressCategory.swift
</context>

<scope_boundary>
**Touch exactly one file: `StressMonitor/StressMonitor/Theme/Color+Extensions.swift`.**

Explicit non-goals — do NOT modify, "while you're in there":
- `StressMonitor/StressMonitor/Views/DesignSystem/Components/ProgressRing.swift` (the consumer)
- `StressMonitor/StressMonitor/Models/StressResult.swift` (the canonical thresholds)
- `StressMonitor/StressMonitor/Models/StressCategory.swift` (the canonical palette)
- The watch target (`StressMonitorWatch Watch App/`) — it duplicates this code by file; mirroring is a later remediation tier
- Any other threshold or color definition anywhere in the repo

Those belong to later remediation tiers and are out of scope for this quick task.

**Working-tree hygiene:** the working tree carries ~39 pre-existing modified/untracked files belonging to the user. Stage ONLY `StressMonitor/StressMonitor/Theme/Color+Extensions.swift`. **Never** run `git add -A`, `git add .`, `git commit -a`, `git stash`, `git checkout -- .`, or `git restore` against anything you did not write.
</scope_boundary>

<tasks>

<task type="auto">
  <name>Task 1: Delegate stressColor(for: Double) to the canonical tier resolver</name>
  <files>StressMonitor/StressMonitor/Theme/Color+Extensions.swift</files>
  <action>
Replace lines 192-200 of `StressMonitor/StressMonitor/Theme/Color+Extensions.swift` — the entire `static func stressColor(for level: Double) -> Color` declaration including its `switch` body — with this exact replacement:

    /// Resolves a raw 0-100 stress level to its category color.
    /// Delegates to `StressResult.category(for:)` so tier thresholds stay consistent
    /// with the algorithm's own boundaries and fractional levels never fall through.
    static func stressColor(for level: Double) -> Color {
        return StressResult.category(for: level).color
    }

Match the forwarding style of the sibling `stressColor(for category: StressCategory)` overload directly below it (explicit `return`, single statement).

Formatting requirements (SwiftLint-enforced, config `.swiftlint.yml`): 4-space indentation at the two nesting levels shown, no trailing whitespace on any line, no line over 150 characters. Leave the `// MARK: - Color Helpers` divider at line 190 and the two functions below (`stressColor(for: StressCategory)`, `stressIcon(for:)`) exactly as they are.

No new import is needed — `StressResult` and `StressCategory` are in the same `StressMonitor` module and the file already imports `SwiftUI`.

Do not delete the now-unreferenced-here `Color.stress*` constants at lines 36-40; they have other call sites and removing them is out of scope.
  </action>
  <verify>
    <automated>cd /Users/ddphuong/Projects/next-labs/stress-ai/ios-stress-app &amp;&amp; set -o pipefail &amp;&amp; xcodebuild build -project StressMonitor/StressMonitor.xcodeproj -scheme StressMonitor -destination 'generic/platform=iOS Simulator' -quiet</automated>
    <automated>grep -n 'stressColor(for level: Double)' -A 2 StressMonitor/StressMonitor/Theme/Color+Extensions.swift | grep -q 'StressResult.category(for: level).color'</automated>
    <automated>grep -c 'case 26...50' StressMonitor/StressMonitor/Theme/Color+Extensions.swift | grep -qx '0'</automated>
  </verify>
  <done>
- `xcodebuild build` for the `StressMonitor` scheme exits 0.
- `stressColor(for level: Double)` contains exactly one statement: `return StressResult.category(for: level).color`.
- The integer-range `switch` (`case 0...25` / `26...50` / `51...75` / `76...100`) and the `default: return .secondary` fallthrough are gone from the file.
- `git status --porcelain` shows `StressMonitor/StressMonitor/Theme/Color+Extensions.swift` as the only file staged by this task; every other pre-existing modification remains unstaged and untouched.
  </done>
</task>

</tasks>

<testing_note>
No unit test is in scope. SwiftUI `Color` equality is unreliable for dynamically resolved colors — `Color(light:dark:)` values do not compare equal in a way a test can depend on, so an assertion like `#expect(Color.stressColor(for: 90) == .stressSevere)` would be testing the comparison, not the fix. Agreed verification for this task is the build plus the code-inspection greps above.

For the SUMMARY, record the behavior delta by inspection against `StressResult.category(for:)`:

| level | before | after |
|-------|--------|-------|
| 25.0  | relaxed (green) | mild (blue) |
| 25.4  | **gray `.secondary`** | mild (blue) |
| 50.0  | mild (blue) | moderate (yellow) |
| 50.7  | **gray `.secondary`** | moderate (yellow) |
| 75.0  | moderate (yellow) | high (orange) |
| 75.5  | **gray `.secondary`** | high (orange) |
| 90.0  | high (orange) | **severe (red)** |
| 101.0 | **gray `.secondary`** | severe (red) |
</testing_note>

<verification>
1. `xcodebuild build -project StressMonitor/StressMonitor.xcodeproj -scheme StressMonitor -destination 'generic/platform=iOS Simulator' -quiet` exits 0 (mirrors the `lint-and-build` job in `.github/workflows/_test.yml:64-72`).
2. `git diff --stat` shows exactly one file changed with a net reduction in lines (9-line switch → 5-line delegating function plus doc comment).
3. Manual read-back of `Color+Extensions.swift:190-206` confirms the `// MARK: - Color Helpers` divider and both sibling forwarding functions are intact.
</verification>

<success_criteria>
- `Color.stressColor(for: Double)` and `StressResult.category(for:)` cannot disagree — there is one threshold table, and this function no longer owns a copy of it.
- No stress level in `[0, ∞)` resolves to `.secondary` gray.
- Levels ≥ 90 resolve to the severe (red) color.
- The `StressMonitor` scheme builds clean.
- Exactly one file changed; the user's ~39 unrelated working-tree modifications are untouched and unstaged.
</success_criteria>

<output>
Create `.planning/quick/260901-vfd-fix-color-stresscolor-for-double-thresho/260901-vfd-SUMMARY.md` when done, including the before/after behavior table from `<testing_note>`.
</output>
