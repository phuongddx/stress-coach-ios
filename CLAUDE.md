# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Build & Test Commands

Use the `xc-all` MCP tools for Xcode operations:

### Building

```swift
// MCP Tool: mcp__plugin_xclaude-plugin_xc-all__xcode_build
// Build iOS app (auto-detects destination)
mcp__plugin_xclaude-plugin_xc-all__xcode_build(scheme: "StressMonitor")

// Build with specific destination
mcp__plugin_xclaude-plugin_xc-all__xcode_build(
    scheme: "StressMonitor",
    destination: "platform=iOS Simulator,name=iPhone 15,OS=18.0"
)

// Build watchOS app
mcp__plugin_xclaude-plugin_xc-all__xcode_build(
    scheme: "StressMonitorWatch",
    destination: "platform=watchOS Simulator,name=Apple Watch Series 9"
)
```

### Testing

```swift
// MCP Tool: mcp__plugin_xclaude-plugin_xc-all__xcode_test
// Run all tests
mcp__plugin_xclaude-plugin_xc-all__xcode_test(
    scheme: "StressMonitor",
    destination: "platform=iOS Simulator,name=iPhone 15"
)

// Run single test class
mcp__plugin_xclaude-plugin_xc-all__xcode_test(
    scheme: "StressMonitor",
    destination: "platform=iOS Simulator,name=iPhone 15",
    only_testing: ["StressMonitorTests/StressCalculatorTests"]
)

// Run single test method
mcp__plugin_xclaude-plugin_xc-all__xcode_test(
    scheme: "StressMonitor",
    destination: "platform=iOS Simulator,name=iPhone 15",
    only_testing: ["StressMonitorTests/StressCalculatorTests/testNormalStress"]
)
```

### Cleaning Build Artifacts

```swift
// MCP Tool: mcp__plugin_xclaude-plugin_xc-all__xcode_clean
// Clean all
mcp__plugin_xclaude-plugin_xc-all__xcode_clean()

// Clean specific scheme
mcp__plugin_xclaude-plugin_xc-all__xcode_clean(scheme: "StressMonitor")
```

### Simulator Management

```swift
// MCP Tool: mcp__plugin_xclaude-plugin_xc-all__simulator_list
// List available simulators
mcp__plugin_xclaude-plugin_xc-all__simulator_list(
    device_type: "iPhone",
    availability: "available"
)

// MCP Tool: mcp__plugin_xclaude-plugin_xc-all__simulator_boot
// Boot a simulator
mcp__plugin_xclaude-plugin_xc-all__simulator_boot(device_id: "iPhone 15")

// MCP Tool: mcp__plugin_xclaude-plugin_xc-all__simulator_shutdown
// Shutdown simulator
mcp__plugin_xclaude-plugin_xc-all__simulator_shutdown(device_id: "booted")
```

### App Installation & Launch

```swift
// MCP Tool: mcp__plugin_xclaude-plugin_xc-all__simulator_install_app
// Install .app bundle
mcp__plugin_xclaude-plugin_xc-all__simulator_install_app(
    device_id: "booted",
    app_path: "/path/to/StressMonitor.app"
)

// MCP Tool: mcp__plugin_xclaude-plugin_xc-all__simulator_launch_app
// Launch app by bundle ID
mcp__plugin_xclaude-plugin_xc-all__simulator_launch_app(
    device_id: "booted",
    app_identifier: "com.stressmonitor.app"
)
```

### UI Interaction & Testing

```swift
// MCP Tool: mcp__plugin_xclaude-plugin_xc-all__idb_describe
// Query accessibility tree
mcp__plugin_xclaude-plugin_xc-all__idb_describe(operation: "all")

// MCP Tool: mcp__plugin_xclaude-plugin_xc-all__idb_find_element
// Find UI element by label
mcp__plugin_xclaude-plugin_xc-all__idb_find_element(query: "Stress Level")

// MCP Tool: mcp__plugin_xclaude-plugin_xc-all__idb_tap
// Tap at coordinates
mcp__plugin_xclaude-plugin_xc-all__idb_tap(x: 200, y: 400)

// MCP Tool: mcp__plugin_xclaude-plugin_xc-all__idb_input
// Type text or press keys
mcp__plugin_xclaude-plugin_xc-all__idb_input(text: "test input")
mcp__plugin_xclaude-plugin_xc-all__idb_input(key: "return")
```

