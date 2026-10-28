# Configuration

This document covers build configuration, signing, capabilities, environment variables, and CI/CD setup for StressMonitor.

---

## Prerequisites

- **Xcode** 26.3+ (CI uses Xcode 26.3 on macOS 15 runners)
- **iOS** 18.6+ deployment target
- **watchOS** 11.6+ deployment target
- **Ruby** 3.3 (for fastlane)
- **Bundler** (for fastlane gem management)

---

## Project Structure

The app is a single Xcode project with three targets:

```
StressMonitor/StressMonitor.xcodeproj
├── StressMonitor/                    # iOS app target
├── StressMonitorWatch Watch App/     # watchOS target
└── StressMonitorWidget/              # Widget extension target
```

Schemes:
- `StressMonitor` — iOS app (includes watch app and widget)
- `StressMonitorWatch Watch App` — watchOS standalone build
- `StressMonitorWidgetExtension` — Widget extension build

---

## Bundle Identifiers

| Target | Bundle ID |
|--------|-----------|
| iOS App | `stress.ai.com` |
| watchOS App | `stress.ai.com.watchkitapp` |
| Widget Extension | `stress.ai.com.widget` |
| Tests | `stress.ai.com.StressMonitorTests` |

---

## Signing & Capabilities

### App Group

- `group.stress.ai.com` — Shared container for iOS app, watch app, and widget data exchange.

### iCloud / CloudKit

- iCloud Container: `iCloud.stress.ai.com`
- Service: CloudKit (end-to-end encrypted sync)

### Entitlements

iOS app (`StressMonitor.entitlements`):
- `com.apple.developer.healthkit` — HealthKit read access
- `com.apple.security.application-groups` — App group sharing
- `com.apple.developer.icloud-container-identifiers` — CloudKit container
- `com.apple.developer.icloud-services` — CloudKit service

<!-- VERIFY: Confirm watch and widget entitlements match iOS entitlements in current Xcode project -->

### HealthKit

Read-only access to:
- Heart Rate Variability (SDNN)
- Heart Rate / Resting Heart Rate
- Sleep Analysis
- Active Energy / Activity
- Recovery metrics

### Code Signing Team

