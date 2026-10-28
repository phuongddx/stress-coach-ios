# Architecture

StressMonitor is a privacy-first iOS 18+ / watchOS 11+ stress monitoring app that computes a composite stress score from HealthKit biometric data, presents it through a character-driven SwiftUI UI, and optionally syncs across devices via CloudKit. The app ships as a single Xcode project with three targets: the iOS app, a watchOS companion/standalone app, and a Home Screen widget extension.

---

## High-Level Overview

```
SwiftUI Views → @Observable ViewModels → Protocol-based Services
     │                  │                        │
  Presentation     State Management        Business Logic
                                              │
                                    SwiftData + CloudKit (Data)
                                              │
                                    HealthKit + Sensors (Input)
```

The app follows MVVM with the `@Observable` macro (iOS 17+). Views are pure presentation; ViewModels own UI state and orchestrate service calls; services encapsulate all business logic behind protocols. There are no third-party state management libraries — everything is built on system frameworks (SwiftUI, SwiftData, HealthKit, CloudKit, StoreKit 2).

---

## Module Structure

### App Root

- `StressMonitor/StressMonitorApp.swift` — `@main` entry point. Owns the `AppRouter`, `PaywallController`, `StoreKitService` singleton, and the SwiftData `ModelContainer`. Seeds default character unlocks on first launch and self-corrects StoreKit entitlements on every scene-phase foreground.

### Navigation

- `Navigation/AppRouter.swift` — Central `@Observable` navigation state. Owns the selected tab and a `NavigationPath` per tab, enabling programmatic navigation, deep links, and cross-tab routing.
- `Navigation/Route.swift` — `Codable` route enum used by `NavigationStack` path bindings.
- `Navigation/View+NavigationDestinations.swift` — Maps `Route` cases to destination views.

### Models (`Models/`)

SwiftData `@Model` classes:

- `StressMeasurement.swift` — Core persistence model. Stores stress level, HRV, resting heart rate, per-factor component scores (HRV, HR, sleep, activity, recovery), confidence array, and CloudKit sync metadata (`isSynced`, `cloudKitRecordName`, `deviceID`, `cloudKitModTime`).
- `Habit.swift` — User habits (added in schema V2 migration).

Value/DTO models (Codable, Sendable):

- `StressResult.swift` — Computed stress result with `level` (0–100), `StressCategory`, `confidence`, and optional `FactorBreakdown`.
- `StressCategory.swift` — Five-level enum (`.relaxed`, `.mild`, `.moderate`, `.high`, `.severe`) with WCAG dual-coding: color + SF Symbol icon + pattern description.
- `FactorWeights.swift` — Per-user calibrated weights (`hrv: 0.40, heartRate: 0.15, sleep: 0.20, activity: 0.15, recovery: 0.10`).
- `StressContext.swift` — Input bundle passed to the multi-factor calculator.
- `FactorBreakdown.swift`, `HRVMeasurement.swift`, `HeartRateSample.swift`, `SleepData.swift`, `ActivityData.swift`, `RecoveryData.swift`, `PersonalBaseline.swift`, `BioAgeResult.swift`, `ChatMessage.swift`, `MoodEntry.swift`, `SubscriptionPlan.swift`, `WidgetSharedData.swift`

### Stress Algorithm (`Services/Algorithm/`)

The multi-factor stress engine. Each factor implements the `StressFactor` protocol and independently produces a normalized 0–1 stress score with a confidence rating:

```swift
protocol StressFactor: Sendable {
    var id: String { get }
    var weight: Double { get }
    func calculate(context: StressContext) async throws -> FactorResult?
}
```

- `MultiFactorStressCalculator.swift` — Primary calculator. Implements `StressAlgorithmServiceProtocol`. Gathers available factors, normalizes weights when factors are missing (graceful degradation), and produces a weighted composite score.
- `StressCalculator.swift` — Legacy 2-factor (HRV + heart rate) fallback calculator.
- Factor implementations: `HRVStressFactor.swift`, `HeartRateStressFactor.swift`, `SleepStressFactor.swift`, `ActivityStressFactor.swift`, `RecoveryStressFactor.swift`
- `BaselineCalculator.swift` — Computes personal baselines from historical data.
- `BioAgeCalculator.swift` — Biological age estimation.
- `FactorCalibrator.swift` — Adjusts `FactorWeights` based on accumulated data.

### Health Data (`Services/HealthKit/`)

- `HealthKitManager.swift` — Singleton with async methods for authorization, HRV fetch, heart rate fetch (with live `AsyncStream` updates), and HRV history.
- `HealthKitManager+SleepFetch.swift`, `HealthKitManager+ActivityFetch.swift`, `HealthKitManager+RecoveryFetch.swift` — Extension files for per-factor data fetching.
- `SimulatorHealthKitService.swift` — Debug simulator for HealthKit data unavailable in the simulator.