### Screenshots

```swift
// MCP Tool: mcp__plugin_xclaude-plugin_xc-all__simulator_screenshot
// Capture screenshot (auto-generated path)
mcp__plugin_xclaude-plugin_xc-all__simulator_screenshot(device_id: "booted")

// With custom output path
mcp__plugin_xclaude-plugin_xc-all__simulator_screenshot(
    device_id: "booted",
    output_path: "/Users/ddphuong/Downloads/screenshot.png"
)
```

### Xcode Info

```swift
// MCP Tool: mcp__plugin_xclaude-plugin_xc-all__xcode_version
// Get Xcode version
mcp__plugin_xclaude-plugin_xc-all__xcode_version()

// Check specific SDK
mcp__plugin_xclaude-plugin_xc-all__xcode_version(sdk: "iphoneos")

// MCP Tool: mcp__plugin_xclaude-plugin_xc-all__xcode_list
// List schemes and targets
mcp__plugin_xclaude-plugin_xc-all__xcode_list()
```

### Environment Health Check

```swift
// MCP Tool: mcp__plugin_xclaude-plugin_xc-all__simulator_health_check
// Validate iOS dev environment
mcp__plugin_xclaude-plugin_xc-all__simulator_health_check()
```

---

### Demo Mode (Simulator Testing)

To test with simulated HealthKit data on simulator:

1. **Xcode** → Product → Scheme → Edit Scheme
2. **Run** → Arguments → Arguments Passed on Launch
3. Add `-demo-mode` (checkbox enabled)
4. Build and run on simulator

**What demo mode provides:**

| Feature | Behavior |
|---------|----------|
| 5-Factor Data | Dynamic HRV, HR, Sleep, Activity, Recovery cycling through all stress levels |
| Scenario Cycling | Relaxed → Mild → Moderate → High → Edge (30s each) |
| Live HR Updates | AsyncStream emits every 3-5 seconds |
| Historical Data | 7-14 days with circadian variation |
| Edge Cases | Low HRV (<20ms), extreme HR (100-115), missing factors, partial recovery |
| Real Pipeline | Uses actual `MultiFactorStressCalculator` + SwiftData (not static mocks) |
| Graceful Degradation | Edge scenario omits sleep/activity/recovery to test weight redistribution |

**Files:**
- `Services/HealthKit/SimulatorHealthKitService.swift` — dynamic data generator
- `Views/Components/DemoModeBannerView.swift` — "DEMO MODE" pill overlay
- `DemoMode.isEnabled` in `StressMonitorApp.swift` — launch argument check

---

## MCP Plugin Categories

- **xc-setup**: Simulator and environment setup (`simulator_boot`, `simulator_create`, `simulator_list`, `xcode_version`)
- **xc-build**: Build operations (`xcode_build`, `xcode_clean`, `xcode_list`)
- **xc-launch**: App lifecycle (`simulator_install_app`, `simulator_launch_app`)
- **xc-interact**: UI automation (`idb_tap`, `idb_input`, `idb_find_element`, `idb_gesture`)
- **xc-testing**: Test execution (`xcode_test`, `idb_describe`, `simulator_screenshot`)
- **xc-meta**: Management operations (`simulator_shutdown`, `simulator_delete`, `xcode_version`)

---

---

## Architecture Overview

**iOS 17+ / watchOS 10+ stress monitoring app** with MVVM + SwiftUI. Tracks stress via multi-factor biometric analysis from HealthKit, with a character/mascot gamification layer and AI chat.

