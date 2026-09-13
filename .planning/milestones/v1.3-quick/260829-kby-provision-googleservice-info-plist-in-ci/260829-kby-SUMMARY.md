---
phase: quick-260829-kby
plan: 01
subsystem: auth
tags: [firebase, auth, error-handling, app-bundle]
status: complete
requires:
  - "GOOGLE_SERVICE_INFO_PLIST_BASE64 CI secret (Task 1 — deferred)"
  - "ci_scripts/provision_firebase_config.sh (Task 2 — deferred)"
provides:
  - FirebaseBootstrap
  - AuthServiceError
affects:
  - StressMonitorApp.init
  - FirebaseAuthService
  - DataDeleterService.wipeServerSessionsOrSkip
tech-stack:
  added: []
  patterns:
    - "caseless enum namespace with a private(set) static state (DesignTokens / DemoMode precedent)"
    - "per-subsystem LocalizedError enum (StressError / SyncError precedent)"
key-files:
  created:
    - StressMonitor/StressMonitor/Services/Firebase/FirebaseBootstrap.swift
    - StressMonitor/StressMonitor/Services/Auth/AuthServiceError.swift
    - StressMonitor/StressMonitorTests/FirebaseBootstrapTests.swift
    - StressMonitor/StressMonitorTests/AuthServiceErrorTests.swift
  modified:
    - StressMonitor/StressMonitor/StressMonitorApp.swift
    - StressMonitor/StressMonitor/Services/Auth/FirebaseAuthService.swift
    - StressMonitor/StressMonitor/Services/DataManagement/DataDeleterService.swift
    - StressMonitor/StressMonitorTests/AccountViewModelTests.swift
    - StressMonitor/StressMonitorTests/StressAPIClientTests.swift
    - StressMonitor/StressMonitorTests/DataDeleterServerWipeTests.swift
  deleted:
    - StressMonitor/StressMonitor/Services/DataManagement/CloudKitResetService.swift.backup
decisions:
  - "Missing Firebase config is an os.Logger .fault plus a failing unit test, never a trap — a fresh checkout without the gitignored plist must still build and launch."
  - "AuthServiceError is a new type; LLMServiceError stays untouched because StressLLMService and StressAPIClient still legitimately throw it."
  - "DataDeleterService keeps its LLMServiceError.unavailable skip arm alongside the two new AuthServiceError arms — StressAPIClient still raises it for invalid server responses."
metrics:
  duration: ~75m
  completed: 2026-08-29
actuals:
  tokens: 5200
  tasks: 2
  commits: 2
---

# Quick 260829-kby: Firebase Bootstrap State + Auth Error Taxonomy Summary

Firebase configuration is now an inspectable, test-pinned state rather than a silent
no-op, and authentication failures throw an auth-shaped `AuthServiceError` instead of
`LLMServiceError.unavailable` — so a Google Sign-In config problem stops rendering as
"AI is not available".

## Scope: Tasks 1 and 2 were deliberately skipped

**The user narrowed scope after the plan was written ("Skip CI work, code only").**
Only Tasks 3 and 4 were executed.

- **Task 1** (checkpoint: create the `GOOGLE_SERVICE_INFO_PLIST_BASE64` secret in GitHub
  Actions and Xcode Cloud) — **not done**.
- **Task 2** (`ci_scripts/provision_firebase_config.sh`, its call sites in `ci.yml` /
  `_test.yml` / `deploy.yml`, and the `secrets: inherit` fix) — **not done**. No file
  under `ci_scripts/` or `.github/workflows/` was touched.

Both tasks remain in `260829-kby-PLAN.md`, unchecked, as the record of that deferral.

**Consequence — the originating blocker is still open.** Every CI-produced build of
StressMonitor still ships without `GoogleService-Info.plist`, so `FirebaseApp.configure()`
still no-ops in TestFlight and App Store builds, and anonymous auth, AI Chat, credits, the
IAP grant, and Google Sign-In remain dead for a real tester. What landed here makes that
failure *loud and diagnosable* (a `.fault` log at runtime, a red test at build time, and
an auth-shaped error message instead of an AI-outage one). It does not fix it. The fix is
Tasks 1 and 2.

## What Was Built

### Task 3 — inspectable Firebase bootstrap state (`d8b0a7d`)

`FirebaseBootstrap` is a caseless-enum namespace with a nested `State`
(`.configured` / `.missingConfiguration`), a `private(set) static var state`, and a
`@discardableResult static func bootstrap()`.