### Data Persistence (`Services/Repository/`)

- `StressRepository.swift` — Implements `StressRepositoryProtocol`. CRUD over SwiftData `StressMeasurement` records, batch save, date-range queries, unsynced record retrieval, baseline management, average HRV calculations, and pending sync flush.

### Cloud Sync (`Services/CloudKit/` + `Services/Sync/`)

- `CloudKitManager.swift` — CloudKit container management (container: `iCloud.stress.ai.com`).
- `CloudKitSchema.swift` — CloudKit record type definitions.
- `CloudKitSyncEngine.swift` — Push/pull sync orchestration.
- `Sync/SyncManager.swift` — Coordinates SwiftData ↔ CloudKit synchronization.
- `Sync/ConflictResolver.swift` — Resolves cross-device edit conflicts.

### LLM / AI Coaching (`Services/LLM/`)

- `SupabaseLLMService.swift` — Production LLM service. Streams chat completions from Supabase Edge Functions via SSE (Server-Sent Events). This is the sole LLM backend.
- `SSEParser.swift` — SSE stream parser.
- `SupabaseConfig.swift` — Centralized Supabase endpoint configuration (Edge Functions: `health`, `chat`, `sessions`, `preferences`, `credits`, `quick-actions`).
- `SupabaseAuthService.swift`, `SupabaseSession.swift`, `SupabaseSecrets.swift` — Auth and session management.
- `ChatContextBuilder.swift`, `ChatQuickActions.swift`, `StressContextPayload.swift` — Build the derived stress context sent to the LLM (score, category, confidence, trend, per-factor scores — never raw health data).
- `LLMServiceProtocol.swift` — Protocol abstraction for the LLM service.

### Monetization (`Services/StoreKit/`)