### Tech Stack
- **Language**: Swift 5.9+, strict concurrency (`Sendable` throughout)
- **UI**: SwiftUI (no UIKit)
- **Persistence**: SwiftData (`StressMeasurement`, `CharacterUnlock`)
- **Health Data**: HealthKit (HRV, HR, Sleep, Activity, Recovery)
- **Cloud Sync**: CloudKit + custom `SyncManager`/`ConflictResolver`
- **AI Chat**: `StressLLMService` (via `StressAPIClient` → chat endpoint on `https://stress-api.dropitx.site`, SSE streaming, Firebase Auth), via `LLMServiceProtocol`
- **IAP**: StoreKit 2 — monthly/annual subscriptions via `StoreKitService` / `MockStoreKitService`
- **Watch**: Separate watchOS target with `WatchConnectivity` sync

### Data Flow

```
HealthKit → HealthKitManager ──┐
                               ├─→ StressContext → MultiFactorStressCalculator → StressResult
                               │         (HRV · HR · Sleep · Activity · Recovery)
                               └─→ StressViewModel → SwiftUI Views

SwiftData (StressMeasurement) ← StressRepository ← StressViewModel
CloudKit ↔ CloudKitSyncEngine ↔ SyncManager
LLMServiceProtocol → ChatViewModel → ChatBottomSheetView
CharacterUnlock (SwiftData) → CharacterCollectionViewModel → CharacterCollectionView
```

---

## Core Algorithm

Two implementations behind `StressAlgorithmServiceProtocol`:

**`MultiFactorStressCalculator`** (primary — uses `StressContext`):

| Factor | Protocol | Default Weight |
|--------|----------|---------------|
| HRVStressFactor | `StressFactor` | highest |
| HeartRateStressFactor | `StressFactor` | medium |
| SleepStressFactor | `StressFactor` | medium |
| ActivityStressFactor | `StressFactor` | low |
| RecoveryStressFactor | `StressFactor` | low |

Missing factors cause automatic weight redistribution. Call via `calculateMultiFactorStress(context:)`.

**`StressCalculator`** (legacy fallback — HRV 70% + HR 30%):
```
HRV Component = ((Baseline - HRV) / Baseline) ^ 0.8
HR Component  = atan((HR - Resting) / Resting * 2) / (π/2)
Stress Level  = (HRV × 0.7) + (HR × 0.3) × 100
```

**Stress Categories** (0-100): Relaxed (0-25) · Mild (25-50) · Moderate (50-75) · High (75-100)

**Note**: HealthKit provides SDNN-based HRV, not RMSSD. Baseline normalization compensates at the individual level.

See `documentation/references/phase-3-core-algorithm.md` for full details.

---

## Key Service Protocols

```swift
// Services/Protocols/StressAlgorithmServiceProtocol.swift
protocol StressAlgorithmServiceProtocol: Sendable {
    func calculateStress(hrv: Double, heartRate: Double) async throws -> StressResult
    func calculateConfidence(hrv: Double, heartRate: Double, samples: Int, lastReadingDate: Date?) -> Double
    func calculateMultiFactorStress(context: StressContext) async throws -> StressResult
}

// Services/Protocols/HealthKitServiceProtocol.swift
protocol HealthKitServiceProtocol {
    func requestAuthorization() async throws
    func fetchLatestHRV() async throws -> HRVMeasurement?
    func fetchHeartRate(samples: Int) async throws -> [HeartRateSample]
}

// Services/Protocols/StressRepositoryProtocol.swift
protocol StressRepositoryProtocol {
    func save(_ measurement: StressMeasurement) async throws
    func fetchRecent(limit: Int) async throws -> [StressMeasurement]
    func getBaseline() async throws -> PersonalBaseline
}

// Services/LLM/LLMServiceProtocol.swift
protocol LLMServiceProtocol: Sendable {
    func isAvailable() -> Bool
    func send(messages: [ChatMessage], systemPrompt: String) async throws -> AsyncThrowingStream<String, Error>
}

// Services/StoreKit/StoreKitServiceProtocol.swift
protocol StoreKitServiceProtocol {
    var availablePlans: [SubscriptionPlan] { get async }
    var isPremiumUser: Bool { get async }
    func purchase(_ plan: SubscriptionPlan) async throws
    func restorePurchases() async throws
}
```

---

## Project Structure