- Returns early when `FirebaseApp.app() != nil`, so a repeat call cannot re-enter
  `FirebaseApp.configure()` (which traps on a second invocation).
- On a present plist: configures, records `.configured`, returns it.
- On an absent plist: records `.missingConfiguration` and emits an `os.Logger` `.fault`
  naming the missing resource and pointing at `ci_scripts/provision_firebase_config.sh`.
- **No `assertionFailure` / `fatalError` / `preconditionFailure`** on the missing path, per
  the planner's locked decision — a fresh checkout without the gitignored plist must still
  build and launch.

`StressMonitorApp.init` now routes through `FirebaseBootstrap.bootstrap()` and starts the
anonymous sign-in `Task` only when the result is `.configured`. The stale comment claiming
the file is simply absent on CI runners was replaced with the one non-obvious constraint
worth keeping: `Auth.auth()` traps without a configured FIRApp, so sign-in rides the same
guard. `import FirebaseCore` was dropped from that file — my change orphaned it.

`CloudKitResetService.swift.backup` was `git rm`'d. It was git-tracked and, because the
app target's synchronized root group lists only `Info.plist` as a membership exception, it
was being copied into the shipped `.app`. No tracked `.backup` file remains
(`git ls-files | grep '\.backup$'` → empty).

### Task 4 — auth error taxonomy (`4558c95`)

`AuthServiceError: Error, LocalizedError` with `notConfigured`, `notSignedIn`, and
`googleSignInFailed(underlying: Error?)`. Strings are product-voiced and disclose no SDK
identity or config-key name; `googleSignInFailed` forwards the underlying
`localizedDescription` only when the OS supplied one.

All five `FirebaseAuthService` throw sites migrated:

| Site | Was | Now |
|------|-----|-----|
| `signInAnonymously`, unconfigured | `LLMServiceError.unavailable("Firebase is not configured.")` | `.notConfigured` |
| `getIDToken`, no current user | `LLMServiceError.unavailable("Please sign in to use AI Chat.")` | `.notSignedIn` |
| `signInWithGoogle`, nil `clientID` | `LLMServiceError.unavailable("Firebase client ID is not configured.")` | `.notConfigured` |
| Google Sign-In returned no result | `LLMServiceError.unavailable(...)` | `.googleSignInFailed(underlying: nil)` |
| Google Sign-In returned no ID token | `LLMServiceError.unavailable(...)` | `.googleSignInFailed(underlying: nil)` |

That third row is the exact origin of the reported "AI is not available: Firebase client
ID is not configured." alert. `LLMServiceError` itself is untouched — `StressLLMService`
and `StressAPIClient` still throw it for genuine LLM and transport failures.

**The load-bearing consumer was handled.** `DataDeleterService.wipeServerSessionsOrSkip`
caught `LLMServiceError.unavailable` specifically to *skip* the server-session wipe when
there is no authenticated identity. Migrating `getIDToken()` off that type without matching
arms would have turned a skippable auth gap into a failed factory reset. Two arms were
added (`AuthServiceError.notSignedIn`, `AuthServiceError.notConfigured`), the existing
`LLMServiceError.unavailable` arm was kept (`StressAPIClient` still raises it for invalid
server responses, and an existing test pins that path), and the method's doc comment was
refreshed.

`SettingsView.swift:88` was read and confirmed unchanged: it renders
`accountViewModel.errorMessage` verbatim under a "Sign-In Failed" title with no per-type
branching, so the alert body improves purely as a consequence of the error migration.

Test updates (no assertion weakened, no test deleted):
- `StressAPIClientTests.swift` — shared `MockAuthService` default `googleSignInError` is now
  `AuthServiceError.googleSignInFailed(underlying: nil)`.
- `AccountViewModelTests.swift` — failure-path mock and the `error is AuthServiceError`
  assertion.
- `DataDeleterServerWipeTests.swift` — **added** a test driving
  `.throwOnList(AuthServiceError.notSignedIn)` and asserting the same outcome as the
  existing signed-out test. The existing `LLMServiceError.unavailable` test stays; both
  arms are covered.
- **New** `AuthServiceErrorTests.swift` — pins the four `errorDescription` behaviors,
  including that `.notConfigured` and `.notSignedIn` do not read as an AI-availability
  failure.

## Verification: NOT RUN — environment blocker

