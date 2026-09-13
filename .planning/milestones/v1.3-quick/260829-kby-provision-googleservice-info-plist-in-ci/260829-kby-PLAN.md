---
phase: quick-260829-kby
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - ci_scripts/provision_firebase_config.sh
  - ci_scripts/ci_post_clone.sh
  - .github/workflows/ci.yml
  - .github/workflows/_test.yml
  - .github/workflows/deploy.yml
  - StressMonitor/StressMonitor/Services/Firebase/FirebaseBootstrap.swift
  - StressMonitor/StressMonitor/StressMonitorApp.swift
  - StressMonitor/StressMonitor/Services/DataManagement/CloudKitResetService.swift.backup
  - StressMonitor/StressMonitor/Services/Auth/AuthServiceError.swift
  - StressMonitor/StressMonitor/Services/Auth/FirebaseAuthService.swift
  - StressMonitor/StressMonitor/Services/DataManagement/DataDeleterService.swift
  - StressMonitor/StressMonitorTests/FirebaseBootstrapTests.swift
  - StressMonitor/StressMonitorTests/AuthServiceErrorTests.swift
  - StressMonitor/StressMonitorTests/AccountViewModelTests.swift
  - StressMonitor/StressMonitorTests/StressAPIClientTests.swift
  - StressMonitor/StressMonitorTests/DataDeleterServerWipeTests.swift
autonomous: false
requirements: [QUICK-260829-kby]

user_setup:
  - service: github-actions
    why: "CI builds cannot decode a Firebase config that does not exist as a secret; only a repo admin can create it."
    env_vars:
      - name: GOOGLE_SERVICE_INFO_PLIST_BASE64
        source: "GitHub repo -> Settings -> Secrets and variables -> Actions -> New repository secret (repository scope, NOT environment scope)"
    dashboard_config:
      - task: "Add the same value as a Secret environment variable named GOOGLE_SERVICE_INFO_PLIST_BASE64"
        location: "Xcode Cloud -> Settings -> Environment Variables (check 'Secret')"

estimate:
  tokens: 45000
  raw_tokens: 45000
  tasks: 4
  confidence: low

must_haves:
  truths:
    - "A CI-produced build of StressMonitor contains GoogleService-Info.plist, so FirebaseApp.configure() actually runs and anonymous auth, AI Chat, credits, IAP grant, and Google Sign-In work for a TestFlight tester."
    - "A CI run with a missing or malformed GOOGLE_SERVICE_INFO_PLIST_BASE64 fails the job with a named error instead of producing a silently broken binary."
    - "A user who hits an auth failure sees an auth-shaped message; an OAuth configuration problem no longer renders as an AI outage."
    - "The shipped .app bundle no longer contains CloudKitResetService.swift.backup."
    - "A fresh checkout without the plist still builds and launches without crashing."
  artifacts:
    - ci_scripts/provision_firebase_config.sh
    - StressMonitor/StressMonitor/Services/Firebase/FirebaseBootstrap.swift
    - StressMonitor/StressMonitor/Services/Auth/AuthServiceError.swift
    - StressMonitor/StressMonitorTests/FirebaseBootstrapTests.swift
    - StressMonitor/StressMonitorTests/AuthServiceErrorTests.swift
  key_links:
    - "GOOGLE_SERVICE_INFO_PLIST_BASE64 secret -> provision_firebase_config.sh -> StressMonitor/StressMonitor/GoogleService-Info.plist -> PBXFileSystemSynchronizedRootGroup auto-inclusion -> app bundle"
    - "ci.yml must pass `secrets: inherit` to _test.yml or the reusable workflow cannot read the secret at all"
    - "FirebaseBootstrap.state -> StressMonitorApp.init -> FirebaseApp.configure() -> FirebaseApp.app()?.options.clientID -> FirebaseAuthService.signInWithGoogle"
    - "FirebaseAuthService throw sites -> DataDeleterService.wipeServerSessionsOrSkip catch arms (a missed arm turns a skippable auth gap into a failed factory reset)"
---

<objective>
Every CI-produced build of StressMonitor ships with Firebase entirely unconfigured, because `GoogleService-Info.plist` is gitignored and nothing in `.github/workflows/`, `ci_scripts/`, or `fastlane/` ever recreates it. `StressMonitorApp.swift:192` gates `FirebaseApp.configure()` behind a bundle-path check that silently no-ops when the file is absent, so anonymous auth, AI Chat, credits, the IAP grant, and Google Sign-In are all dead in every TestFlight and App Store build. The observed symptom is a "Sign-In Failed" alert reading "AI is not available: Firebase client ID is not configured."

