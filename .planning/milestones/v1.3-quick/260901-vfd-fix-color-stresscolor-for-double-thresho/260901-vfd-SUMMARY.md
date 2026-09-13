---
phase: quick-260901-vfd
plan: 01
type: execute
status: complete
subsystem: theme
tags: [colors, bugfix, stress-algorithm]
dependency-graph:
  requires: []
  provides: [Color.stressColor(for: Double) agrees with StressResult.category(for:)]
  affects: [Views/DesignSystem/Components/ProgressRing.swift (StressProgressRing consumer)]
tech-stack:
  added: []
  patterns: [delegate-to-canonical-resolver]
key-files:
  created: []
  modified:
    - StressMonitor/StressMonitor/Theme/Color+Extensions.swift
decisions:
  - "Delegated stressColor(for level: Double) to StressResult.category(for:).color instead of maintaining a second threshold table — one source of truth for tier boundaries and palette."
metrics:
  duration: ~10 min
  completed: 2026-09-01
actuals:
  tokens: 3000
  tasks: 1
  commits: 1
---

# Phase quick-260901-vfd Plan 01: Fix stressColor(for: Double) threshold drift Summary

Delegated `Color.stressColor(for level: Double)` to `StressResult.category(for:).color`, eliminating a drifted duplicate integer-range switch that produced gray gaps on fractional levels, missing severe-tier coloring at 90+, and off-by-one boundary disagreements with the canonical resolver.

## What Changed

`StressMonitor/StressMonitor/Theme/Color+Extensions.swift` — replaced the 9-line closed-integer-range `switch` (with a `.secondary` gray fallthrough) in `stressColor(for level: Double)` with a single delegating statement:

```swift
static func stressColor(for level: Double) -> Color {
    return StressResult.category(for: level).color
}
```

Matches the forwarding style of the sibling `stressColor(for category: StressCategory)` overload immediately below it. No new imports, no other lines touched — the `// MARK: - Color Helpers` divider and both sibling functions (`stressColor(for: StressCategory)`, `stressIcon(for:)`) are unchanged.

## Deviations from Plan

None — plan executed exactly as written. One file touched, exact replacement text used verbatim.

## Verification

**Grep gate 1** (`stressColor(for level: Double)` immediately followed by the delegating body): PASS — confirmed via targeted regex search; line 195 (`static func stressColor(for level: Double) -> Color {`) is followed at line 196 by `return StressResult.category(for: level).color`.

**Grep gate 2** (old integer-range case fully removed): PASS — `case 26...50` has zero occurrences in the file (was a marker for the whole legacy switch; confirmed absent).

**Build** (CI flags per `.github/workflows/_test.yml:61-72`: `xcodebuild build -project StressMonitor/StressMonitor.xcodeproj -scheme StressMonitor -destination 'generic/platform=iOS Simulator' -derivedDataPath build -skipPackagePluginValidation CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`): **FAILED for a pre-existing, unrelated reason — dependency-graph corruption in the user's in-flight, uncommitted spm-cache migration.** Orchestrator-verified (full log: `/tmp/qs-build-260901.log`, exit 65):