**I did not observe a passing test run, and I am not claiming one.**

The plan's verify gate for both tasks is
`xcodebuild test -scheme StressMonitor -destination 'platform=iOS Simulator,name=iPhone 17'`.
That command cannot run on this host:

```
$ xcodebuild build-for-testing -scheme StressMonitor \
    -project StressMonitor/StressMonitor.xcodeproj \
    -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild: error: Failed to build project StressMonitor with scheme StressMonitor.:
This scheme builds an embedded Apple Watch app. watchOS 26.2 must be installed
in order to test the scheme
```

```
$ xcrun simctl list runtimes
== Runtimes ==
iOS 26.3 (26.3.1 - 23D8133) - com.apple.CoreSimulator.SimRuntime.iOS-26-3
```

The watchOS **SDK** is present (`xcodebuild -showsdks` lists `watchos26.2` and
`watchsimulator26.2`); the watchOS **simulator runtime** is not. The `StressMonitor`
scheme embeds the watch app, and there is no test-only scheme that excludes it, so
`test` and `build-for-testing` are both refused. This is the same family as the
`WINDOWS.md #8` CoreSimulator limitation the task brief warned about, but the specific
cause here is the missing runtime, not a test-session launch failure.

Workarounds attempted and why each failed:

| Attempt | Result |
|---------|--------|
| `xcodebuild build -scheme StressMonitor -destination 'platform=iOS Simulator,name=iPhone 17'` | Same refusal ("...in order to run the scheme") |
| `-destination 'generic/platform=iOS Simulator'` | Same refusal |
| `-target StressMonitorTests -sdk iphonesimulator` | Watch target is a transitive dependency; it is forced onto the iOS SDK and fails at `CompileAssetCatalogVariant` (`AppIcon ... did not have any applicable content`). The app and test targets' Swift compile is never reached — `SwiftDriver` appears 0 times in the log. |
| `-target StressMonitorTests` without `-sdk` | Switches to device signing; fails on Match provisioning profile capability mismatches |
| Adding `ASSETCATALOG_COMPILER_APPICON_NAME=""` to skip the watch icon | The override applies to SPM package targets too and broke GTMAppAuth module-map generation. Reverted; SPM state recovered on the next clean invocation. |
| Building the watch target alone against `iphonesimulator` | Genuine compile failure — `WatchConnectivityManager does not conform to WCSessionDelegate` under the iOS SDK. Dead end. |
| `xcodebuild -downloadPlatform watchOS` (started in background) | Ran ~60 minutes without completing, then was killed when the session ended. `xcrun simctl list runtimes` still shows no watchOS runtime, so this workaround delivered nothing and must be re-run. |

**What I did verify:**

- **SwiftLint is clean on the changed files.** `swiftlint lint --quiet` reports zero
  violations in `FirebaseBootstrap.swift` and `AuthServiceError.swift`. The violations it
  reports in `StressMonitorApp.swift` (`force_try` line 141, `line_length` line 214) and
  `DataDeleterService.swift` (`duplicate_imports`, `file_length`,
  `vertical_whitespace_closing_braces`) are all pre-existing and untouched by this work.
  This confirms the new files parse; it does **not** type-check them.
- **No tracked `.backup` file remains** — `git ls-files | grep '\.backup$'` is empty and
  the file is gone from disk. This half of Task 3's verify gate passes.

**What remains unverified:** every type-level and behavioral claim. Neither the app target's
Swift compile nor any test executed. The test files in particular have never been compiled.

**To verify, on a host with the watchOS 26.2 simulator runtime installed:**

```bash
xcodebuild test -scheme StressMonitor \
  -project StressMonitor/StressMonitor.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO
```

Note the plan's `FirebaseBootstrapTests` `.configured` assertion requires
`StressMonitor/StressMonitor/GoogleService-Info.plist` to exist locally (it is gitignored).
I copied it into this worktree from the main checkout so the test host bundle would carry
it; a fresh worktree will need the same step, or Task 2's provisioning script.

## Deviations from Plan

**1. [Scope] Tasks 1 and 2 not executed** — user decision, not a discovery. Documented above.

**2. [Rule 3 — blocking] Copied the gitignored `GoogleService-Info.plist` into the worktree**
The worktree is a fresh checkout, so the gitignored plist was absent and
`FirebaseBootstrapTests` could never have reported `.configured`. Copied from the main
checkout at `/Users/ddphuong/Projects/next-labs/stress-ai/ios-stress-app/StressMonitor/StressMonitor/GoogleService-Info.plist`.
Confirmed still ignored via `git check-ignore -v` (`.gitignore:174`); it is not staged or
committed.

