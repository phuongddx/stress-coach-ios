# Getting Started

A quick guide to get StressMonitor running locally on a simulator or device.

---

## Prerequisites

- **macOS** with **Xcode 26.3+** (download from the Mac App Store or [developer.apple.com](https://developer.apple.com/xcode/))
- **iOS 18.6+** simulator runtime (bundled with Xcode)
- **watchOS 11.6+** simulator runtime (install via Xcode → Settings → Platforms if missing)
- Apple Developer account (for device builds; not required for simulator)

Verify your setup:

```bash
xcodebuild -version
# Should print Xcode 26.3 or newer
```

---

## Clone & Open

```bash
git clone <repo-url>
cd ios-stress-app
open StressMonitor/StressMonitor.xcodeproj
```

---

## Build & Run (Simulator)

1. In Xcode, select the **StressMonitor** scheme from the toolbar.
2. Choose an iOS Simulator destination (e.g., iPhone 16).
3. Press `⌘R` to build and run.

The watchOS app and widget extension are embedded in the iOS scheme and build automatically.

### Build the watchOS App Standalone

```bash
xcodebuild build \
  -project StressMonitor/StressMonitor.xcodeproj \
  -scheme "StressMonitorWatch Watch App" \
  -destination 'generic/platform=watchOS Simulator' \
  -skipPackagePluginValidation
```

If the watchOS simulator runtime is not installed:

```bash
xcodebuild -downloadPlatform watchOS
```

---

## HealthKit on the Simulator

HealthKit data is not available in the iOS Simulator by default. The app includes a debug `SimulatorHealthKitService` that provides synthetic data so you can exercise the UI and stress algorithm without a real device.

To use real HealthKit data, run on a **physical device** with HealthKit authorization granted.

---

## First Launch

On first launch the app presents an onboarding flow:

1. **Welcome** — App overview.
2. **HealthKit Authorization** — Grant read access to HRV, heart rate, sleep, activity, and recovery data.
3. **Character Selection** — Choose your stress buddy character (Ripple is the default).
4. **Dashboard** — The main stress dashboard with current score, character, and readings.

---

## Demo Mode (Debug)

For generating screenshots or previews, launch with the demo flag:

```bash
xcodebuild ... -demo-mode
```

This injects sample stress data into the UI. DEBUG builds only.

---

## Next Steps

- **Architecture** — See [ARCHITECTURE.md](./ARCHITECTURE.md) for the full system design.
- **Configuration** — See [CONFIGURATION.md](./CONFIGURATION.md) for signing, capabilities, and CI setup.
- **Development** — See [DEVELOPMENT.md](./DEVELOPMENT.md) for coding conventions and workflows.
- **Testing** — See [TESTING.md](./TESTING.md) for running and writing tests.
- **Deployment** — See [DEPLOYMENT.md](./DEPLOYMENT.md) for TestFlight and App Store release.
