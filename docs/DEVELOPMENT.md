# Development

Coding conventions, project structure, and development workflows for StressMonitor contributors.

---

## Tech Stack

- **Language**: Swift 5.9+
- **UI**: SwiftUI (no UIKit)
- **State**: `@Observable` macro (iOS 17+)
- **Persistence**: SwiftData with versioned schema migration
- **Health Data**: HealthKit (read-only)
- **Cloud Sync**: CloudKit (end-to-end encrypted)
- **Monetization**: StoreKit 2
- **AI Coaching**: Supabase Edge Functions (SSE streaming)
- **Dependencies**: System frameworks only (no SPM packages)

---

## Architecture Pattern: MVVM

```
SwiftUI Views (Presentation)
    ↓ observes
@Observable ViewModels (State)
    ↓ calls
Protocol-based Services (Business Logic)
    ↓ reads/writes
SwiftData + CloudKit (Data)
```

Every service is defined behind a protocol and injected via constructor injection. This enables testability and mock substitution (e.g., `MockStoreKitService` in DEBUG, `MockServices.swift` for tests).

---

## Code Style

### Imports

Group system frameworks alphabetically:

```swift
import Foundation
import HealthKit
import Observation
import SwiftData
import SwiftUI
```

### State Management

Use `@Observable` for ViewModels — never `ObservableObject`/`@Published`:

```swift
@Observable
final class StressViewModel {
    var currentStress: StressResult?
    var isLoading = false
    var errorMessage: String?
}
```

### Dependency Injection

Protocol-based with constructor injection and defaults:

```swift
final class StressViewModel {
    private let healthKit: HealthKitServiceProtocol
    private let algorithm: StressAlgorithmServiceProtocol

    init(
        healthKit: HealthKitServiceProtocol = HealthKitManager.shared,
        algorithm: StressAlgorithmServiceProtocol = MultiFactorStressCalculator()
    ) {
        self.healthKit = healthKit
        self.algorithm = algorithm
    }
}
```

### Async/Await

Prefer `async`/`await` over callbacks. Use `.task {}` in views:

```swift
func fetchAndCalculate() async {
    isLoading = true
    defer { isLoading = false }

    do {
        async let hrv = healthKit.fetchLatestHRV()
        async let hr = healthKit.fetchHeartRate(samples: 10)
        let (hrvData, hrData) = try await (hrv, hr)
        currentStress = try await algorithm.calculateStress(
            hrv: hrvData?.value ?? 0,
            heartRate: hrData.first?.value ?? 0
        )
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

### SwiftData Models

Use the `@Model` macro:

```swift
@Model
public final class StressMeasurement {
    public var timestamp: Date
    public var stressLevel: Double
    public var hrv: Double

    init(timestamp: Date, stressLevel: Double, hrv: Double) {
        self.timestamp = timestamp
        self.stressLevel = stressLevel
        self.hrv = hrv
    }
}
```

When adding new `@Model` types, create a new `VersionedSchema` and add a migration stage to `AppMigrationPlan` in `StressMonitorApp.swift` to prevent silent store resets.

---

## UI/UX Design System

All UI work must follow the project's design system (see `docs/design-guidelines.md`).

### Stress Level Dual Coding

Stress levels always combine color + icon + text for WCAG AA compliance:

| Level | Color | Icon | Hex |
|-------|-------|------|-----|
| Relaxed | Green | `leaf.fill` | `#34C759` |
| Mild | Blue | `circle.fill` | `#007AFF` |
| Moderate | Yellow | `triangle.fill` | `#FFD60A` |
| High | Orange | `square.fill` | `#FF9500` |
| Severe | Red | `exclamationmark.octagon.fill` | `#FF3B30` |

### Key Requirements

- **Dynamic Type**: Use `.accessibleDynamicType()` modifier
- **Touch targets**: Minimum 44×44pt
- **Haptic feedback**: Use `HapticManager.shared`
- **SF Symbols**: Use the centralized `AppIconSystem` registry — never hardcode SF Symbol strings

---

## SwiftLint

The project uses SwiftLint with configuration in `.swiftlint.yml`:

- Line length: warning at 150, error at 250
- Type body length: warning at 400, error at 600
- Opt-in rules: `empty_count`, `closure_spacing`, `force_unwrapping`, `private_outlet`, and others

Run locally:

```bash
swiftlint lint --reporter github-actions-logging
```

CI runs SwiftLint automatically on every PR.

---

## Navigation

Navigation is centralized in `AppRouter` (`@Observable`), injected via `.environment()`. Each tab owns a `NavigationPath`. For programmatic navigation or deep links:

```swift
@Environment(AppRouter.self) private var router

// Push to a route in the current tab
router.homePath.append(Route.someDetail)

// Deep link — switch tab and push
router.deepLink(to: Route.breathing, in: .action)
```

Route state is serialized to `@SceneStorage` per tab for state restoration.

---

## Linting & Formatting

The project does not use a separate code formatter (e.g., SwiftFormat). Follow existing code style and run SwiftLint before committing.

---

## Adding a New Stress Factor

1. Create a new file in `Services/Algorithm/` implementing `StressFactor`:

```swift
struct MyStressFactor: StressFactor {
    let id = "myFactor"
    let weight: Double = 0.10

    func calculate(context: StressContext) async throws -> FactorResult? {
        // Compute normalized 0-1 stress score + confidence
        return FactorResult(value: score, confidence: conf, metadata: [:])
    }
}
```

2. Add the factor to `MultiFactorStressCalculator`.
3. Update `FactorWeights` defaults if needed.
4. Add a corresponding test file in `StressMonitorTests/`.

---

## Common Issues

### HealthKit Authorization Denied

Guide users to: **Settings → Privacy & Security → Health → StressMonitor**

### Background Tasks Not Running

- Verify Background Modes (App Refresh) is enabled in capabilities.
- Ensure the device is not in Low Power Mode.
- The system ultimately controls when `BGAppRefreshTask` fires.

### CloudKit Sync Errors

- Check iCloud account is signed in.
- Handle network errors gracefully — sync retries on next foreground.

---

## Related Docs

- [ARCHITECTURE.md](./ARCHITECTURE.md) — Full system design
- [CONFIGURATION.md](./CONFIGURATION.md) — Build and CI configuration
- [TESTING.md](./TESTING.md) — Testing guide