**3. [Rule 3 — orphan cleanup] Removed `import FirebaseCore` from `StressMonitorApp.swift`**
My change removed the file's only `FirebaseApp` reference, orphaning the import.

**4. [Commit metadata] Author set to `Phuong Doan`** via `--author`, per the project
CLAUDE.md rule, even though the repo's own history uses `phuongddx <95doanphuong@gmail.com>`.
Flagging the inconsistency; the explicit instruction won.

## Known Stubs

None.

## Threat Flags

None. The work reduces surface (T-QUICK-04: the `.backup` file no longer ships;
T-QUICK-05: `AuthServiceError` strings omit SDK identity and config-key names).

## Deferred Issues

- **Tasks 1 and 2 (CI provisioning)** — the actual fix for the originating blocker.
- **`xcodebuild test` cannot run on this host** — install the watchOS 26.2 simulator
  runtime (`xcodebuild -downloadPlatform watchOS`), or add a test-only scheme that does not
  embed the watch app. The latter would also make the CI test job cheaper.
- **All Task 3 / Task 4 code is uncompiled and untested.** This is the single largest risk
  in the change set and must be closed before the branch merges.

## Self-Check: PASSED

Files created — all present:
- `StressMonitor/StressMonitor/Services/Firebase/FirebaseBootstrap.swift`
- `StressMonitor/StressMonitor/Services/Auth/AuthServiceError.swift`
- `StressMonitor/StressMonitorTests/FirebaseBootstrapTests.swift`
- `StressMonitor/StressMonitorTests/AuthServiceErrorTests.swift`

File deleted — confirmed absent from disk and from `git ls-files`:
- `StressMonitor/StressMonitor/Services/DataManagement/CloudKitResetService.swift.backup`

Commits — both present on `worktree-agent-a742319862ae7a112`:
- `d8b0a7d` fix(firebase): make bootstrap state inspectable and drop stray backup from the bundle
- `4558c95` refactor(auth): introduce AuthServiceError so sign-in failures stop reading as AI outages

Note: this self-check verifies artifact existence only. It does **not** verify that the
code compiles or that any test passes — see "Verification: NOT RUN" above.


## Verification (orchestrator, 2026-08-29)

Executed on iPhone 17 / iOS 26.3 after installing the watchOS 26.2 simulator
runtime, which had been the standing blocker (`xcodebuild -downloadPlatform
watchOS`, detached).

| Run | total | passed | failed | skipped |
|-----|-------|--------|--------|---------|
| before target-membership fix | 237 | 216 | 6 | 15 |
| after fix (`6227803`) | 244 | 223 | 6 | 15 |

Both new suites now execute and pass: `Auth Service Error`, `Firebase Bootstrap`.
`Data Deleter Server Session Wipe` and `AccountViewModelTests` pass, including
`AuthServiceError.notSignedIn skips the wipe and still resets locally` — the
factory-reset guard.

**The 6 failures are pre-existing and not a regression.** They match
`WINDOWS.md` entry #8 exactly (recorded 2026-08-16): 4 in `CloudKit Failure &
Cancellation Ordering`, 2 in `Data Export Field Selection`, cold-launch host
restarts with the tests themselves passing. Count, suites, and signature are
identical. The 15 skips are the documented `CharacterEntitlementSyncTests`
quarantine plus StoreKit-config-dependent suites (no `.storekit` file exists).

### Defect found and fixed during verification

`StressMonitorTests` uses an explicit `PBXSourcesBuildPhase` file list, NOT a
`PBXFileSystemSynchronizedRootGroup` like the app target. `FirebaseBootstrapTests.swift`
and `AuthServiceErrorTests.swift` were committed to disk but never added to it,
so they could not compile or run — and the suite still reported green. Fixed in
`6227803`. Any future test file added to this target needs four `pbxproj`
entries; creating the file is not sufficient.

### Still open

Tasks 1-2 (CI provisioning) remain deferred per user scope decision. Every
CI-produced build still ships without `GoogleService-Info.plist`, so Firebase
is unconfigured in TestFlight and App Store builds — anonymous auth, AI Chat,
credits, IAP grant, and Google Sign-In all dead there. This work makes that
failure loud; it does not fix it.