Purpose: make CI builds actually functional, and make this class of failure impossible to reproduce silently.
Output: a single provisioning script wired into every app-building CI path, an inspectable Firebase bootstrap state, an auth-shaped error taxonomy, and removal of a stray source file that is currently being copied into the shipped bundle.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@CLAUDE.md
@.claude/CLAUDE.md

@ci_scripts/ci_post_clone.sh
@.github/workflows/_test.yml
@StressMonitor/StressMonitor/Services/Auth/FirebaseAuthService.swift
@StressMonitor/StressMonitor/Services/LLM/LLMServiceProtocol.swift

**Verified facts — do not re-derive:**
- `.gitignore:174` ignores `StressMonitor/StressMonitor/GoogleService-Info.plist`. Confirmed via `git check-ignore -v`.
- `grep -rn "GoogleService" ci_scripts/ .github/ fastlane/` returns zero matches.
- Fastlane lanes: `upload_beta` (called by `deploy.yml`) runs `gym` and therefore builds. `distribute_beta` (`distribute.yml`) runs `pilot` with `distribute_only`, and `release` (`release.yml`) runs `deliver` — neither builds, so neither needs the plist.
- In `_test.yml`, only the `lint-and-build` and `test` jobs build the iOS app target. `build-watchos` and `build-widget` build separate targets whose synchronized root groups do not contain the plist.
- `ci.yml` calls `_test.yml` via `uses:` with no `secrets:` key. Reusable workflows do not inherit secrets by default, so `secrets: inherit` must be added or the provisioning step in `_test.yml` will always see an empty variable.
- The Xcode project is `objectVersion = 77` with `PBXFileSystemSynchronizedRootGroup`; the app target's only `membershipExceptions` entry is `Info.plist`. Anything sitting in `StressMonitor/StressMonitor/` is auto-included, which is why the decoded plist will be picked up with no `.pbxproj` edit, and also why `CloudKitResetService.swift.backup` (git-tracked) is currently copied into the bundle.
- `SettingsView.swift:88` renders `accountViewModel.errorMessage` verbatim under a "Sign-In Failed" title; it has no per-error-type branching, so fixing the thrown error type fixes the alert text with no view change.
- `ChatViewModel.swift:237` has a typed `catch let error as LLMServiceError` followed by a generic `catch` that also calls `preservePartialResponseIfNeeded()`, so an auth error that stops being an `LLMServiceError` still degrades correctly through the generic arm.
- `DataDeleterService.swift:470` catches `LLMServiceError.unavailable` specifically to skip the server-session wipe when there is no authenticated identity. This arm is load-bearing and must gain the new error cases or a signed-out factory reset starts failing.
- `MockAuthService` lives in `StressMonitor/StressMonitorTests/StressAPIClientTests.swift:11` and is shared by `FirebaseAuthServiceTests` and `AccountViewModelTests`.
</context>

<tasks>

<task type="checkpoint:human-action" gate="blocking-human">
  <name>Task 1: Create the GOOGLE_SERVICE_INFO_PLIST_BASE64 secret</name>
  <action>Create the GOOGLE_SERVICE_INFO_PLIST_BASE64 secret in GitHub Actions and Xcode Cloud</action>
  <instructions>
Secret creation has no CLI path an agent may take here — writing a Firebase config into a CI secret store is a credential-trust step a human must perform. Nothing is automatable ahead of it, so this checkpoint leads the plan.

Copy the base64-encoded local Firebase config to the clipboard:

  base64 -i StressMonitor/StressMonitor/GoogleService-Info.plist | pbcopy

Then paste it into BOTH destinations:

1. GitHub repo -> Settings -> Secrets and variables -> Actions -> New **repository** secret
   Name: GOOGLE_SERVICE_INFO_PLIST_BASE64
   Scope matters: create it at repository scope, NOT under the `production` environment. `deploy.yml` runs with `environment: production` and can still read repository secrets, but `_test.yml` runs with no environment and cannot read environment-scoped secrets at all.

2. Xcode Cloud -> Settings -> Environment Variables -> add
   Name: GOOGLE_SERVICE_INFO_PLIST_BASE64
   Value: the same base64 string
   Check the "Secret" box.

