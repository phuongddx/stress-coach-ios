# Repository Guidelines

## Project Overview

iOS stress-monitoring app (SwiftUI): reads HealthKit metrics, computes a personalized multi-factor stress score, persists via SwiftData with CloudKit sync, streams AI chat via backend SSE, and monetizes via StoreKit credits/premium subscriptions. Three shipping targets: iOS app, watchOS app, widget extension.

## Repo Layout — Read First

The Xcode project is **one level down**: `StressMonitor/StressMonitor.xcodeproj`. Run all `xcodebuild`/fastlane commands from repo root with `-project StressMonitor/StressMonitor.xcodeproj`.

**Orphaned code — edits never build or run:**
- `StressMonitorTests/` (repo root)
- `StressMonitor/Models/`, `StressMonitor/Services/`, `StressMonitor/Views/`

**Real targets:**
- App: `StressMonitor/StressMonitor/`
- Tests: `StressMonitor/StressMonitorTests/`
- Watch: `StressMonitor/StressMonitorWatch Watch App/` (path contains spaces)
- Widget: `StressMonitor/StressMonitorWidget/`

Schemes: `StressMonitor`, `"StressMonitorWatch Watch App"` (shared); `StressMonitorWidgetExtension` (target-derived, no shared scheme — CI builds it by target).

## Architecture & Data Flow

**MVVM + SwiftUI.** Entry: `StressMonitor/StressMonitor/StressMonitorApp.swift` (`@main`; owns app-scope `AppRouter`, `PaywallController`, `StoreKitService`, `CreditService`, `PreferencesService`, injected via `.environment`). Root flow: `Views/Onboarding/OnboardingContainerView.swift` → `Views/MainTabView.swift` (4 tabs, each with own `NavigationStack(path:)`; `Navigation/AppRouter.swift` restores paths via `@SceneStorage`).

**State:** Most ViewModels are `@MainActor @Observable final class`. Combine/`ObservableObject` exceptions: `AgentChatViewModel`, `HealthSyncService`, `PhoneConnectivityManager`. SwiftData views use repository-mediated access (`Services/Repository/StressRepository.swift`, built from `@Environment(\.modelContext)`), sparse `@Query`.

**DI:** Protocol-based, no container. Central protocols in `Services/Protocols/` (`HealthKitServiceProtocol`, `StressAlgorithmServiceProtocol`, `StressRepositoryProtocol`, `CloudKitServiceProtocol`); domain-local ones beside their implementations (`FirebaseAuthService`, `CreditServiceProtocol`, `StoreKitServiceProtocol`, `StressFactor`). Constructor injection with concrete production defaults; tests substitute protocol fakes.

**Stress-score pipeline** (`Services/Algorithm/`): `MultiFactorStressCalculator` runs 5 `StressFactor`s — HRV `.40`, heart rate `.15`, sleep `.20`, activity `.15`, recovery `.10` (`Models/FactorWeights.swift`). Missing factors → weight renormalization; all-nil → `StressError.noData`. Legacy `StressCalculator` (HRV 70%/HR 30%) remains the `hrv:heartRate:` fallback. Personalization: `BaselineCalculator` (≥30 samples, 30-day window, IQR filtering, circadian adjustment) → `FactorCalibrator` (variance weighting, clamped ±25% of defaults). Bands (`Models/StressResult.swift`): `<25` relaxed, `<50` mild, `<75` moderate, `<90` high, `90+` severe.

**Data flow:** HealthKit (read-only: HRV SDNN, HR, RHR, sleep, steps, energy, stand, respiration, SpO₂) → `HealthKitManager` → factors → score → `StressRepository` (offline-first: local SwiftData save → widget App Group publish → optional CloudKit handoff). SwiftData schema V1: `StressMeasurement`, `CharacterUnlock`; V2 adds `Habit`. `PersonalBaseline` is Codable/UserDefaults. Primary CloudKit path is SwiftData `cloudKitDatabase: .automatic`; an explicit stack (`Services/CloudKit/CloudKitManager.swift`, `SyncEngine`, `Services/Sync/SyncManager.swift`) exists but is currently unwired.

**Backend** (`Services/API/`): `StressAPIClient` is a `@MainActor` URLSession client; `FirebaseAuthService` supplies Bearer ID tokens. Domain extensions: `+AgentChat`, `+Credits`, `+Health`, `+Preferences`, `+QuickActions`, `+Sessions`. Chat streams SSE via `Services/LLM/StressLLMService.swift` → `SSEParser.swift` → `AsyncThrowingStream`. `CreditService` is display-only convergence; backend is authoritative. `HealthSyncService` uploads yesterday's aggregates once/local-day after server consent (`403 CONSENT_REQUIRED` drives consent UI).

