# Deployment

Build, signing, TestFlight, and App Store release workflows for StressMonitor.

---

## Overview

StressMonitor uses **fastlane** + **GitHub Actions** for CI/CD, with **fastlane match** for code signing certificate and provisioning profile management. The pipeline builds three targets (iOS app, watchOS app, widget extension) and deploys to TestFlight automatically on merges to `main`/`release/*`.

---

## Signing Configuration

| Setting | Value |
|---------|-------|
| Team ID | `K2TYLYAWMK` |
| Code Sign Identity (Release) | `iPhone Distribution` |
| Provisioning | fastlane match (App Store profiles) |
| iOS App ID | `stress.ai.com` |
| watchOS App ID | `stress.ai.com.watchkitapp` |
| Widget App ID | `stress.ai.com.widget` |

Provisioning profiles are named `match AppStore {bundle-id}` and managed in a separate git repo (configured via `MATCH_GIT_URL`).

<!-- VERIFY: Confirm the match git repo URL and access credentials are current -->

---

## GitHub Actions Workflows

All workflows are in `.github/workflows/`:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | PR to `main`/`develop` | Lint (SwiftLint) + build iOS, watchOS, Widget |
| `deploy.yml` | After CI success on `main`/`release/*`, or manual | Build & upload to TestFlight |
| `distribute.yml` | Manual (`workflow_dispatch`) | Distribute processed build to a TestFlight group |
| `release.yml` | Manual (`workflow_dispatch`) | Submit latest TestFlight build for App Store review |

### CI Pipeline (`ci.yml` → `_test.yml`)

Runs on **macOS 15** with **Xcode 26.3**:

1. **Lint & Build (iOS)** — SwiftLint + `xcodebuild build` for iOS Simulator
2. **Build watchOS** — watchOS Simulator build (auto-installs watchOS runtime if missing)
3. **Build Widget** — Widget extension build

Code signing is disabled in CI builds (`CODE_SIGN_IDENTITY=""`, `CODE_SIGNING_REQUIRED=NO`).

DerivedData and SPM packages are cached for faster subsequent builds.

### Deploy Pipeline (`deploy.yml`)

Triggers automatically when CI passes on `main` or `release/*` branches:

1. Checkout + select Xcode 26.3
2. Install Ruby/fastlane dependencies
3. Sync signing certs via `fastlane match` (readonly)
4. Update code signing settings for all three targets
5. Auto-increment build number (from latest TestFlight/App Store)
6. Build IPA via `fastlane upload_beta`
7. Upload to TestFlight (no distribution)
8. Slack notification

### Distribute Pipeline (`distribute.yml`)

Manual trigger — distributes a processed TestFlight build to a tester group:

- **TestFlight Groups**: `Core Testers`, `Extended Beta`, `Public Beta`
- Reads changelog written during `upload_beta`
- Notifies external testers

### Release Pipeline (`release.yml`)

Manual trigger — submits the latest TestFlight build for App Store review via `fastlane release` / `deliver`.

---

## Fastlane Lanes

| Lane | Command | Purpose |
|------|---------|---------|
| `build_widget` | `bundle exec fastlane build_widget` | Build widget extension only |
| `build_only` | `bundle exec fastlane build_only` | Build IPA without uploading |
| `upload_beta` | `bundle exec fastlane upload_beta` | Build & upload to TestFlight |
| `distribute_beta` | `bundle exec fastlane distribute_beta` | Distribute to TestFlight group |
| `release` | `bundle exec fastlane release` | Submit to App Store review |
| `increment_build` | `bundle exec fastlane increment_build` | Auto-increment build number |
| `setup_match` | `bundle exec fastlane setup_match` | One-time cert generation |

---

## Required Secrets

Configure these in GitHub repository settings (**Settings → Secrets and variables → Actions**):

| Secret | Purpose |
|--------|---------|
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect issuer ID |
| `APP_STORE_CONNECT_API_KEY_P8` | API key file contents (.p8) |
| `MATCH_PASSWORD` | fastlane match repo encryption password |
| `MATCH_GIT_URL` | Git repo storing signing certs |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Basic auth for match repo access |
| `SLACK_WEBHOOK_URL` | Slack deploy notifications (optional) |

<!-- VERIFY: Confirm all secrets are configured and the App Store Connect API key has not expired -->

---

## Local Deployment

### Prerequisites

```bash
# Install Ruby dependencies
bundle install
```

### Build IPA Locally

```bash
bundle exec fastlane build_only
```

This requires signing certs to be synced first (`fastlane match appstore`).

### Upload to TestFlight Locally

```bash
bundle exec fastlane upload_beta
```

---

## Xcode Cloud (Alternative CI)

The project includes scripts for Xcode Cloud in `ci_scripts/`:

- `ci_post_clone.sh` — Installs fastlane via Homebrew, syncs signing via `fastlane match appstore --readonly`
- `ci_post_xcodebuild.sh` — Runs `fastlane upload_beta` or `fastlane release` based on the Xcode Cloud workflow name (`Beta` or `Release`)

Set `MATCH_PASSWORD` and `MATCH_GIT_URL` in Xcode Cloud environment variables.

<!-- VERIFY: Confirm Xcode Cloud workflow names match the expected "Beta"/"Release" strings -->

---

## Build Number Management

Build numbers are auto-incremented based on the highest of:
- Latest TestFlight build number
- Latest App Store build number (for the current version)

This happens automatically in the `upload_beta` lane via the `increment_build` lane.

---

## Version Management

- **Version number**: Set in the Xcode project (Marketing Version)
- **Build number**: Auto-incremented by fastlane

To check current version/build:

```bash
bundle exec fastlane run get_version_number xcodeproj:"StressMonitor/StressMonitor.xcodeproj" target:"StressMonitor"
```

---

## Release Checklist

Before a release:

1. [ ] All CI checks pass on `main`
2. [ ] Test on a physical device (HealthKit requires real hardware)
3. [ ] Verify StoreKit products load correctly (Release build)
4. [ ] Test CloudKit sync between devices
5. [ ] Run `bundle exec fastlane upload_beta` (or let deploy.yml trigger)
6. [ ] Distribute to `Core Testers` via `distribute.yml`
7. [ ] After tester approval, trigger `release.yml` for App Store submission
8. [ ] Monitor App Store Connect for review status

---

## Rollback

If a bad build reaches TestFlight:

1. Stop the `distribute.yml` workflow if still running
2. Do not distribute the bad build to tester groups
3. Fix the issue, merge to `main`, let `deploy.yml` create a new build
4. Distribute the new build instead

If a bad build reaches the App Store:
- Use App Store Connect to phase-rollout or pull the version
- Submit a hotfix build via `release.yml`

<!-- VERIFY: Document the exact App Store Connect rollback procedure for the team -->

---

## Related Docs

- [CONFIGURATION.md](./CONFIGURATION.md) — Signing, capabilities, and CI environment details
- [GETTING-STARTED.md](./GETTING-STARTED.md) — Local build setup