The local file at StressMonitor/StressMonitor/GoogleService-Info.plist already exists and is valid (it carries a CLIENT_ID) — this step only copies it into the two CI secret stores. Do not commit the file; `.gitignore:174` already excludes it and must stay that way.
  </instructions>
  <verification>After Task 2 lands and the branch is pushed, the CI run's "Provision Firebase config" step logs `Firebase config provisioned` in both `_test.yml` jobs instead of failing with the missing-variable message.</verification>
  <resume-signal>Type "done" when both secrets are saved.</resume-signal>
</task>

<task type="tracer">
  <name>Task 2: Provision the Firebase config in every CI path that builds the app</name>
  <precondition>GOOGLE_SERVICE_INFO_PLIST_BASE64 exists as a GitHub repository secret (Task 1). Local verification uses the on-disk StressMonitor/StressMonitor/GoogleService-Info.plist as the encoding source; confirm it is present before running the verify block.</precondition>
  <files>ci_scripts/provision_firebase_config.sh, ci_scripts/ci_post_clone.sh, .github/workflows/ci.yml, .github/workflows/_test.yml, .github/workflows/deploy.yml</files>
  <action>
This is the vertical slice: CI secret -> script -> decoded plist -> validated -> consumed by the build. One script, four call sites — do not inline the shell logic into YAML four times.

Create `ci_scripts/provision_firebase_config.sh`, executable (`chmod +x`), starting with a `#!/bin/bash` shebang and `set -euo pipefail`. It must:

- Resolve the repo root from its own location rather than trusting the caller's working directory, so Xcode Cloud and GitHub Actions behave identically. Compute it with `cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd`.
- Read `GOOGLE_SERVICE_INFO_PLIST_BASE64` from the environment using the `${VAR:-}` form (required by `set -u`). If it is empty or unset, print a message on stderr naming the variable, naming both places it must be created (GitHub repository secrets, Xcode Cloud environment variables), and `exit 1`. This is the loud failure — there is no skip branch and no fallback.
- Decode into `$REPO_ROOT/StressMonitor/StressMonitor/GoogleService-Info.plist` with `printf '%s' "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 --decode > "$DEST"`. Use `--decode`, not `-d`/`-D`, for BSD/GNU portability. If the decode fails, remove the partial file and exit non-zero — never leave a truncated plist on disk for the build to pick up.
- Validate structure: run `plutil -lint "$DEST"` with its stdout redirected to `/dev/null`.
- Validate content: run `/usr/libexec/PlistBuddy -c "Print :CLIENT_ID" "$DEST"` with its stdout redirected to `/dev/null`. Both validations are bare commands under `set -e` — do not append any success-forcing suffix to either, or the whole point of the gate is lost.
- On success, echo a single confirmation line: `Firebase config provisioned`. Never echo the secret, never `cat` the decoded plist, and never print the PlistBuddy value — the plist carries API keys and CI logs are readable by anyone with repo access.

Wire the four call sites, each invoking `bash ci_scripts/provision_firebase_config.sh` (or `./ci_scripts/...`) with `GOOGLE_SERVICE_INFO_PLIST_BASE64` in scope:

1. `.github/workflows/_test.yml`, job `lint-and-build`: a step named "Provision Firebase config" placed after "Checkout" and immediately before "Build iOS", with `env: GOOGLE_SERVICE_INFO_PLIST_BASE64: ${{ secrets.GOOGLE_SERVICE_INFO_PLIST_BASE64 }}`.
2. `.github/workflows/_test.yml`, job `test`: same step, immediately before "Run Tests". The test host app bundle needs the plist for Task 3's bootstrap test.
3. `.github/workflows/deploy.yml`: same step, placed after "Free Disk Space" and immediately before "Build & Deploy via Fastlane" so the file exists when `gym` runs.
4. `ci_scripts/ci_post_clone.sh`: call the script near the top, before the Match sync, matching the file's existing style. This one is NOT guarded by an `if [ -n ... ]` env check the way MATCH_PASSWORD is — an absent Firebase config must fail the Xcode Cloud build, whereas an absent Match password only skips cert sync.

Also add `secrets: inherit` to the `build` job in `.github/workflows/ci.yml` under the `uses:` key. Without it the reusable workflow receives an empty variable and every PR fails at the provisioning step.