**Watch duplication (critical):** algorithm sources are duplicated into `StressMonitorWatch Watch App/Services/` (`MultiFactorStressCalculator`, `StressCalculator`, `StressFactor`, all `*StressFactor`, `BaselineCalculator`, `BioAgeCalculator`). Copies are **not byte-identical** — mirror changes semantically into both targets. `FactorCalibrator` is app-only. Widget shares data via App Group `group.stress.ai.com` (`Models/WidgetSharedData.swift::WidgetPublisher` writes; `StressMonitorWidget/Models/WidgetDataProvider.swift` reads) with keys/state duplicated by convention — docs elsewhere say `group.com.stressmonitor.app`; that's stale, code is ground truth.

## Key Directories

| Path | Purpose |
|---|---|
| `StressMonitor/StressMonitor/` | App target (entry, Views, ViewModels, Services, Models, Theme) |
| `StressMonitor/StressMonitorWatch Watch App/` | Watch target; duplicated algorithm sources |
| `StressMonitor/StressMonitorWidget/` | Widget extension |
| `StressMonitor/StressMonitorTests/` | Real test target |
| `docs/` | Product/engineering docs — start at `docs/INDEX.md` |
| `plans/` | Active plans and `plans/reports/` |
| `scripts/` | Test runner, icon generator, archive verifier |
| `fastlane/` | Build/release lanes |
| `design/`, `assets/` | Static design system/prototype; UI reference exports |

## Development Commands

```bash
# Build iOS (CI parity: signing off)
xcodebuild build -project StressMonitor/StressMonitor.xcodeproj \
  -scheme StressMonitor -destination 'generic/platform=iOS Simulator' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# Build watchOS — scheme name contains spaces
xcodebuild build -project StressMonitor/StressMonitor.xcodeproj \
  -scheme "StressMonitorWatch Watch App" -destination 'generic/platform=watchOS Simulator' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# All tests (CI parity — mirrors .github/workflows/_test.yml flag-for-flag)
xcodebuild test \
  -project StressMonitor/StressMonitor.xcodeproj \
  -scheme StressMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -derivedDataPath build \
  -resultBundlePath TestResults.xcresult \
  -skipPackagePluginValidation \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO

# Single class / method filter:
#   -only-testing:StressMonitorTests/SSEParserTests
#   -only-testing:StressMonitorTests/SSEParserTests/testMethod

# Local helper (finds/boots simulator; not flag-for-flag CI parity)
python3 scripts/run-tests.py

# Lint (from repo root)
swiftlint lint
```

Keep `-parallel-testing-enabled NO` and the one-destination cap when reproducing CI — parallelism is disabled deliberately.

Run on simulator with `-demo-mode` launch argument to cycle stress levels through the real pipeline (simulators have no HealthKit data).

## Code Conventions & Common Patterns

- **Naming:** `*ViewModel`, `*Service`, `*ServiceProtocol`, `*Factor`, typed `*Error` enums. Test methods `test[Method]_[Condition]`.
- **Lint:** `.swiftlint.yml` opts into `force_unwrap` and `implicitly_unwrapped_optional` — avoid `!` in new code. CI lint is advisory (`|| true`), don't regress.
- **Indentation:** 4 spaces in app target (watch copies often 2).
- **Errors:** `async throws` + small `LocalizedError` enums; avoid Swift `Result`.
- **Async:** `async let` for parallel fetches, `Task` for UI-initiated work, `AsyncStream`/`AsyncThrowingStream` for HealthKit/SSE. No custom actors; isolation via `@MainActor` + deliberate `Sendable` copies.
- **UI:** dual-code stress levels (color + icon/text), 44pt touch targets, `.accessibleDynamicType()`, `HapticManager` (`Views/Components/`), `Color.stressColor(for:)` (`Theme/Color+Extensions.swift`). Design system: `docs/design-guidelines*.md`.
- **Float assertions:** use `accuracy:` (XCTest) / explicit tolerance comparisons.
- **Comments:** none unless non-obvious business rules, external-library workarounds, or critical constraints.

## Important Files

- Entry point: `StressMonitor/StressMonitor/StressMonitorApp.swift` (schema/migration, app-scope DI)
- Stress algorithm: `StressMonitor/StressMonitor/Services/Algorithm/` (+ mirrored watch copies)
- Repository: `StressMonitor/StressMonitor/Services/Repository/StressRepository.swift`
- Backend config: `StressMonitor/StressMonitor/Services/API/StressAPIConfig.swift`
- Config truth: `StressMonitor/StressMonitor/Info.plist` (see below)
- CI: `.github/workflows/ci.yml` → `_test.yml`
- Fastlane: `fastlane/Fastfile`

