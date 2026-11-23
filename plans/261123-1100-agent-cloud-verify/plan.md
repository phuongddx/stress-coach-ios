# Agent Cloud Verify (PA2) Implementation Plan

> **For agentic workers:** each task below is independent and owns a disjoint set of files. Work in your own git worktree off `origin/main`; touch only the files your task lists. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agents verify build, tests and screenshots on GitHub Actions instead of the Mac; PR CI also builds the Release configuration; the Xcode caches actually hit.

**Architecture:** New `agent-verify.yml` (push `agent/**` + `workflow_dispatch`) runs the test suite and optional AXe screenshots on `macos-15` and uploads `.xcresult` + PNGs. A composite action `.github/actions/xcode-cache` restores SwiftPM checkouts and the Xcode 26 compilation cache from the paths `-derivedDataPath build` really uses; every Xcode job calls it. `ci.yml` gains a `Release Build` job. Docs tell agents to use the cloud loop first.

**Tech Stack:** GitHub Actions (`macos-15` standard runner only), Xcode 26.3, `actions/cache@v4`, `actions/upload-artifact@v4`, AXe, bash, actionlint, shellcheck.

**Spec:** `docs/text2prod/specs/2026-11-23-agent-cloud-verify-design.md`

## Global Constraints

- Public repo `phuongddx/stress-coach-ios`: logs and artifacts are public. Reference no secrets in new jobs; screenshots only in demo mode.
- Runners: `macos-15` (standard) only. No larger runners, no self-hosted runner, no paid service.
- Do not touch: Xcode Cloud, App Store Connect, signing, secrets, branch protection, repo visibility, `cd-testflight.yml`, `StressMonitor/ci_scripts/`, Fastlane, app source or tests.
- Never weaken checks: no skipped/disabled tests, no `continue-on-error` on a check, no `|| true` added to a build or test step.
- Commits: author `Phuong Doan <95doanphuong@gmail.com>`, conventional prefix (`ci:`, `docs:`, `chore:`), no AI attribution or co-author lines.
- Keep `-derivedDataPath build`, `-skipPackagePluginValidation`, `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO` on simulator builds; `XCODE_VERSION: "26.3"`.
- No local `xcodebuild`. Static checks only: `actionlint`, `shellcheck`, `bash -n`. Verification happens on GitHub after integration.
- Do not push; the integrator merges task branches into `agent/cloud-verify`.

## Shared interface: `.github/actions/xcode-cache` (owned by Task 2)

```yaml
- uses: ./.github/actions/xcode-cache
  with:
    job-key: test              # required; unique per job: lint-build, watchos, widget, test, build, release, agent-verify
    derived-data-path: build   # optional, default "build"
# outputs: spm-hit ("true" on exact SwiftPM key hit), compilation-hit ("true" when a compilation cache was restored)
# side effect: exports XCODE_CACHE_ARGS to $GITHUB_ENV (build settings, e.g. COMPILATION_CACHE_ENABLE_CACHING=YES)
```

Callers place it after Checkout and Select Xcode, and append `$XCODE_CACHE_ARGS` (unquoted, `# shellcheck disable=SC2086` not needed in YAML) to every `xcodebuild build|test|build-for-testing` that uses `-derivedDataPath build`. Saving happens in the nested `actions/cache` post steps; callers do nothing else.

## File Map

| File | Action | Task | Responsibility |
|---|---|---|---|
| `.github/workflows/agent-verify.yml` | Create | T1 | Agent cloud loop: tests + screenshots + artifacts |
| `.github/actions/xcode-cache/action.yml` | Create | T2 | SwiftPM + compilation cache at the real DerivedData path |
| `.github/workflows/_test.yml` | Modify | T2 | Replace broken cache steps with the action; append `$XCODE_CACHE_ARGS` |
| `.github/workflows/build.yml` | Modify | T2 | Same |
| `.github/workflows/ci.yml` | Modify | T3 | Add `release-build` job ("Release Build") |
| `CLAUDE.md` | Modify | T4 | Cloud-first build/test instructions |
| `AGENTS.md` | Modify | T4 | Same |
| `.github/workflows/testflight.yml` | Modify (header comment only) | T5 | Correct the Beta note |
| `scripts/xcode-disk-cleanup.sh` | Create | T5 | Weekly disk cleanup, dry run by default |

