# Changelog

All notable changes to StressMonitor will be documented in this file.

Versions are App Store marketing versions; the release flow is in
[RELEASING.md](RELEASING.md).

## [1.1.0] - submitted for App Review 2026-11-25

Build 68 from tag `v1.1.0` (`9c53c127`), branch `release/1.1`.

### Added
- Ripple, the otter coach, with a look for every stress level from Relaxed to Severe, and a new app icon
- Plus subscription (monthly and annual): unlimited AI chat, every chart, and 30- and 90-day trends
- Layout for iPhone Duo (one column on the outer display, two on the inner display)

### Changed
- Redesigned Home, Action, Trends and Settings screens, Apple Watch app and widgets
- Empty states instead of sample numbers when there is no data
- Both chat screens say the coach is AI
- Characters / companions are hidden until 1.2 (`CharactersAvailability`)

### Fixed
- Mini Walk no longer closes when paused or ended
- The breathing summary opens after a session
- The Haptics setting is saved

### Removed
- Unused `NSCameraUsageDescription` (#98)

## [1.0.1] - 2026-09-19

App Review fixes for 1.0.0, build 36 (tag `release/1.0.1`).

### Changed
- Purchases withdrawn behind `PurchaseAvailability` (App Review 2.1(b)); no in-app purchases shipped
- Science & Sources section citing peer-reviewed sources for every health claim (App Review 1.4.1)
- Widget is iPhone-only, matching the app

### Added
- `build.yml` (build on push to main), `testflight.yml` (manual TestFlight fallback), weekly Xcode Cloud image guard

## [1.0.0] - 2026-06-09

### Added
- Initial TestFlight CI/CD pipeline with Fastlane + GitHub Actions
- Automated build number incrementing from TestFlight
- TestFlight distribution to external testing groups
- SwiftLint integration in CI
