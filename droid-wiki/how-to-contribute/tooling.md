# Tooling

## Xcode project

- Project file: `StressMonitor/StressMonitor.xcodeproj`.
- Schemes: `StressMonitor` (iOS app + widget), `StressMonitorWatch Watch App` (watchOS app), `StressMonitorWidget` (widget extension alone).
- Workspace: there is no `.xcworkspace`; SPM dependencies are resolved by Xcode automatically.

## SwiftLint

Configuration at `.swiftlint.yml` at the repo root. Run from Xcode as a build phase or from the command line:

```bash
swiftlint lint --path StressMonitor
```

## xc-all MCP plugin

The `xc-all` MCP plugin (documented in `CLAUDE.md` and `AGENTS.md`) wraps Xcode operations as MCP tool calls: `xcode_build`, `xcode_test`, `xcode_clean`, `xcode_list`, `xcode_version`, `simulator_list`, `simulator_boot`, `simulator_shutdown`, `simulator_install_app`, `simulator_launch_app`, `simulator_screenshot`, `idb_describe`, `idb_find_element`, `idb_tap`, `idb_input`, and `simulator_health_check`.

## Fastlane

Fastlane configuration lives in `fastlane/`. The `Fastfile` defines lanes for building, signing, and uploading to App Store Connect / TestFlight. The `Appfile` declares the app identifier and Apple ID. The `Matchfile` references the match repository for code signing certificates and provisioning profiles.

Typical lanes:

- `fastlane beta` - build and upload to TestFlight.
- `fastlane release` - build and submit for App Store review.
- `fastlane sigh` / `fastlane match` - manage signing.

## CI

Two CI systems are configured:

- **GitHub Actions** at `.github/workflows/`: `ci.yml` (continuous integration), `deploy.yml` and `distribute.yml` (release automation), `release.yml`, `_test.yml`, and `droid-wiki-refresh.yml` (auto-refresh this wiki on push to main).
- **Xcode Cloud** at `ci_scripts/`: `ci_post_clone.sh` and `ci_post_xcodebuild.sh` run as Xcode Cloud scripts.

## App icon generation

`scripts/generate_app_icons.py` generates app icon assets from a source image. Outputs go into the Asset Catalog.

## Demo mode

A launch-argument flag (`-demo-mode`), DEBUG-only. Configured in the scheme's Run > Arguments tab. See [Getting started](../overview/getting-started.md) for details.

## Scripts

| Script | Purpose |
| --- | --- |
| `scripts/generate_app_icons.py` | Generate app icon set from source image |
| `scripts/run-tests.py` | Run xcodebuild tests with retries |

## Documentation tooling

- `docs/` contains narrative architecture and design documents in markdown.
- `docs-site/` contains a static site build (separate from the app).
- `design/` contains HTML mockups and the icon/character asset mapping.