`screenshots.yml` is left alone (its SwiftPM cache already uses the right path).

---

### Task 1: `agent-verify.yml`

**Files:** Create `.github/workflows/agent-verify.yml`

**Interfaces:**
- Consumes: `./.github/actions/xcode-cache` (above); `scripts/screenshots/capture.sh <udid> <app>` with env `OUT_DIR`, `DEBUG_DIR`.
- Produces: workflow name `Agent Verify`, file `agent-verify.yml`; artifacts `agent-xcresult`, `agent-screenshots`; inputs `only_testing`, `screenshots`, `device`.

- [ ] Triggers: `push: branches: ['agent/**']`; `workflow_dispatch.inputs`: `only_testing` (string, default `""`, description: comma-separated `Target/Class[/method]`), `screenshots` (boolean, default true), `device` (string, default `iPhone 16`).
- [ ] `concurrency: { group: agent-verify-${{ github.ref }}, cancel-in-progress: true }`, `permissions: contents: read`, env `XCODE_VERSION`, `SCHEME`, `DEVICE: ${{ inputs.device || 'iPhone 16' }}`, `SCREENSHOTS: ${{ github.event_name == 'push' || inputs.screenshots }}`, `ONLY_TESTING: ${{ inputs.only_testing }}`.
- [ ] One job `verify` "Verify (tests + screenshots)", `runs-on: macos-15`, `timeout-minutes: 45`. Steps: Checkout → Select Xcode → `xcode-cache` with `job-key: agent-verify` → Ensure watchOS runtime (copy from `screenshots.yml`) → Boot simulator by name (copy the jq block from `screenshots.yml`) → Run tests.
- [ ] Run tests: build `-only-testing:` args from `ONLY_TESTING` (split on commas, trim spaces) in a bash array; `xcodebuild test -project … -scheme "$SCHEME" -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build -resultBundlePath TestResults.xcresult -skipPackagePluginValidation -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 "${ONLY[@]}" $XCODE_CACHE_ARGS CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO | xcbeautify --renderer github-actions` with `set -o pipefail`. Pass inputs through `env:`, never interpolate `${{ inputs.* }}` inside `run:`.
- [ ] Test summary step (`if: always()`): `xcrun xcresulttool get test-results summary --path TestResults.xcresult --compact` → totals to `$GITHUB_STEP_SUMMARY` (same approach as `_test.yml`).
- [ ] Screenshots (`if: env.SCREENSHOTS == 'true'`): `brew install cameroncooke/axe/axe`; `OUT_DIR=build/agent-screenshots DEBUG_DIR=build/agent-screenshots/debug scripts/screenshots/capture.sh "$UDID" build/Build/Products/Debug-iphonesimulator/StressMonitor.app`.
- [ ] Upload (`if: always()`, `if-no-files-found: warn`): `agent-xcresult` ← `TestResults.xcresult`; `agent-screenshots` ← `build/agent-screenshots` (only when screenshots enabled); `retention-days: 7`.
- [ ] Header comment: what it is for and the agent loop (`gh workflow run agent-verify.yml --ref <branch> -f only_testing=… ; gh run watch ; gh run download <id> -n agent-xcresult -n agent-screenshots`).
- [ ] `actionlint .github/workflows/agent-verify.yml` clean. Commit `ci: add agent-verify workflow for cloud build, test and screenshots`.

### Task 2: Cache fix

**Files:** Create `.github/actions/xcode-cache/action.yml`; Modify `.github/workflows/_test.yml`, `.github/workflows/build.yml`