Do NOT add the step to `distribute.yml` or `release.yml`: their lanes (`distribute_beta` -> `pilot distribute_only`, `release` -> `deliver`) upload an already-built binary and never invoke `gym`. Do NOT add it to the `build-watchos` or `build-widget` jobs: those build targets whose synchronized root groups do not include the plist.

No `.pbxproj` edit is needed — `PBXFileSystemSynchronizedRootGroup` auto-includes the decoded file in the app target.
  </action>
  <verify>
    <automated>cp StressMonitor/StressMonitor/GoogleService-Info.plist /tmp/gsi-backup.plist && bash -n ci_scripts/provision_firebase_config.sh && test -x ci_scripts/provision_firebase_config.sh && ! env -u GOOGLE_SERVICE_INFO_PLIST_BASE64 bash ci_scripts/provision_firebase_config.sh >/dev/null 2>&1 && ! GOOGLE_SERVICE_INFO_PLIST_BASE64="%%not-base64%%" bash ci_scripts/provision_firebase_config.sh >/dev/null 2>&1 && GOOGLE_SERVICE_INFO_PLIST_BASE64="$(base64 -i /tmp/gsi-backup.plist)" bash ci_scripts/provision_firebase_config.sh && plutil -lint StressMonitor/StressMonitor/GoogleService-Info.plist >/dev/null && /usr/libexec/PlistBuddy -c "Print :CLIENT_ID" StressMonitor/StressMonitor/GoogleService-Info.plist >/dev/null && git check-ignore -q StressMonitor/StressMonitor/GoogleService-Info.plist && ruby -ryaml -e 'ARGV.each { |f| YAML.load_file(f) }' .github/workflows/ci.yml .github/workflows/_test.yml .github/workflows/deploy.yml && test "$(grep -v '^[[:space:]]*#' .github/workflows/_test.yml | grep -c 'provision_firebase_config.sh')" -eq 2 && test "$(grep -v '^[[:space:]]*#' .github/workflows/deploy.yml | grep -c 'provision_firebase_config.sh')" -ge 1 && test "$(grep -v '^[[:space:]]*#' ci_scripts/ci_post_clone.sh | grep -c 'provision_firebase_config.sh')" -ge 1 && grep -q 'secrets: inherit' .github/workflows/ci.yml && echo PASS</automated>
  </verify>
  <done>The script hard-fails on an unset secret and on undecodable input, succeeds and produces a lint-clean plist carrying CLIENT_ID on valid input; all three YAML files parse; both `_test.yml` build/test jobs, `deploy.yml`, and `ci_post_clone.sh` invoke it; `ci.yml` inherits secrets; the decoded plist remains gitignored.</done>
  <reversibility rating="reversible">CI wiring and a standalone script — revert the commit and CI returns to its prior behavior.</reversibility>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Make the Firebase bootstrap state inspectable, and stop shipping the stray backup file</name>
  <files>StressMonitor/StressMonitor/Services/Firebase/FirebaseBootstrap.swift, StressMonitor/StressMonitor/StressMonitorApp.swift, StressMonitor/StressMonitorTests/FirebaseBootstrapTests.swift, StressMonitor/StressMonitor/Services/DataManagement/CloudKitResetService.swift.backup</files>
  <behavior>
    - `FirebaseBootstrap.bootstrap()` returns `.configured` and leaves `FirebaseBootstrap.state == .configured` when GoogleService-Info.plist is present in the main bundle.
    - Calling `FirebaseBootstrap.bootstrap()` a second time is a no-op that returns the already-recorded state (`FirebaseApp.configure()` traps on a double call).
    - `FirebaseBootstrap.state` inside the test host is `.configured`, because the test host app bundle carries the plist. This test is the regression gate: if CI provisioning breaks, this test goes red instead of a TestFlight build going quietly dead.
    - No test asserts a crash — the missing-config path is a state value plus a log, not a trap.
  </behavior>
  <action>
Both halves of this task are about what the built app bundle contains and what it knows about its own configuration.

Create `StressMonitor/StressMonitor/Services/Firebase/FirebaseBootstrap.swift` — a caseless `enum FirebaseBootstrap` namespace (matches the `DesignTokens` / `DemoMode` precedent) containing a nested `enum State { case configured, missingConfiguration }`, a `static private(set) var state: State = .missingConfiguration`, and a `@discardableResult static func bootstrap() -> State`.

