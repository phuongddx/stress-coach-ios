# Agent verification on GitHub Actions (PA2)

Status: design, approved for implementation · Date: 2026-11-23 · Owner: ddphuong

## 1. Intent

Coding agents stop building and testing on the developer's Mac. Build, test,
watchOS/Widget builds and screenshots run on GitHub Actions standard macOS runners
(free on this public repo). TestFlight stays on Xcode Cloud as today. Cost stays $0:
standard `macos-15` runners only, no larger runners, no new paid service, no sign-ups,
no self-hosted runner.

**Scope**

- **a.** `agent-verify.yml`: triggered by `workflow_dispatch` and by push to `agent/**`.
  Inputs: an `-only-testing` filter and whether to capture screenshots. Uploads the
  `.xcresult` and screenshots as artifacts. Concurrency cancels superseded runs on the
  same branch.
- **b.** DerivedData/SwiftPM cache that actually hits; cycle time before and after,
  from real runs.
- **c.** Release-configuration build check on every PR (no signing, generic iOS),
  so an error like `PlanCard.previewAnnual` (Xcode Cloud Beta run 53, fixed in PR #72)
  fails the PR instead of the TestFlight build.
- **d.** `CLAUDE.md` and `AGENTS.md`: no local build/test by default; use
  `gh workflow run agent-verify` → `gh run watch` → `gh run download`; when a local
  build is unavoidable, `-parallel-testing-enabled NO` and delete the DerivedData
  afterwards. Every other instruction stays as is.
- **e.** Correct the stale "Xcode Cloud Beta disabled" header note in `testflight.yml`.
- **f.** `scripts/xcode-disk-cleanup.sh`: `simctl delete unavailable`, DerivedData older
  than 7 days, SwiftPM cache, size report. Dry run by default; deletes only with
  `--delete`. Not installed as a scheduled job.

**Non-goals**

- Xcode Cloud workflows, App Store Connect, signing, secrets, branch protection, repo
  visibility: unchanged.
- Removing the local simulator runtime, the "iPhone Duo" simulator or any other data on
  the Mac (PA2 step 5 waits for the owner once this workflow is proven).
- No skipped or disabled tests, no `continue-on-error` on a check.
- No change to `cd-testflight.yml`, `ci_post_clone.sh`, Fastlane.

**Acceptance criteria**

1. `agent-verify` is green at least once from an `agent/**` push and once via
   `workflow_dispatch` with an `-only-testing` filter; its `.xcresult` and screenshot
   artifacts download with `gh run download` and a screenshot opens.
2. The Release build check fails on a deliberate reproduction of the PlanCard-style
   error (a `#Preview` using a DEBUG-only symbol, on a throwaway branch that is deleted
   afterwards and never enters the PR) and passes on the real code.
3. A second run on the same commit shows a cache hit in the log; cold vs warm minutes
   reported.
4. All required PR checks are green on the final PR.
5. macOS minutes consumed by this work reported; only standard runners used.

## 2. Current state (verified 2026-11-23)

| Piece | State |
|---|---|
| `ci.yml` → `_test.yml` | PR to `main`/`develop`; jobs Lint & Build, Build watchOS, Build Widget, Test; avg 12.1 min wall (14 runs, 30 days) |
| Job averages | Test 10.3 min (Run Tests step 9.1), Lint & Build 7.1 (Build iOS step 6.4), Build watchOS 6.8, Build Widget 6.0 |
| `build.yml` | push to `main`; build-for-testing; avg 7.6 min |
| `screenshots.yml` | manual; AXe + `scripts/screenshots/capture.sh` in demo mode; avg 16.3 min |
| Cache in `_test.yml`/`build.yml` | **never useful**: caches `~/Library/Developer/Xcode/DerivedData` but every build uses `-derivedDataPath build`; SwiftPM paths point at the same wrong place. Run 45108050356: 383 MB restored, packages still resolved for ~2.7 min |
| Release configuration | not built anywhere on GitHub; only Xcode Cloud Beta archives it, after merge |
| `PlanCard.swift` | `#Preview` blocks reference a DEBUG-only symbol; fixed in PR #72, **open, not merged** |
| Required checks on `main` | `Lint & Build / Lint & Build`, `/ Build watchOS`, `/ Build Widget`, `/ Test` |
| `testflight.yml` header | says Xcode Cloud Beta is disabled; Beta is enabled and driven by `cd-testflight.yml` |
| macOS minutes, last 30 days | 541 (all standard runners, $0 on the public repo) |

## 3. Design

```
agent pushes agent/<topic> ──► agent-verify.yml (macos-15)
   or gh workflow run agent-verify -f only_testing=… -f screenshots=true
        │  xcode-cache (SwiftPM + compilation cache)
        │  xcodebuild test [-only-testing:…] → TestResults.xcresult
        │  [screenshots] AXe capture.sh, demo mode → PNGs
        ▼
   artifacts: agent-xcresult, agent-screenshots ──► gh run download

PR ──► ci.yml
        ├─ Lint & Build (reusable _test.yml: Lint & Build, Build watchOS, Build Widget, Test)
        ├─ Release Build (new: -configuration Release, generic/platform=iOS, no signing)
        └─ notify-failure (unchanged)
```

### 3.1 `agent-verify.yml`

- Triggers: `push` to `agent/**`; `workflow_dispatch` with inputs `only_testing`
  (string, optional, e.g. `StressMonitorTests/SSEParserTests`; several separated by
  commas), `screenshots` (boolean, default true), `device` (default `iPhone 16`).
- Push runs use the defaults: full test suite, screenshots on.
- One job on `macos-15`, `timeout-minutes: 45`. Same flags as `_test.yml` Test
  (`-parallel-testing-enabled NO`, `-maximum-concurrent-test-simulator-destinations 1`,
  signing off) so agent results match the PR gate.
- Screenshots reuse `scripts/screenshots/capture.sh` against the app the test build
  produced, demo mode only (sample data), into `build/agent-screenshots`.
- Artifacts: `agent-xcresult` (`TestResults.xcresult`), `agent-screenshots`
  (PNGs + UI dumps), retention 7 days. Uploaded with `if: always()` so failures are
  inspectable.
- `concurrency: agent-verify-${{ github.ref }}`, `cancel-in-progress: true`.
- `permissions: contents: read`. No secrets referenced.
- Step summary prints the test totals from `xcresulttool` and the artifact names.

### 3.2 Cache (`.github/actions/xcode-cache`)

A composite action used by every Xcode job, so the fix lives in one place.

- **SwiftPM**: cache `build/SourcePackages/checkouts` and `build/SourcePackages/repositories`
  (the real location under `-derivedDataPath build`), key
  `spm-v1-<hash of both Package.resolved files>`, prefix restore. Shared by all jobs.
- **Compilation cache**: Xcode 26 content-addressed compilation caching
  (`COMPILATION_CACHE_ENABLE_CACHING=YES`). Content-addressed, so the mtime churn of a
  fresh checkout does not invalidate it (it does invalidate a plain DerivedData cache).
  Key `xcc-v1-<job>-<sha>`, restore by prefix `xcc-v1-<job>-`. The action exports the
  build settings callers append (`$XCODE_CACHE_ARGS`) so the flag is set in one place.
  If the compilation cache breaks a build or does not hit on a real run, it is dropped
  and only the SwiftPM cache ships (reported).
- Budget: the repo cache limit is 10 GB with LRU eviction. Report cache sizes from the
  runs.

### 3.3 Release Build check

New top-level job `release-build` (check name **Release Build**) in `ci.yml`:
`xcodebuild build -configuration Release -destination 'generic/platform=iOS'
-derivedDataPath build CODE_SIGNING_ALLOWED=NO`, ensuring the iOS and watchOS
platforms as the existing jobs do. Needs no secrets (`GoogleService-Info.plist` is
optional at build time; `FirebaseBootstrapTests` already covers its absence in Debug).
Branch protection is not changed here; the owner decides whether to make it required.

### 3.4 Docs, note, cleanup script

- `CLAUDE.md` "Build & Test Commands" and `AGENTS.md` "Development Commands" gain a
  short "Verify in the cloud first" block; existing commands stay, marked as the
  fallback when a local build is unavoidable.
- `testflight.yml` header: emergency fallback for when Xcode Cloud Beta cannot run;
  Beta is enabled and started by `cd-testflight.yml`; manual dispatch only.
- `scripts/xcode-disk-cleanup.sh`: bash, `set -euo pipefail`, shellcheck clean,
  `--delete` to act, `--help`. Never touches simulator runtimes or named devices other
  than unavailable ones.

## 4. Risks

| Risk | Mitigation |
|---|---|
| `workflow_dispatch` needs the workflow on the default branch | Try `gh workflow run agent-verify.yml --ref agent/cloud-verify` after the push run registers it; if refused, acceptance 1 (dispatch half) is reported as not met until merge |
| PR #72 not merged → Release Build fails on any branch from current `main` | Prove "pass" on a branch that contains #72; report that the PR goes green once #72 lands (rebase) |
| Compilation cache unstable on Xcode 26.3 or large | Ship SwiftPM cache alone; report numbers |
| Public logs/artifacts | No secrets referenced; screenshots only in demo mode with sample data |
| PR caches are scoped to the PR ref | Warm-run proof uses a rerun on the same ref; main's caches serve all branches after merge |
| Cleanup script deletes something wanted | Dry run by default, explicit `--delete`, unavailable simulators only |