**Interfaces:** Produces the shared interface above exactly (input names, outputs, `XCODE_CACHE_ARGS`).

- [ ] Composite action. Step 1 `actions/cache@v4` id `spm`: paths `<dd>/SourcePackages/checkouts`, `<dd>/SourcePackages/repositories`; key `spm-v1-${{ runner.os }}-${{ hashFiles('StressMonitor/StressMonitor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved', 'StressMonitor/spm-cache/packages/proxy/Package.resolved') }}`; restore-keys `spm-v1-${{ runner.os }}-`.
- [ ] Step 2 compilation cache: determine where Xcode 26 stores the compilation cache when `-derivedDataPath build` is used (look for Apple docs / Xcode 26 release notes on `COMPILATION_CACHE_ENABLE_CACHING`; expected `<dd>/CompilationCache.noindex`; if the location cannot be established with a source, cache `<dd>/CompilationCache.noindex` and say so in a comment as "verify on first run"). `actions/cache@v4` id `xcc`: key `xcc-v1-${{ runner.os }}-${{ inputs.job-key }}-${{ github.sha }}`, restore-keys `xcc-v1-${{ runner.os }}-${{ inputs.job-key }}-`.
- [ ] Step 3: `echo "XCODE_CACHE_ARGS=COMPILATION_CACHE_ENABLE_CACHING=YES" >> "$GITHUB_ENV"`; print hit/miss and restored sizes (`du -sh` when present) so the log shows the cache result.
- [ ] Outputs `spm-hit: ${{ steps.spm.outputs.cache-hit }}`, `compilation-hit: ${{ steps.xcc.outputs.cache-matched-key != '' }}`.
- [ ] `_test.yml`: in all four jobs remove the "Cache DerivedData" / "Cache SPM Packages" steps that point at `~/Library/Developer/Xcode/DerivedData`, add the action with job-keys `lint-build`, `watchos`, `widget`, `test`; append `$XCODE_CACHE_ARGS` to each `xcodebuild build`/`test` line. Change nothing else (lint `|| true`, plist check, test flags, artifact names stay).
- [ ] `build.yml`: same, job-key `build`.
- [ ] `actionlint` clean on all three. Commit `ci: cache SwiftPM and compilation results at the real DerivedData path`.

### Task 3: Release Build check

**Files:** Modify `.github/workflows/ci.yml`

**Interfaces:** Consumes `./.github/actions/xcode-cache` (job-key `release`). Produces check name `Release Build`.

- [ ] New top-level job `release-build`, `name: Release Build`, `runs-on: macos-15`, `timeout-minutes: 30`, `permissions: contents: read`. Steps: Checkout → Select Xcode 26.3 → xcode-cache → ensure iOS + watchOS platforms (reuse the conditional `-downloadPlatform` logic from `_test.yml` Build Widget and the watchOS guard) → build:
  `xcodebuild build -project StressMonitor/StressMonitor.xcodeproj -scheme StressMonitor -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build -skipPackagePluginValidation $XCODE_CACHE_ARGS CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO | xcbeautify --renderer github-actions` with `set -o pipefail`.
- [ ] Comment above the job: why (Release-only compile errors such as a `#Preview` using a DEBUG-only symbol, Xcode Cloud Beta run 53) and that it needs no secrets.
- [ ] Add `release-build` to `notify-failure.needs` so its failure also posts to Slack, keeping the existing condition logic.
- [ ] `actionlint` clean. Commit `ci: build the Release configuration on every pull request`.

### Task 4: Agent instructions

**Files:** Modify `CLAUDE.md`, `AGENTS.md`