**Info.plist truth:** custom `INFOPLIST_KEY_*` build settings do **not** merge into product plists on this toolchain — the `Info.plist` file is source of truth for any key that must ship. Example incident: `INFOPLIST_KEY_UIBackgroundModes = "fetch processing"` exists in pbxproj but absent from built plists — background fetch/processing never shipped. Before trusting an `INFOPLIST_KEY_*` setting, confirm the key in a merged/built plist.

**API base URL precedence** (`StressAPIConfig.swift`): Info.plist `STRESS_API_BASE_URL` → env → UserDefaults → fallback `https://stress-api.dropitx.site`.

**StoreKit config keys — intentionally absent (2026-09-25):** all six `STOREKIT_*` keys were removed from `StressMonitor/Info.plist` (commit `b85d0d3`) for the free-only App Review release. `StoreKitProductCatalog.live` still resolves via the same Info.plist → env → UserDefaults precedence — so a stray `STOREKIT_*` env var on a dev machine will make `StoreKitProductCatalogLiveTests` fail. To re-enable purchases later: restore the keys from `git show b85d0d3^:StressMonitor/StressMonitor/Info.plist`, recreate the ASC products, and attach them to a submission — in that order.

**IAP guardrail (enforced in CI):** `PurchaseAvailability.current` stays `.postponed` and this release ships no IAP evidence. Three gates enforce absence — the merged-plist check in `_test.yml` (Lint & Build), `verify-archive.sh` (fails on ANY `STOREKIT_*`-prefixed key in the shipped plist), and `StoreKitProductCatalogLiveTests` (asserts empty catalog). Do not flip `.enabled` or re-add keys without all three gates updated together. ASC subscription deletion + resubmission are tracked in `plans/260925-0819-remove-iap-mentions/`.

## Runtime / Tooling Preferences

- **CI:** macOS 15, Xcode 26.3, Ruby 3.3, fastlane 2.236.1. **Local:** Xcode 26.6, system `python3` (no iOS device platform/simulator runtimes — Swift/Xcode verification is GitHub-Actions-only). Diagnose red jobs from the run log, not memory: `PaywallController.swift:59:40` is a Swift-6-mode *warning* only (`SWIFT_VERSION=5.0`); the actual Test-job failure was `MockAuthService` missing `signInWithApple(presenting:)` (fixed `5e55944`). The legacy Xcode Cloud `PR Gate` check fails separately — GitHub Actions is the validation path; don't mix the two.
- **SPM deps (only two):** `firebase-ios-sdk` (Auth/Core) and `GoogleSignIn-iOS`, via a local proxy package. Trust `project.pbxproj`, not README/docs package tables.
- **`GoogleService-Info.plist`** is **gitignored** and untracked — required locally at `StressMonitor/StressMonitor/GoogleService-Info.plist`; provision separately. Some Firebase tests self-disable without it.
- **Release (CD):** merge to `main` → `build.yml` ("Build") → `.github/workflows/cd-testflight.yml` (ubuntu) runs `scripts/cd-testflight.sh`: starts Xcode Cloud workflow `Beta` via `asc xcode-cloud run --wait` (Beta has a Manual start condition on `main`; archives and uploads `INTERNAL_ONLY`; TestFlight group `Qa` gets all builds), waits for TestFlight processing, posts the result to Slack (repo secret `SLACK_WEBHOOK_URL`). If `main` moved past the commit Build validated, the CD run skips (notice only) and the newer Build's CD run ships. PR CI failures also post to Slack (same-repo PRs; fork PRs get no secrets and skip) (`ci.yml` job `notify-failure`). Xcode Cloud `PR Gate` is disabled; `main` requires the four `Lint & Build / *` checks. Xcode Cloud workflow settings are not in git — their written record is `docs/text2prod/specs/2026-09-26-cicd-testflight-design.md` §3.4 (rollback JSON in `plans/260926-1046-cicd-testflight-cd/backup/`). **Emergency fallback:** manual `.github/workflows/testflight.yml` (`asc` CLI + raw p12 cert `XPT2DHR688`; secrets `GOOGLE_SERVICE_INFO_PLIST_BASE64`, `BUILD_CERTIFICATE_P12_BASE64`, `P12_PASSWORD`; archive gate runs BEFORE Export IPA so a verify failure never uploads the signed IPA artifact on this public repo) — after using it, raise App Store Connect → Xcode Cloud → Settings → Build Number → Next Build Number above the uploaded number (web UI only), or the next Beta upload collides. Xcode Cloud also provisions Firebase config (`StressMonitor/ci_scripts/ci_post_clone.sh`); weekly `.github/workflows/xcodecloud-image-guard.yml` checks workflow image pairings. Other manual workflows: `distribute.yml` (`fastlane distribute_beta`), `release.yml` (`fastlane release`; `build_number`/`submit_for_review` inputs are ignored by the lane), `match.yml`. README's "How it ships" table is stale.
- **Fastlane** (repo root): `bundle exec fastlane upload_beta|distribute_beta|release|build_only|build_widget|increment_build`. Requires `APP_STORE_CONNECT_API_KEY_*`, `MATCH_PASSWORD`, `MATCH_GIT_URL`. CI always syncs Match **readonly**; only `match.yml`/`setup_match` may regenerate.
- **Signing:** automatic, team `K2TYLYAWMK`; CI builds disable signing. Bundle IDs: `stress.ai.com`, `stress.ai.com.watchkitapp`, `stress.ai.com.widget`. Targets: iOS 18.6 (some 26.1), watchOS 11.6 — ignore older "iOS 17+" doc claims. Archive/Export need `-allowProvisioningUpdates` + ASC API-key auth (manually dropping `.mobileprovision` files does nothing under Automatic signing). Adding a capability (e.g. Sign in with Apple, 2026-09-24) silently invalidates existing profiles — regenerate before building. `APPLE_ID_AUTH` is enabled on the App ID; the Firebase Apple provider must be enabled in the Firebase console before SIWA works end-to-end.
- **Simulator interaction:** prefer the `argent` MCP server (wired via `.mcp.json`/`opencode.json`) over raw `xcrun simctl`. Exception: `scripts/run-tests.py` uses simctl internally.
- **Scripts:** `scripts/run-tests.py` (tests), `scripts/generate_app_icons.py` (needs Pillow), `scripts/verify-archive.sh` (archive gate: entitlements, credentials, SDK manifests, and StoreKit-absence — fails on any `STOREKIT_*`-prefixed plist key) + `verify-archive-tests.sh` (7-test local suite, no Xcode needed — always run it after touching `verify-archive.sh`). `scripts/cd-testflight.sh` + `cd-testflight-tests.sh` (11 tests with a fake `asc`, no network — run after touching the script). Credential-scan allowlist includes `task-force-1996-hrv` (science-citation id, not a secret).