`bootstrap()` must:
- Return `state` immediately if `FirebaseApp.app() != nil`, so a repeat call cannot re-enter `FirebaseApp.configure()` (which traps on a second invocation).
- Look up `Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")`. When present: call `FirebaseApp.configure()`, set `state = .configured`, return it.
- When absent: set `state = .missingConfiguration`, emit an `os.Logger` message at `.fault` level naming the missing resource and pointing at `ci_scripts/provision_firebase_config.sh`, and return it.

Do NOT add `assertionFailure`, `fatalError`, or `preconditionFailure` on the missing path. The stated requirement is that a fresh checkout without the plist still builds and launches. The loud signal is the `.fault` log at runtime plus the failing unit test at build time — that combination is what makes this class of failure non-silent, and it costs no crash path.

Update `StressMonitorApp.init` (replacing the `if Bundle.main.path(...) != nil { ... }` block at line ~192): call `FirebaseBootstrap.bootstrap()` and start the anonymous sign-in Task only when the returned state is `.configured`. Preserve the existing explanatory comment's intent about why `Auth.auth()` rides the same guard, condensed — the comment policy allows a WHY comment for a non-obvious framework constraint, and "`Auth.auth()` traps without a configured FIRApp" is exactly that. Remove the now-stale claim that the file is simply absent on CI runners.

Write `StressMonitor/StressMonitorTests/FirebaseBootstrapTests.swift` using Swift Testing (`import Testing`), matching the style of the neighbouring suites. Assert the `<behavior>` items above. When the `.configured` assertion fails, the failure message must name `GoogleService-Info.plist` and `ci_scripts/provision_firebase_config.sh` so a developer on a fresh checkout knows the remedy immediately.

Separately: `git rm StressMonitor/StressMonitor/Services/DataManagement/CloudKitResetService.swift.backup`. The file is git-tracked and, because the app target's synchronized root group has only `Info.plist` as a membership exception, it is currently being copied into the shipped `.app`. Deletion is preferred over a `membershipExceptions` entry — the live `CloudKitResetService.swift` sits beside it, so nothing is lost.
  </action>
  <verify>
    <automated>set -o pipefail && test ! -e StressMonitor/StressMonitor/Services/DataManagement/CloudKitResetService.swift.backup && ! git ls-files | grep -q '\.backup$' && xcodebuild test -scheme StressMonitor -project StressMonitor/StressMonitor.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO -only-testing:StressMonitorTests/FirebaseBootstrapTests 2>&1 | tail -20</automated>
  </verify>
  <done>`FirebaseBootstrap.state` reports `.configured` in the test host and the suite passes; `StressMonitorApp.init` routes through `FirebaseBootstrap.bootstrap()`; no `.backup` file remains tracked or on disk; the app still builds and launches when the plist is absent.</done>
  <reversibility rating="reversible">Additive namespace plus a deletion of a redundant tracked file recoverable from git history.</reversibility>
</task>

<task type="auto" tdd="true">
  <name>Task 4: Introduce an auth error taxonomy and migrate FirebaseAuthService off LLMServiceError</name>
  <files>StressMonitor/StressMonitor/Services/Auth/AuthServiceError.swift, StressMonitor/StressMonitor/Services/Auth/FirebaseAuthService.swift, StressMonitor/StressMonitor/Services/DataManagement/DataDeleterService.swift, StressMonitor/StressMonitorTests/AuthServiceErrorTests.swift, StressMonitor/StressMonitorTests/AccountViewModelTests.swift, StressMonitor/StressMonitorTests/StressAPIClientTests.swift, StressMonitor/StressMonitorTests/DataDeleterServerWipeTests.swift</files>
  <behavior>
    - `AuthServiceError.notConfigured.errorDescription` is non-nil, reads as a sign-in problem, and contains no mention of AI or chat.
    - `AuthServiceError.notSignedIn.errorDescription` is non-nil and asks the user to sign in, phrased so it reads correctly both in the Settings "Sign-In Failed" alert and inline in the chat surface.
    - `AuthServiceError.googleSignInFailed(underlying:)` surfaces the underlying error's `localizedDescription` when one is supplied, and a generic Google Sign-In failure string when `underlying` is nil.
    - `AccountViewModel.signInWithGoogle` rethrows an `AuthServiceError` (not an `LLMServiceError`) when the auth service fails, and still sets `errorMessage` and clears `isSigningIn`.
    - `DataDeleterService.performFactoryReset` skips the server-session wipe and still completes the local + CloudKit reset when the wiper throws `AuthServiceError.notSignedIn`, exactly as it already does for `LLMServiceError.unavailable`.
  </behavior>
  <action>