- [ ] `CLAUDE.md`: at the top of "Build & Test Commands" insert a "Verify in the cloud first (default)" block: no local build/test unless unavoidable; push to an `agent/<topic>` branch (runs automatically) or `gh workflow run agent-verify.yml --ref <branch> -f only_testing=StressMonitorTests/<Class> -f screenshots=true`; `gh run watch <id> --exit-status`; `gh run download <id> -n agent-xcresult -n agent-screenshots -D /tmp/agent-verify-<id>`; Release compile errors show on the PR's `Release Build` check. Then "If a local build is unavoidable": `-parallel-testing-enabled NO`, a throwaway `-derivedDataPath`, and delete that DerivedData afterwards. Change the sentence "Use the `xc-all` MCP tools for Xcode operations:" only to say they are the local fallback. Everything else in the file unchanged.
- [ ] `AGENTS.md`: same block at the top of "Development Commands"; in "Runtime / Tooling Preferences" add one line pointing to `agent-verify.yml`; mention `scripts/xcode-disk-cleanup.sh` in the Scripts bullet. Everything else unchanged.
- [ ] Commit `docs: tell agents to verify on GitHub Actions instead of building locally`.

### Task 5: testflight note + cleanup script

**Files:** Modify `.github/workflows/testflight.yml` (header comment only); Create `scripts/xcode-disk-cleanup.sh`

- [ ] `testflight.yml` lines 5–7: replace with: emergency fallback for when Xcode Cloud Beta cannot ship a build; Beta is enabled and is started after each green Build on `main` by `cd-testflight.yml`; manual dispatch only so the two never race. No other line changes.
- [ ] `scripts/xcode-disk-cleanup.sh` (executable, `#!/usr/bin/env bash`, `set -euo pipefail`): flags `--delete` (act), `--days N` (default 7), `-h|--help`. Default is dry run: print what would be removed.
  - Size report before (and after when `--delete`): `~/Library/Developer/Xcode/DerivedData`, `~/Library/Developer/CoreSimulator/Devices`, `~/Library/Developer/XCTestDevices`, `~/Library/Caches/org.swift.swiftpm`, `~/Library/org.swift.swiftpm`, plus `xcrun simctl runtime list` (listed, never removed).
  - Unavailable simulators: list via `xcrun simctl list devices unavailable`; with `--delete` run `xcrun simctl delete unavailable`.
  - DerivedData folders older than N days (top-level entries, by mtime): list; with `--delete` remove them.
  - SwiftPM cache (`~/Library/Caches/org.swift.swiftpm`): show size; with `--delete` remove it.
  - Tolerates missing directories and missing `xcrun`. Never removes runtimes or available devices.
- [ ] `shellcheck scripts/xcode-disk-cleanup.sh` and `bash -n` clean; run it once **without** `--delete` and keep the output for the PR. Never run with `--delete`. Not installed as a scheduled job.
- [ ] Commit `chore: add dry-run-by-default Xcode disk cleanup script` and `ci: correct the Xcode Cloud Beta note in testflight.yml`.

---

## Integration and verification (integrator, not subagents)

1. Merge T1–T5 into `agent/cloud-verify` (which carries the spec and this plan); `actionlint` all workflows.
2. Push → `Agent Verify` runs on push. Open the PR to `main` → `CI` runs including `Release Build`.
3. Acceptance 1: dispatch `gh workflow run agent-verify.yml --ref agent/cloud-verify -f only_testing=StressMonitorTests/SSEParserTests -f screenshots=true`; `gh run download`; open one PNG.
4. Acceptance 2: throwaway branch from `agent/cloud-verify` adding a `#Preview` that uses a `#if DEBUG`-only symbol → Release Build fails (run via a draft PR or temporary dispatch); a branch with PR #72's fix → passes; delete throwaway branches and PRs.
5. Acceptance 3: rerun on the same commit; log shows `Cache restored from key`; cold vs warm job minutes.
6. Acceptance 4/5: PR checks green (Release Build depends on #72); sum job minutes from `gh api …/jobs`; all `macos-15`.

## Rollback

Revert the PR. No external state changes.