- `StoreKitService.swift` — Real StoreKit 2 implementation. Fetches App Store products and monitors `Transaction.updates` for the app's lifetime.
- `MockStoreKitService.swift` — Debug/test mock (used in DEBUG builds via the app's factory).
- `PremiumState.swift` — Shared observable entitlement state.
- `StoreKitProductCatalog.swift`, `StoreKitServiceProtocol.swift`, `StoreKitServiceEnvironment.swift` — Product definitions, protocol, and SwiftUI environment injection.

### Background Processing (`Services/Background/`)

- `HealthBackgroundScheduler.swift` — `BGAppRefreshTask` registration, scheduling, and stress refresh handling.
- `NotificationManager.swift` — Local notification scheduling for stress alerts.

### Device Connectivity (`Services/Connectivity/`)

- `PhoneConnectivityManager.swift` — Watch ↔ phone connectivity via `WatchConnectivity`.

### Data Management (`Services/DataManagement/`)

- `DataExporter.swift` — User data export.
- `DataDeleter.swift`, `DataDeleterService.swift`, `LocalDataWipeService.swift`, `CloudKitResetService.swift` — User-initiated deletion (local, CloudKit, full wipe).
- `DataManagementUtilities.swift` — Shared helpers.

### ViewModels (`ViewModels/`)

All use the `@Observable` macro:

- `StressViewModel.swift` — Main stress dashboard state.
- `ChatViewModel.swift` — AI coaching chat state.
- `CharacterCollectionViewModel.swift` — Character unlock/evolution state.
- `HabitViewModel.swift` — Habits state.
- `PremiumViewModel.swift` — Paywall and subscription state.

### Views (`Views/`)

Tab-based UI with four tabs (Home, Action, Trend, Settings):

- `Views/Dashboard/` — Home tab (stress score, character, readings).
- `Views/Action/` — Action tab (exercises, interventions).
- `Views/Trends/` — Trend tab (history, charts).
- `Views/Settings/` — Settings tab.
- `Views/Chat/`, `Views/Breathing/`, `Views/MiniWalk/`, `Views/Journal/`, `Views/Characters/`, `Views/Premium/`, `Views/Onboarding/`, `Views/History/`, `Views/Shared/`, `Views/DesignSystem/`, `Views/Components/`

### Theme & Design System (`Theme/`)

- `AppIconSystem.swift` — Centralized SF Symbol registry (single source of truth).
- `Color+Wellness.swift`, `Color+Extensions.swift` — Stress colors and color utilities.
- `DesignTokens.swift` — Spacing, corner radius, sizing tokens.
- `Gradients.swift` — Gradient definitions.
- `Font+WellnessType.swift` — Custom typography.
- `CharacterAssetCatalog.swift`, `HomeCharacterDesignTokens.swift` — Character SVG asset management.

### Utilities (`Utilities/`)

Accessibility-first helpers: `AccessibilityModifiers.swift`, `DynamicTypeScaling.swift`, `HighContrastModifier.swift`, `PatternOverlay.swift`, `ColorBlindnessSimulator.swift`, `AnimationPresets.swift`, `Animation+Wellness.swift`, `FontBlaster.swift`, `DocsURL.swift`.

### watchOS App (`StressMonitorWatch Watch App/`)

Standalone watch app with its own `Models/`, `Services/`, `ViewModels/`, `Views/`, `Theme/`, and `Complications/` directories. Includes its own `MultiFactorStressCalculator` and `StressAlgorithmServiceProtocol`. Uses list-based navigation.

### Widget Extension (`StressMonitorWidget/`)

- `StressMonitorWidgetBundle.swift` — Widget bundle entry point.
- `StressMonitorWidget.swift` — Home Screen widget.
- `StressMonitorWidgetControl.swift` — Control Center widget.
- `StressMonitorWidgetLiveActivity.swift` — Live Activity.
- `WidgetStressCharacter.swift` — Character rendering in widgets.
- `AppIntent.swift` — App Intents for interactive widgets.

---

## Key Architectural Patterns

### Protocol-Based Dependency Injection

All services are defined behind protocols (`HealthKitServiceProtocol`, `StressAlgorithmServiceProtocol`, `StressRepositoryProtocol`, `CloudKitServiceProtocol`, `StoreKitServiceProtocol`, `LLMServiceProtocol`). ViewModels and other consumers receive dependencies via constructor injection with sensible defaults, enabling testability and mock substitution.

### @Observable State Management

The app uses the `@Observable` macro throughout instead of `ObservableObject`/`@Published`. ViewModels are injected via SwiftUI environment or `@State`.

### Async/Await Throughout

All service methods use `async`/`await`. Views launch async work via `.task {}`. HealthKit heart rate updates are exposed as an `AsyncStream`.

### SwiftData with Versioned Migration

The app declares `AppSchemaV1` and `AppSchemaV2` (adds `Habit`) with a lightweight migration stage to prevent silent store resets on schema changes.

### Graceful Degradation

The multi-factor calculator normalizes remaining factor weights when data is missing, producing a composite score from whatever factors are available with adjusted confidence.

---

## Data Flow

1. **Input**: `HealthKitManager` fetches HRV, heart rate, sleep, activity, and recovery data from HealthKit.
2. **Calculation**: `MultiFactorStressCalculator` runs each `StressFactor`, normalizes weights, and produces a `StressResult` with a 0–100 score, `StressCategory`, confidence, and `FactorBreakdown`.
3. **Persistence**: `StressRepository` saves the result as a `StressMeasurement` (SwiftData).
4. **Sync**: `SyncManager` + `CloudKitSyncEngine` push unsynced records to CloudKit and pull remote changes, with `ConflictResolver` handling edit conflicts.
5. **Presentation**: `StressViewModel` exposes results to SwiftUI views; `DashboardView` renders the stress score, character, and readings.
6. **Coaching**: `ChatContextBuilder` derives a non-raw stress context payload (score, category, confidence, trend, per-factor scores) and sends it to `SupabaseLLMService`, which streams AI coaching responses via SSE.

---

## Concurrency Model

- All services are `@MainActor` or `Sendable` as appropriate.
- `HealthBackgroundScheduler` uses `BGAppRefreshTask` for system-managed background refresh.
- `StoreKitService` runs a `Transaction.updates` async sequence for the app's lifetime.
- `SupabaseLLMService` uses async/await with SSE streaming for chat responses.

---

## Bundle Identifiers

| Target | Bundle ID |
|--------|-----------|
| iOS App | `stress.ai.com` |
| watchOS App | `stress.ai.com.watchkitapp` |
| Widget Extension | `stress.ai.com.widget` |
| App Group | `group.stress.ai.com` |
| iCloud Container | `iCloud.stress.ai.com` |

---

## Error Handling

Services throw typed errors. ViewModels catch errors in `do/catch` blocks within `.task {}` or async methods and surface human-readable messages via `errorMessage` state. HealthKit authorization denials degrade gracefully — the app continues to function with available data, adjusting confidence scores accordingly.

---

## Privacy Boundaries

- All health data is stored locally via SwiftData (encrypted at rest).
- CloudKit sync is end-to-end encrypted and optional.
- HealthKit access is read-only.
- The only data transmitted off-device is the derived stress context payload (score, category, confidence, trend, per-factor scores) sent to Supabase Edge Functions for AI coaching — never raw HealthKit readings.
- No third-party analytics or tracking.