- Team ID: `K2TYLYAWMK`
- Distribution identity: `iPhone Distribution`
- Provisioning via [fastlane match](https://docs.fastlane.tools/actions/match/) (App Store profiles)

---

## Supabase Configuration

The AI coaching chat uses Supabase Edge Functions. Configuration is resolved in priority order from `SupabaseConfig.swift`:

1. **Info.plist** build setting (`SUPABASE_URL`, `SUPABASE_ANON_KEY`)
2. **Process environment** (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) — used in tests
3. **UserDefaults** (`supabaseURL`, `supabaseAnonKey`) — for local QA
4. **Fallback** (compiled-in defaults)

Edge Function endpoints (under `{base}/functions/v1/`):
- `health` — Health check
- `chat` — Chat completions (SSE streaming)
- `sessions` — Session management
- `preferences` — User preferences
- `credits` — Credit/quota management
- `quick-actions` — Quick action suggestions

> **Security note**: The Supabase anon key is safe to embed only when restricted by Row-Level Security (RLS). Provide the real key via Info.plist build settings or environment variables — do not hardcode in source.

<!-- VERIFY: Supabase project URL and anon key should be injected via CI secrets or xcconfig, not committed -->

---

## Build Configuration

### Local Build

```bash
# Open in Xcode
open StressMonitor/StressMonitor.xcodeproj

# Or build from CLI
xcodebuild build \
  -project StressMonitor/StressMonitor.xcodeproj \
  -scheme StressMonitor \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath build \
  -skipPackagePluginValidation

# watchOS
xcodebuild build \
  -project StressMonitor/StressMonitor.xcodeproj \
  -scheme "StressMonitorWatch Watch App" \
  -destination 'generic/platform=watchOS Simulator'
```

### Demo Mode (Debug only)

```bash
# Launch with demo flag for screenshot/preview generation
xcodebuild ... -demo-mode
```

The app checks `ProcessInfo.processInfo.arguments.contains("-demo-mode")` (DEBUG builds only) to enable demo data.

### StoreKit: Mock vs Real

- **DEBUG**: Uses `MockStoreKitService` (no App Store network calls)
- **Release**: Uses real `StoreKitService` with live `Transaction.updates` monitoring

This is controlled by the factory in `StressMonitorApp.swift`:

```swift
#if DEBUG
private static func makeStoreKitService() -> StoreKitServiceProtocol {
    MockStoreKitService(premiumState: .shared)
}
#else
private static func makeStoreKitService() -> StoreKitServiceProtocol {
    StoreKitService(premiumState: .shared)
}
#endif
```

---

## SwiftData Configuration

The app uses a versioned schema with lightweight migration:

- **V1** (`AppSchemaV1`): `StressMeasurement`, `CharacterUnlock`
- **V2** (`AppSchemaV2`): Adds `Habit`
- Migration plan: `AppMigrationPlan` with a single lightweight stage V1 → V2

The container is stored on disk (`isStoredInMemoryOnly: false`). In-memory containers are used only for SwiftUI previews and settings previews.

---

## Background Tasks

`HealthBackgroundScheduler` registers a `BGAppRefreshTask` for periodic stress refresh. Requires:
- Background Modes capability (App Refresh)
- The app must not be in Low Power Mode for the system to schedule tasks

---

## CI/CD Configuration

### GitHub Actions Workflows

Located in `.github/workflows/`:

| Workflow | File | Purpose |
|----------|------|---------|
| CI | `ci.yml` → `_test.yml` | Lint (SwiftLint) + build iOS, watchOS, and Widget on every PR |
| Deploy | `deploy.yml` | Build & upload to TestFlight (triggers after CI on `main`/`release/*`) |
| Distribute | `distribute.yml` | Distribute processed TestFlight build to tester groups |
| Release | `release.yml` | Submit latest TestFlight build for App Store review |

### CI Environment

- **Runner**: `macos-15`
- **Xcode**: `26.3`
- **Ruby**: `3.3`
- **Build targets**: iOS Simulator (generic), watchOS Simulator (generic), Widget (generic/iOS)
- Code signing disabled in CI builds (`CODE_SIGN_IDENTITY=""`, `CODE_SIGNING_REQUIRED=NO`)
- DerivedData and SPM caches enabled

### Fastlane Lanes

| Lane | Purpose |
|------|---------|
| `build_widget` | Build widget extension only (CI validation) |
| `build_only` | Build IPA without uploading |
| `upload_beta` | Build & upload to TestFlight (no distribution) |
| `distribute_beta` | Distribute processed build to TestFlight group |
| `release` | Submit latest TestFlight build for App Store review |
| `increment_build` | Auto-increment build number from latest TestFlight/App Store |
| `setup_match` | One-time cert/profile generation into match repo |

### Required GitHub Secrets

For the deploy workflow:

| Secret | Purpose |
|--------|---------|
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect issuer ID |
| `APP_STORE_CONNECT_API_KEY_P8` | API key file contents (.p8) |
| `MATCH_PASSWORD` | fastlane match repo encryption password |
| `MATCH_GIT_URL` | Git repo storing signing certs |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Basic auth for match repo access |
| `SLACK_WEBHOOK_URL` | Slack deploy notifications (optional) |

<!-- VERIFY: Confirm all listed secrets are configured in the GitHub repository settings -->

---

## Local CI Setup (fastlane)

```bash
# Install Ruby dependencies
bundle install

# Build widget for validation
bundle exec fastlane build_widget

# Build IPA locally (requires signing setup)
bundle exec fastlane build_only
```

---

## Xcode Cloud

The project includes `ci_scripts/` for Xcode Cloud integration:
- `ci_post_clone.sh` — Runs after Xcode Cloud clones the repo
- `ci_post_xcodebuild.sh` — Runs after the Xcode Cloud build completes

<!-- VERIFY: Review ci_scripts content for current build/test commands -->