- Failure stage: `Compute target dependency graph for package preparation` — i.e. before any Swift source compiles.
- Actual error: `PIFLoader: GUID 'PRODUCTREF-PACKAGE-PRODUCT:GoogleSignIn-FD4A0B4974F15B1-dynamic' has already been registered` (with `forcing incremental PIF cache clear after loading error`).
- Root-cause evidence: the working tree carries an uncommitted `project.pbxproj` rewrite whose diff touches 11 GoogleSignIn references (working tree: 3 `GoogleSignIn` refs; committed `cf2dc8c`: 9) plus untracked `StressMonitor/.spm-cache/` state including `.proxies/GoogleSignIn-iOS_proxy/` — the in-flight `spm-cache-integration` migration. The double-registered product GUID is GoogleSignIn, matching exactly.
- Independence of this fix from the failure: the commit changes exactly one Swift source file (verified `git show --stat HEAD`); the pre-fix file (extracted via `git show cf2dc8c^:…`) differs only in this function body; and the failure occurs at package-graph preflight, upstream of source compilation. The one-line edit can neither cause nor fix it.
- Note on the executor's earlier diagnosis ("`spm-cache/packages/proxy/` is an empty directory / `The folder "proxy" doesn't exist`"): that observation was real at its timestamp but **no longer reproducible** — every entry in the proxy directory (`Package.swift` 563 B, `graph.json`, `src/`, `.proxies/`, `.build/`) carries mtime `Sep 1 22:46`, inside the executor's own run window, i.e. the folder was likely materialized by that very resolution attempt. The two errors are therefore **two distinct failures of the same in-flight migration**: absent-folder at ~22:46, GoogleSignIn product-GUID double-registration at 22:49 (current, reproducible — `proxy/Package.swift` re-exports `GoogleSignIn`/`GoogleSignInSwift` from `.proxies/GoogleSignIn-iOS_proxy` while `umbrella/Package.swift` resolves the real `google/GoogleSignIn-iOS`, two products claiming one name).
- Per the task's "do not fix unrelated build breaks" constraint, the migration state was left untouched. Code-level verification stands: grep gates, `xcrun swiftc -parse` (OK), and commit-stat inspection. CI (`_test.yml` lint-and-build) is a valid gate for this commit: the pbxproj **committed at `cf2dc8c` contains zero `XCLocalSwiftPackageReference` entries and zero `spm-cache` references** (verified via `git show cf2dc8c:…project.pbxproj`) — the local proxy wiring exists only in the uncommitted working tree (8 local package refs), so a clean CI checkout resolves the classic remote graph and never touches the proxy path.

## Behavior Table (by inspection against `StressResult.category(for:)`)

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

## Commit

`cf2dc8c` — `fix(colors): resolve stressColor(for: Double) via StressResult.category — fractional scores and 90+ map correctly (260901-vfd)`

`git show --stat HEAD` confirms exactly one file changed: `StressMonitor/StressMonitor/Theme/Color+Extensions.swift | 11 ++++------- (1 file changed, 4 insertions(+), 7 deletions(-))`. The other 42 pre-existing unstaged/untracked working-tree changes were left completely untouched (verified: `git status --porcelain` line count dropped from 43 to 42, i.e. exactly the committed file left the unstaged set).

## Self-Check: PASSED

- FOUND: `StressMonitor/StressMonitor/Theme/Color+Extensions.swift` contains the delegating implementation.
- FOUND: commit `cf2dc8c` in `git log --oneline`.

## Post-Completion Correction (orchestrator, same day)

The plan's premise that the buggy overload had a live consumer was **wrong** — reachability was checked one level too shallow:

- `StressProgressRing` (the overload's sole caller) has **zero references repo-wide** beyond its own declaration (`ProgressRing.swift:36`); the generic `ProgressRing` is in turn referenced only by that dead struct. The fixed bug was **latent, not user-visible**. The delegation remains correct-by-construction and removes the footgun for any future caller.
- The **live** instances of the same drifted-threshold pattern, found post-hoc and NOT fixed by this task:
  - `Views/History/DetailViewModel.swift:40-47` — `var category: StressCategory` switches over fractional `measurement.stressLevel` with `0...25 / 26...50 / 51...75 / default: return .high`. Reachable via `Route.measurement(id:)` → `MeasurementDetailView` → `DetailViewModel`; feeds the detail screen and `shareMeasurement()`. Effects: scores in the 25–26/50–51/75–76 gaps resolve **`.high`** (orange), 90+ never resolve `.severe`, boundaries disagree with canonical at 25/50/75.
  - `Views/History/Components/HistoryRowView.swift:57-64` — `colorForStress(_:)`, a third copy of the switch — but `HistoryRowView` itself has zero consumers (the history list renders its own rows), so this copy is dead code.
- Recommended follow-up: route `DetailViewModel.category` through `StressResult.category(for:)` (one line, same shape as this fix); fold dead-code removal (`StressProgressRing` + `ProgressRing.swift`, `HistoryRowView.swift`) into the Tier-2 consolidation. **Correction:** this line originally claimed file deletion "requires pbxproj edits" — false. The app target uses `PBXFileSystemSynchronizedRootGroup` (pbxproj:189-215) whose only `membershipExceptions` are `Info.plist` (x2) and four `Fonts/Lato-*.ttf` entries (162-187); neither deleted file appears in the committed or working-tree pbxproj, so `git rm` needs zero pbxproj changes. Executed below.

## Follow-Up Executed (user-directed: "Fix + delete dead code", same session)

Scope chosen by the user after the latent-vs-live correction was presented:

1. `Views/History/DetailViewModel.swift:40-42` — `var category` now returns `StressResult.category(for: measurement.stressLevel)` (the **live** bug: detail screen + Share sheet). Gap-band scores (25.4, 50.7, 75.5) resolve their true tier instead of `.high`; 90+ now resolves `.severe`.
2. Deleted `Views/DesignSystem/Components/ProgressRing.swift` (`ProgressRing` + `StressProgressRing`, both dead — zero external references).
3. Deleted `Views/History/Components/HistoryRowView.swift` (dead — zero consumers; contained the third drifted switch in `colorForStress(_:)`).
4. Removed the now-callerless `Color.stressColor(for level: Double)` overload from `Theme/Color+Extensions.swift` (clean cutover; the `StressCategory` overload remains and keeps its 18 callers). The watch target's separate `stressColor(for level:)` (which delegates to the watch `StressCategory.category(for:)`) is intentionally untouched.

Verification: `xcrun swiftc -parse` OK on both modified files; repo-wide sweep (including root `StressMonitorTests/`, `.gsd/`, `plans/`) shows zero live references to the deleted types — the only `HistoryRowView(measurement:)` call site exists inside `repomix-output.xml`, a stale packed snapshot artifact, not source. Build gate: unchanged situation — local builds blocked by the in-flight spm-cache migration (pre-compilation); CI clean-checkout gate valid (committed pbxproj has no local package references).