```
StressMonitor/
├── StressMonitor/          ← iPhone app target
│   ├── StressMonitorApp.swift   (entry point — seeds CharacterUnlock, sets up ModelContainer)
│   ├── Models/             (StressMeasurement @Model, CharacterUnlock @Model, CharacterCreature)
│   ├── ViewModels/         (StressViewModel, TrendViewModel, ChatViewModel, PremiumViewModel,
│   │                        CharacterCollectionViewModel)
│   ├── Views/              (Dashboard, History/Trends, Settings, Chat, Characters,
│   │                        Breathing, MiniWalk, Onboarding, Premium, DesignSystem)
│   ├── Services/
│   │   ├── Algorithm/      (MultiFactorStressCalculator, StressCalculator, 5 StressFactor impls)
│   │   ├── HealthKit/      (HealthKitManager + extensions for Activity/Recovery/Sleep fetch)
│   │   ├── LLM/            (StressLLMService, ChatContextBuilder)
│   │   ├── StoreKit/       (StoreKitService, MockStoreKitService, StoreKitProductCatalog)
│   │   ├── CloudKit/       (CloudKitManager, CloudKitSyncEngine, CloudKitSchema)
│   │   ├── Sync/           (SyncManager, ConflictResolver)
│   │   ├── Background/     (HealthBackgroundScheduler, NotificationManager)
│   │   ├── DataManagement/ (DataExporter CSV/JSON, DataDeleter, LocalDataWipeService)
│   │   ├── Repository/     (StressRepository)
│   │   └── Protocols/      (all service protocols)
│   └── Theme/              (DesignTokens, Color+Extensions, Font+WellnessType, Gradients)
├── StressMonitorWatch Watch App/  ← watchOS target (mirrors iPhone service structure)
├── StressMonitorWidget/           ← WidgetKit target (Smart Stack, Live Activities)
└── StressMonitorTests/            (CharacterAssetResolverTests, StoreKitProductCatalogTests,
                                    PremiumViewModelTests, CharacterCollectionViewModelTests)
```

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
Use `@Observable` macro (iOS 17+) for ViewModels:
```swift
@Observable
class StressViewModel {
    var currentStress: StressResult?
    var isLoading = false
    var errorMessage: String?
}
```

### Dependency Injection
Protocol-based with constructor injection:
```swift
class StressViewModel {
    private let healthKit: HealthKitServiceProtocol
    private let algorithm: StressAlgorithmServiceProtocol

    init(healthKit: HealthKitServiceProtocol = DefaultHealthKitService(),
         algorithm: StressAlgorithmServiceProtocol = StressCalculator()) {
        self.healthKit = healthKit
        self.algorithm = algorithm
    }
}
```

### Async/Await
Prefer `async`/`await` over callbacks. Use `.task {}` for async work in views:
```swift
func fetchAndCalculate() async {
    isLoading = true
    defer { isLoading = false }

    do {
        async let hrv = healthKit.fetchLatestHRV()
        async let hr = healthKit.fetchHeartRate(samples: 10)
        let (hrvData, hrData) = try await (hrv, hr)
        currentStress = try await algorithm.calculateStress(hrv: hrvData.value, heartRate: hrData.first?.value ?? 0)
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

### SwiftData Models
Use `@Model` macro:
```swift
@Model
final class StressMeasurement {
    var timestamp: Date
    var stressLevel: Double
    var hrv: Double