## Testing & QA

- **Frameworks:** Swift Testing dominant (47 of 49 files: `@Test`/`@Suite`/`#expect`/`#require`) + 2 XCTest files (`BioAgeCalculatorTests`, `StressContextPayloadTests`). App-hosted unit bundle (`TEST_HOST` = app); no XCUITest.
- **Coverage areas:** SSE parser, calculators, ViewModels (Account/AgentChat/Premium/Credits/Characters), `StressAPIClient+*`, auth, preferences, health sync, data deletion/entitlements, StoreKit catalog, SwiftData migrations, widget state, accessibility/contrast.
- **StoreKit:** config at `StressMonitor/StressMonitorTests/StressMonitorProducts.storekit`. StoreKitTest allows only one process-wide session — always use shared `StoreKitTestSessionProvider.session()`, never construct `SKTestSession` per-file. `StoreKitServiceTests` and `EntitlementForegroundCorrectionTests` are currently `.disabled` (unresolved session isolation).
- **SwiftData fixtures:** in-memory `ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)`; fixtures must return `(ModelContainer, ModelContext)` and keep the container alive — a container-deallocation trap caused historical exit-65 CI stalls. All suites run unconditionally (env gating removed 2026-09-04).
- **Networking fakes:** custom `URLProtocol` subclasses (`RequestCaptureURLProtocol`, `FailingURLProtocol`, …) + inline JSON. Isolation via unique `UserDefaults(suiteName:)`.
- **Coverage:** no CI coverage gate. Aspirational targets (`docs/system-architecture.md`): overall >80%, core algorithm >90%. Known gaps in `docs/TESTING.md`: `MultiFactorStressCalculator`, individual factors, repository/CloudKit sync.

## Documentation Notes

- Product docs live in `docs/` — start at `docs/INDEX.md`. Current truth for commands lives here, not in `docs/TESTING.md` (it defers here).
- Known-stale docs: `docs/INDEX.md` and `docs/code-standards.md` package tables; "iOS 17+" claims in older architecture/deployment docs; `docs/project-roadmap.md` coverage-reporting claim; `README.md` pre-existing-test-failure note. Also stale: `docs/ARCHITECTURE.md` still describes auth/chat as Supabase (`SupabaseAuthService`/`SupabaseLLMService`) — the app now uses Firebase Auth + `StressAPIClient`/`StressLLMService`; no Supabase code remains. `docs/CONFIGURATION.md`'s Supabase env-var section is dead. `docs/DEPLOYMENT.md` documents `deploy.yml` and `ci_post_xcodebuild.sh`, neither of which exists — see Runtime/Tooling Preferences → Release for the current path. README's "How it ships" Xcode-Cloud-centric pipeline table is superseded by `testflight.yml`.
- Active plans/reports go under `plans/`, not `docs/`.