Create `StressMonitor/StressMonitor/Services/Auth/AuthServiceError.swift` (one type per file, matching the repo convention) declaring `enum AuthServiceError: Error, LocalizedError` with cases `notConfigured`, `notSignedIn`, and `googleSignInFailed(underlying: Error?)`, plus an `errorDescription` switch producing the user-facing strings described in `<behavior>`. Keep the strings product-voiced and free of internal detail such as which SDK or which config key was missing — an end user cannot act on that, and it is needless disclosure. Add a `// MARK: -` divider consistent with the neighbouring files; no explanatory comments.

Migrate every throw site in `FirebaseAuthService.swift`:
- line ~51 (`signInAnonymously`, unconfigured) and line ~85 (`signInWithGoogle`, nil `clientID`) -> `AuthServiceError.notConfigured`. Line 85 is the exact origin of the reported "AI is not available: Firebase client ID is not configured." alert.
- line ~62 (`getIDToken`, no current user) -> `AuthServiceError.notSignedIn`.
- lines ~96 and ~102 (Google Sign-In returned no result / no ID token) -> `AuthServiceError.googleSignInFailed(underlying: nil)`.
Leave the `LLMServiceError` declaration in `LLMServiceProtocol.swift` untouched — `StressLLMService` and `StressAPIClient` still legitimately throw it for genuine LLM and transport failures.

Update `DataDeleterService.wipeServerSessionsOrSkip` (around line 468): add `catch AuthServiceError.notSignedIn` and `catch AuthServiceError.notConfigured` skip arms beside the existing `LLMServiceError.unavailable` arm, each logging the same "no authenticated identity" reason. Keep the existing `LLMServiceError.unavailable` arm — `StressAPIClient` still raises it for invalid server responses and the existing suite pins that path. Refresh the doc comment above the method so its reference to `getIDToken()`'s error type stays accurate.

`SettingsView.swift:88` needs no edit: the alert renders `accountViewModel.errorMessage` with no type branching, so the message improves as a consequence of the error migration. Confirm by reading it; do not restructure the alert.

Test updates (do not weaken any assertion):
- `StressAPIClientTests.swift:23` — change `MockAuthService`'s default `googleSignInError` to `AuthServiceError.googleSignInFailed(underlying: nil)`.
- `AccountViewModelTests.swift:40` and `:48` — construct the mock with `AuthServiceError.googleSignInFailed(underlying: nil)` and assert `error is AuthServiceError`.
- `DataDeleterServerWipeTests.swift` — add a test alongside `signedOutSkipsServerWipeAndStillCompletesReset` that drives `FakeServerSessionWiper` with `.throwOnList(AuthServiceError.notSignedIn)` and asserts the same outcome (wipe skipped after the list call, CloudKit reset ran once, local measurements emptied, stored chat session id cleared). Keep the existing `LLMServiceError.unavailable` test — both arms must stay covered.
- New `StressMonitor/StressMonitorTests/AuthServiceErrorTests.swift` using Swift Testing, mirroring the shape of `LLMServiceErrorTests.swift`, asserting the four `<behavior>` bullets that concern `errorDescription`, including that the `notConfigured` and `notSignedIn` descriptions do not read as an AI-availability failure.

Then run the full suite: this migration touches shared test doubles, so a green targeted run is not sufficient evidence.
  </action>
  <verify>
    <automated>set -o pipefail && xcodebuild test -scheme StressMonitor -project StressMonitor/StressMonitor.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO 2>&1 | tail -30</automated>
  </verify>
  <done>The full StressMonitor test suite passes; `FirebaseAuthService` throws only `AuthServiceError` from its own guards; `DataDeleterService` skips the server wipe for both the legacy and the new auth-unavailable error shapes; the Settings sign-in alert body no longer describes an AI outage.</done>
  <reversibility rating="reversible">New error type plus mechanical throw-site and test migration; revertable in one commit.</reversibility>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| CI secret store -> build runner filesystem | The base64 Firebase config crosses from GitHub/Xcode Cloud secret storage onto an ephemeral runner disk and into build logs' reach. |