    init(timestamp: Date, stressLevel: Double, hrv: Double) {
        self.timestamp = timestamp
        self.stressLevel = stressLevel
        self.hrv = hrv
    }
}
```

### Testing
- Use `XCTAssertEqual` with `accuracy` for floating point
- Name tests: `test[Condition]` or `test[Method]_[Condition]`

```swift
func testNormalStress() async throws {
    let result = try await calculator.calculateStress(hrv: 50, heartRate: 60)
    XCTAssertEqual(result.level, 0, accuracy: 10)
    XCTAssertEqual(result.category, .relaxed)
}
```

---

## UI/UX Design System

**All UI work must follow** `documentation/references/ui-ux-design-system.md`

### Key Requirements
- **Dual coding for stress levels**: Always combine color with icons/text (WCAG compliance)
- **Dynamic Type**: Use `.accessibleDynamicType()` modifier
- **Touch targets**: Minimum 44x44pt
- **Haptic feedback**: Use `HapticManager.shared.stressLevelChanged(to:)`

### Stress Colors
```swift
Color.stressColor(for: .relaxed)      // Green #34C759
Color.stressColor(for: .mild)         // Blue #007AFF
Color.stressColor(for: .moderate)      // Yellow #FFD60A
Color.stressColor(for: .high)          // Orange #FF9500
```

---

## Global Rules

- Please do not create git commit if I not required
- Keep rules under 500 lines, split large rules into multiple composable rules
- **NEVER** include Claude credentials or attribution in commit messages
- Do not add "🤖 Generated with [Claude Code](https://claude.ai/code)"
- Do not add "Co-Authored-By: Claude <noreply@anthropic.com>"
- **ALWAYS** use `Phuong Doan` as the author name in commit metadata

---

## Implementation Phases

Follow `documentation/references/README.md` for phased implementation:

1. **Project Foundation** - Project setup, protocols
2. **Data Layer** - SwiftData models, repository
3. **Core Algorithm** - Stress calculation, confidence scoring
4. **iPhone UI** - Dashboard, trends, settings
5. **watchOS App** - Watch app, complications (WidgetKit, not ClockKit)
6. **Background Notifications** - BGAppRefreshTask, alerts
7. **Data Sync** - CloudKit integration
8. **Testing & Polish** - Unit tests, accessibility, performance

---

## Key Technical Decisions

| Area | Decision | Rationale |
|------|----------|-----------|
| Architecture | MVVM with @Observable | Clean state management, testable |
| Persistence | SwiftData | iOS 17+ native, SwiftUI-friendly |
| Cloud Sync | CloudKit + SyncManager/ConflictResolver | End-to-end encrypted, custom merge logic |
| watchOS Complications | WidgetKit (NOT ClockKit) | Required for watchOS 10+ |
| Background Tasks | BGAppRefreshTask | System-managed, battery-efficient |
| Dependencies | None (system only) | Privacy-first, no bloat |
| AI Chat | StressLLMService (via StressAPIClient → https://stress-api.dropitx.site, SSE streaming, Firebase Auth) | On-device privacy when available |
| IAP | StoreKit 2 — monthly + annual plans | StoreKitProductCatalog resolves IDs from Info.plist/env |
| Gamification | 5 character creatures with evolution (SwiftData CharacterUnlock) | Engagement via stress-driven character evolution |
| Algorithm | MultiFactorStressCalculator (5 factors) with StressCalculator fallback (HRV+HR) | Graceful degradation when sensors missing |

---

## Privacy & Security

- All health data stored locally via SwiftData (encrypted at rest)
- CloudKit sync is end-to-end encrypted
- HealthKit is read-only access (no writes)
- No third-party analytics or tracking (privacy manifest declares `NSPrivacyTracking` false; the DeviceID/ProductInteraction collected-data entries exist solely because of the Google/Firebase auth SDKs)
- AI Coaching Chat sends derived stress-context (stress score/category, confidence, trend, and per-factor HRV/heart-rate/sleep/activity/recovery scores — never raw HealthKit readings) to the `chat` endpoint on `https://stress-api.dropitx.site` (via `StressAPIClient`) under a Bearer-authenticated Firebase session (anonymous sign-in or Google Sign-In)

---

## Common Issues

### HealthKit Authorization Denied
Guide user to: Settings → Privacy & Security → Health → StressMonitor

### CloudKit Sync Errors
Check iCloud account status, handle network errors gracefully

### Background Tasks Not Running
Ensure Background Modes enabled in capabilities, verify device not in Low Power Mode

---

## References

- **Implementation Phases**: `documentation/references/README.md`
- **UI/UX Design System**: `documentation/references/ui-ux-design-system.md`
- **Algorithm Details**: `documentation/references/phase-3-core-algorithm.md`
- **Docs folder**: `./docs/` (project-overview-pdr, code-standards, codebase-summary, system-architecture)
- **Apple HIG**: https://developer.apple.com/design/human-interface-guidelines/
- **HealthKit**: https://developer.apple.com/documentation/healthkit
- **StoreKit 2**: https://developer.apple.com/documentation/storekit

# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
