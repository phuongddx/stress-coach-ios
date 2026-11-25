# Configuration

## Info.plist

The iOS app's Info.plist is at `StressMonitor/StressMonitor/Info.plist`; most privacy strings are generated from `INFOPLIST_KEY_*` build settings in `project.pbxproj`. Notable keys:

| Key | Value | Purpose |
| --- | --- | --- |
| `CFBundleDisplayName` | StressMonitor | Home screen name |
| `CFBundleShortVersionString` | `$(MARKETING_VERSION)` | Release version (set in Xcode) |
| `CFBundleVersion` | `$(CURRENT_PROJECT_VERSION)` | Build number |
| `UIAppFonts` | Lato-Regular, Lato-Medium, Lato-Bold, Lato-Black | Custom fonts loaded by `FontBlaster` |
| `NSHealthShareUsageDescription` | "We need access to your health data to monitor stress levels." | HealthKit read permission string |
| `UIBackgroundModes` | fetch, processing | Background app refresh and processing |
| `NSAppTransportSecurity.NSAllowsLocalNetworking` | true | Allows local networking for development |

StoreKit and Supabase configuration keys are resolved at runtime through `StoreKitProductCatalog` and `SupabaseConfig` (see below), not declared statically in Info.plist. They are injected through Xcode build settings (`STOREKIT_PREMIUM_*_PRODUCT_ID`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_GUEST_JWT`) which Xcode writes into Info.plist at build time.

## Entitlements

The iOS app entitlements file at `StressMonitor/StressMonitor/StressMonitor.entitlements` enables:

- `com.apple.developer.healthkit`: true (read-only access, no share types requested).

Additional capabilities configured in Xcode Signing & Capabilities (not all appear in the entitlements file directly):

- iCloud (CloudKit, private database).
- App Groups (for widget/watch data sharing).
- Background Modes (fetch, processing).

## App Group

The App Group container is the shared storage between the iOS app, the widget extension, and (transitively) the watch app. The iPhone app writes a `WidgetSharedData` snapshot to the App Group after each measurement. `WidgetDataProvider` in the widget extension reads from the same container.

## Secrets resolution

`SupabaseConfig` and `StoreKitProductCatalog` resolve configuration values in the same priority order:

1. **Info.plist key** (set via Xcode build settings).
2. **Process environment variable** (for tests and CI).
3. **UserDefaults key** (for local QA overrides).
4. **Hardcoded fallback** (only for the project URL and display-only plan prices; secrets fall back to a masked placeholder).

Unresolved Xcode build-setting placeholders like `$(STOREKIT_PREMIUM_MONTHLY_PRODUCT_ID)` are treated as `nil`.

| Configuration | Info.plist key | Env var | UserDefaults key |
| --- | --- | --- | --- |
| Supabase URL | `SUPABASE_URL` | `SUPABASE_URL` | `supabaseURL` |
| Supabase anon key | `SUPABASE_ANON_KEY` | `SUPABASE_ANON_KEY` | `supabaseAnonKey` |
| Supabase guest JWT | `SUPABASE_GUEST_JWT` | `SUPABASE_GUEST_JWT` | `supabaseGuestJWT` |
| StoreKit weekly product ID | `STOREKIT_PREMIUM_WEEKLY_PRODUCT_ID` | same | `storeKitPremiumWeeklyProductID` |
| StoreKit monthly product ID | `STOREKIT_PREMIUM_MONTHLY_PRODUCT_ID` | same | `storeKitPremiumMonthlyProductID` |
| StoreKit annual product ID | `STOREKIT_PREMIUM_ANNUAL_PRODUCT_ID` | same | `storeKitPremiumAnnualProductID` |
| StoreKit subscription group ID | `STOREKIT_PREMIUM_SUBSCRIPTION_GROUP_ID` | same | `storeKitPremiumSubscriptionGroupID` |

## UserDefaults keys

| Key | Owner | Purpose |
| --- | --- | --- |
| `com.stressmonitor.personalBaseline` | `StressRepository` | Encoded `PersonalBaseline` |
| `com.stressmonitor.deviceID` | `CloudKitDeviceID` / `CloudKitManager` | Per-device UUID |
| `com.stressmonitor.subscription` | `CloudKitManager` | CloudKit subscription ID |
| `supabaseChatSessionId` | `SupabaseLLMService` | Active chat session UUID |
| `storeKitPremium*ProductID` | `StoreKitProductCatalog` | Optional product ID overrides |

## Build settings

Set in Xcode for each target. The most important:

- `MARKETING_VERSION`: the user-facing version string.
- `CURRENT_PROJECT_VERSION`: the build number.
- `DEVELOPMENT_TEAM`: the Apple Developer team used for signing.
- `CODE_SIGN_STYLE`: Xcode-managed (Automatic) or manual.
- Bundle identifiers per target (see [Deployment](../deployment.md)).