| Build runner filesystem -> shipped .app bundle | Whatever sits in `StressMonitor/StressMonitor/` is auto-copied into the distributed binary by the synchronized root group. |
| App -> end user (error surface) | Thrown error descriptions render verbatim in user-facing alerts. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-QUICK-01 | Information Disclosure | `provision_firebase_config.sh` CI logs | medium | mitigate | Script echoes only a fixed confirmation line; `plutil -lint` and `PlistBuddy Print :CLIENT_ID` stdout redirected to `/dev/null`; the plist is never `cat`-ed. GitHub masks the secret value in logs. |
| T-QUICK-02 | Tampering | Decoded `GoogleService-Info.plist` | high | mitigate | A corrupt or truncated secret must not reach the build: decode failure removes the partial file and exits non-zero; `plutil -lint` and the `CLIENT_ID` assertion run bare under `set -euo pipefail` with no success-forcing suffix. |
| T-QUICK-03 | Information Disclosure | Repo working tree | medium | mitigate | The script writes only to the path already covered by `.gitignore:174`; Task 2's verify asserts `git check-ignore` still matches, so a future `.gitignore` edit that would leak API keys fails the gate. |
| T-QUICK-04 | Information Disclosure | Shipped `.app` bundle | low | mitigate | `CloudKitResetService.swift.backup` is currently copied into the distributed binary; Task 3 removes it and the verify asserts no tracked `.backup` files remain. |
| T-QUICK-05 | Information Disclosure | `AuthServiceError.errorDescription` | low | mitigate | User-facing strings stay product-voiced and omit SDK identity and config-key names; only `googleSignInFailed` forwards an underlying description, and only when the OS supplied one. |
| T-QUICK-06 | Denial of Service | `_test.yml` on secretless runs | low | accept | Hard-failing the PR build when the secret is unreadable is the intended behavior — a silently unconfigured binary is the failure mode being eliminated. Accepted with `secrets: inherit` added to `ci.yml` so the reachable configuration is correct. |
| T-QUICK-SC | Tampering | npm/pip/cargo installs | low | accept | No package-manager installs are added or modified by this plan; the pre-existing `brew install fastlane` and `gem install xcpretty` steps are untouched. Package legitimacy gate not applicable. |
</threat_model>

<verification>
1. `bash ci_scripts/provision_firebase_config.sh` with no secret in scope exits non-zero and names the missing variable.
2. With a valid base64 value, the same script writes a plist that passes `plutil -lint` and exposes `CLIENT_ID`.
3. `ruby -ryaml -e 'ARGV.each { |f| YAML.load_file(f) }'` parses `ci.yml`, `_test.yml`, and `deploy.yml`.
4. Full suite: `xcodebuild test -scheme StressMonitor -project StressMonitor/StressMonitor.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO` passes, including the new `FirebaseBootstrapTests` and `AuthServiceErrorTests`.
5. Push the branch and confirm the CI run's "Provision Firebase config" step logs `Firebase config provisioned` in both `_test.yml` jobs.
6. Temporarily rename the local plist, build the app, and confirm it compiles and launches without crashing; restore the file afterwards.
</verification>

<success_criteria>
- A CI build of the app contains `GoogleService-Info.plist`, so `FirebaseApp.configure()` runs and anonymous auth succeeds in TestFlight builds.
- A missing or malformed `GOOGLE_SERVICE_INFO_PLIST_BASE64` fails the CI job with a named error and never yields a shipped binary.
- `FirebaseBootstrap.state` is inspectable and pinned by a unit test, so a future provisioning regression is caught at test time.
- A Google Sign-In configuration failure renders as a sign-in error, not an AI-availability error.
- No `.backup` file is tracked in the repo or copied into the app bundle.
- Full test suite green; no test weakened or deleted.
</success_criteria>

<output>
Create `.planning/quick/260829-kby-provision-googleservice-info-plist-in-ci/260829-kby-SUMMARY.md` when done.

Commits: conventional format, author `Phuong Doan`, no Claude attribution or co-author trailers. Suggested split:
- `ci(firebase): provision GoogleService-Info.plist in every app-building CI path`
- `fix(firebase): make bootstrap state inspectable and drop stray backup from the bundle`
- `refactor(auth): introduce AuthServiceError so sign-in failures stop reading as AI outages`

Do not stage `docs/superpowers/` or `StressMonitor/StressMonitor/GoogleService-Info.plist`.
</output>
