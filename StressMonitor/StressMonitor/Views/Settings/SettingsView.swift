import SwiftUI
import SwiftData
import HealthKit
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(PaywallController.self) private var paywall
    @Environment(CreditService.self) private var creditService
    @Environment(PreferencesService.self) private var preferencesService
    @State private var viewModel: SettingsViewModel
    @State private var habitViewModel: HabitViewModel?
    @State private var accountViewModel = AccountViewModel()
    @State private var docsURL: URL? = nil
    @State private var showChatSheet = false
    @State private var showManageSubscriptions = false
    @State private var showSignInErrorAlert = false
    @State private var showDeleteAccountConfirm = false
    @State private var showAccountDeletedAlert = false

    @Query(filter: #Predicate<CharacterUnlock> { $0.isActive })
    private var activeUnlocks: [CharacterUnlock]

    @Query(filter: #Predicate<CharacterUnlock> { $0.isUnlocked })
    private var unlockedCharacters: [CharacterUnlock]

    init() {
        _viewModel = State(initialValue: SettingsViewModel(
            modelContext: ModelContext((try? ModelContainer(for: StressMeasurement.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))!)
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 12) {
                    meHeroSection
                    companionBannerSection
                }
                plusSection
                healthDevicesSection
                accountSection
                coachSection
                notificationsSection
                habitsSection
                preferencesSection
                dataSupportSection
                versionFooter
            }
            .padding(.horizontal, V2Metrics.margin)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.V2.bg.ignoresSafeArea())
        .accessibleDynamicType()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Delete your account?", isPresented: $showDeleteAccountConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Account", role: .destructive) {
                Task {
                    if await accountViewModel.deleteAccount() {
                        showAccountDeletedAlert = true
                    } else {
                        showSignInErrorAlert = accountViewModel.errorMessage != nil
                    }
                }
            }
        } message: {
            Text("This permanently deletes your account and its data. This cannot be undone.")
        }
        .alert("Account deleted", isPresented: $showAccountDeletedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your account and its data have been deleted.")
        }
        .onAppear {
            viewModel = SettingsViewModel(modelContext: modelContext)
            if habitViewModel == nil {
                habitViewModel = HabitViewModel(modelContext: modelContext)
            } else {
                habitViewModel?.loadToday()
            }
            Task { await viewModel.loadUserProfile() }
            accountViewModel.refreshAccountState()
            Task { try? await creditService.refreshBalance() }
            Task { await preferencesService.seedIfNeeded() }
            refreshHealthAuthStatus()
        }
        .sheet(item: $docsURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .sheet(isPresented: $showChatSheet) {
            ChatBottomSheetView(
                stressResult: viewModel.chatStressResult,
                baseline: viewModel.chatBaseline,
                recentHistory: viewModel.chatHistory
            )
        }
        // Explanation + grant sheet for the first "Health Data Sync" enable.
        // Allow performs the PUT inside the sheet; Not Now reverts the
        // optimistic toggle without touching the server.
        .sheet(isPresented: $showHealthConsentSheet, onDismiss: {
            // Swipe-to-dismiss skips `onDecision` entirely, so the
            // optimistic flip must revert unless the grant actually landed.
            if !hasGrantedHealthConsent { healthSyncOptedIn = false }
        }) {
            HealthConsentView { granted in
                if granted {
                    // Allow persisted the grant inside the sheet; align the
                    // toggle's session state so it doesn't read stale-OFF
                    // after a revoke-then-re-enable round trip.
                    hasGrantedHealthConsent = true
                    healthSyncOptedIn = true
                } else {
                    // Not Now: no server call, no side effects — revert the
                    // optimistic flip.
                    healthSyncOptedIn = false
                }
            }
        }
        .alert("Health Access Needed", isPresented: $showPermissionDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Ripple needs Health access to read your stress data. Please enable it in Settings → Privacy → Health.")
        }
        .alert("Sign-In Failed", isPresented: $showSignInErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(accountViewModel.errorMessage ?? "Google Sign-In could not be completed.")
        }
    }

    // MARK: - 1. Me-hero

    /// Nil while purchases are postponed so `MeHeroCard` drops the PLUS pill.
    private var plusTapHandler: (() -> Void)? {
        guard PurchaseAvailability.isEnabled else { return nil }
        return plusTapped
    }

    /// Plus members manage their subscription with Apple; everyone else
    /// gets the paywall.
    private func plusTapped() {
        if PremiumState.shared.isPremiumUser {
            showManageSubscriptions = true
        } else {
            paywall.present(reason: .general)
        }
    }

    private var meHeroSection: some View {
        MeHeroCard(
            bioAge: viewModel.bioAge,
            stressLevel: viewModel.latestStressLevel,
            streakDays: viewModel.streakDays,
            displayName: viewModel.displayName,
            email: viewModel.displayEmail ?? accountViewModel.linkedEmail,
            onPlusTap: plusTapHandler
        )
    }

    // MARK: - 2. Active companion banner

    private var companionBannerSection: some View {
        CompanionBanner(
            companionName: activeCreature.displayName,
            companionSubtitle: activeCreature.element.rawValue.capitalized,
            mood: RippleMood.from(stressLevel: viewModel.latestStressLevel ?? 0),
            onSwitch: { router.settingsPath.append(Route.characters) }
        )
    }

    // MARK: - 3. Plus

    /// Same row, same logic as before: shown only while purchases are on;
    /// Plus members open Apple's manage-subscription sheet, everyone else
    /// the paywall (`plusTapped`).
    @ViewBuilder
    private var plusSection: some View {
        if PurchaseAvailability.isEnabled {
            let isPremium = PremiumState.shared.isPremiumUser
            group("Plus") {
                navRow(
                    icon: AppIconSystem.Setting.stressMonitorPlus.sfSymbol,
                    setting: .stressMonitorPlus,
                    tint: Color.V2.plusBg,
                    glyph: Color.V2.plus,
                    title: isPremium ? "Manage subscription" : "StressMonitor Plus",
                    value: isPremium
                        ? "Active"
                        : CreditBalanceFormatter.plusRowValue(creditService.balance),
                    valueTint: Color.V2.plus,
                    action: plusTapped
                )
            }
        }
    }

    // MARK: - 4. Health & devices

    private var healthDevicesSection: some View {
        group("Health & devices", footer: healthSyncError, footerIsError: true) {
            navRow(
                icon: AppIconSystem.Setting.appleHealth.sfSymbol,
                setting: .appleHealth,
                tint: StressCategory.high.fillColor,
                glyph: StressCategory.high.onFillColor,
                title: "Apple Health",
                value: healthStatusText,
                action: healthAuthStatus == .sharingAuthorized ? nil : { requestHealthPermission() }
            )
            ActionRowDivider()
            toggleRow(
                icon: "checkmark.shield.fill",
                tint: StressCategory.relaxed.fillColor,
                glyph: StressCategory.relaxed.onFillColor,
                title: "Health Data Sync",
                isOn: healthSyncToggleBinding
            )
            ActionRowDivider()
            navRow(
                icon: AppIconSystem.Setting.appleWatch.sfSymbol,
                setting: .appleWatch,
                tint: Color.V2.ink2,
                glyph: Color.V2.surface,
                title: "Apple Watch",
                value: watchStatusText,
                destination: .watchFace
            )
            ActionRowDivider()
            navRow(
                icon: AppIconSystem.Setting.biologicalAge.sfSymbol,
                setting: .biologicalAge,
                tint: Color.V2.Companion.lumi,
                glyph: Color.V2.onAccent,
                title: "Biological Age",
                value: bioAgeText,
                destination: .bioAge
            )
        }
    }

    // MARK: - 5. Account

    private var accountSection: some View {
        group("Account") {
            navRow(
                icon: "apple.logo",
                tint: Color.V2.ink,
                glyph: Color.V2.surface,
                title: "Sign in with Apple",
                value: accountViewModel.linkedEmail ?? "Link account",
                action: signInWithAppleTapped
            )
            ActionRowDivider()
            navRow(
                icon: "g.circle",
                tint: Color.V2.surface3,
                glyph: Color.V2.ink,
                title: "Sign in with Google",
                value: accountViewModel.linkedEmail ?? "Link account",
                action: signInWithGoogleTapped
            )
            ActionRowDivider()
            navRow(
                icon: "person.crop.circle.badge.xmark",
                tint: Color.V2.dangerSoft,
                glyph: Color.V2.danger,
                title: "Delete Account",
                titleColor: Color.V2.danger,
                value: accountViewModel.isDeletingAccount ? "Deleting…" : nil,
                valueTint: Color.V2.danger,
                action: { showDeleteAccountConfirm = true }
            )
        }
    }

    // MARK: - 6. Coach (Ripple Coach, Health Coach, AI Coach preferences)

    /// Language + coaching-style pickers riding `PreferencesService`. The
    /// closed option sets mirror the backend's accepted vocabulary; a current
    /// value outside the set still displays (the row text comes from state,
    /// not the option list). A failed PUT reverts inside the service — the
    /// footnote under the card is the user-facing signal.
    private var coachSection: some View {
        group("Coach", footer: preferencesService.errorMessage, footerIsError: true) {
            navRow(
                icon: AppIconSystem.Setting.rippleCoach.sfSymbol,
                setting: .rippleCoach,
                tint: Color.V2.Companion.ripple,
                glyph: Color.V2.onAccent,
                title: "Ripple Coach",
                value: CreditBalanceFormatter.chatRowValue(
                    available: ChatAvailability.current.isAvailable,
                    balance: creditService.balance
                ),
                action: {
                    guard ChatAvailability.current.isAvailable else { return }
                    showChatSheet = true
                }
            )
            if FeatureFlags.agentChatEnabled {
                ActionRowDivider()
                navRow(
                    icon: AppIconSystem.Setting.rippleCoach.sfSymbol,
                    setting: .rippleCoach,
                    tint: Color.V2.Companion.zephyr,
                    glyph: Color.V2.onAccent,
                    title: "Health Coach",
                    value: "New",
                    destination: .agentChat
                )
            }
            ActionRowDivider()
            aiCoachPickerRow(
                icon: "globe",
                tint: Color.V2.accentSoft,
                glyph: Color.V2.accent,
                title: "Language",
                currentValue: preferencesService.language,
                options: [("en", "English"), ("vi", "Tiếng Việt")],
                pickerLabel: "AI Coach language"
            ) { newValue in
                Task { await preferencesService.update(language: newValue) }
            }
            ActionRowDivider()
            aiCoachPickerRow(
                icon: "text.bubble.fill",
                tint: Color.V2.accentSoft,
                glyph: Color.V2.accent,
                title: "Coaching Style",
                currentValue: preferencesService.coachingStyle,
                options: [
                    ("supportive", "Supportive"),
                    ("direct", "Direct"),
                    ("educational", "Educational")
                ],
                pickerLabel: "AI Coach coaching style"
            ) { newValue in
                Task { await preferencesService.update(coachingStyle: newValue) }
            }
        }
    }

    private func aiCoachPickerRow(
        icon: String,
        tint: Color,
        glyph: Color,
        title: String,
        currentValue: String,
        options: [(raw: String, label: String)],
        pickerLabel: String,
        onChange: @escaping (String) -> Void
    ) -> some View {
        SettingsRowLabel(
            icon: icon,
            tint: tint,
            glyph: glyph,
            title: title,
            value: options.contains(where: { $0.raw == currentValue }) ? nil : currentValue.capitalized
        ) {
            Picker(title, selection: Binding(
                get: { currentValue },
                set: { onChange($0) }
            )) {
                ForEach(options, id: \.raw) { option in
                    Text(option.label).tag(option.raw)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(Color.V2.ink2)
            .frame(minHeight: V2Metrics.minTouchTarget)
            .accessibilityLabel(pickerLabel)
        }
    }

    // MARK: - 7. Notifications

    private var notificationsSection: some View {
        group("Notifications") {
            toggleRow(
                icon: AppIconSystem.Setting.stressAlerts.sfSymbol,
                setting: .stressAlerts,
                tint: StressCategory.moderate.fillColor,
                glyph: StressCategory.moderate.onFillColor,
                title: "Stress alerts",
                isOn: $viewModel.notificationSettings.stressAlertsEnabled
            )
            ActionRowDivider()
            toggleRow(
                icon: AppIconSystem.Setting.waterReminder.sfSymbol,
                setting: .waterReminder,
                tint: Color.V2.Companion.ripple,
                glyph: Color.V2.onAccent,
                title: "Water reminder",
                isOn: $viewModel.notificationSettings.waterReminderEnabled
            )
            ActionRowDivider()
            toggleRow(
                icon: AppIconSystem.Setting.dailySummary.sfSymbol,
                setting: .dailySummary,
                tint: StressCategory.mild.fillColor,
                glyph: StressCategory.mild.onFillColor,
                title: "Daily summary",
                isOn: $viewModel.notificationSettings.dailySummaryEnabled
            )
        }
        .onChange(of: viewModel.notificationSettings.stressAlertsEnabled) { _, _ in viewModel.notificationSettings.persist() }
        .onChange(of: viewModel.notificationSettings.waterReminderEnabled) { _, _ in viewModel.notificationSettings.persist() }
        .onChange(of: viewModel.notificationSettings.dailySummaryEnabled) { _, _ in viewModel.notificationSettings.persist() }
    }

    // MARK: - 8. Habits & tracking

    private var habitsSection: some View {
        group("Habits & tracking") {
            if let habitVM = habitViewModel {
                ForEach(Array(HabitType.allCases.enumerated()), id: \.element.id) { index, type in
                    if let habit = habitVM.habit(for: type) {
                        if index > 0 { ActionRowDivider() }
                        HabitLogRow(habit: habit) {
                            habitVM.logManual(type)
                        }
                    }
                }
            } else {
                ForEach(Array(HabitType.allCases.enumerated()), id: \.element.id) { index, type in
                    if index > 0 { ActionRowDivider() }
                    HabitLogRow(habit: Habit(type: type))
                }
            }
        }
    }

    // MARK: - 9. Preferences

    private var preferencesSection: some View {
        group("Preferences") {
            navRow(
                icon: AppIconSystem.Setting.appearance.sfSymbol,
                setting: .appearance,
                tint: Color.V2.ink2,
                glyph: Color.V2.surface,
                title: "Appearance",
                value: appearanceLabel,
                destination: .appearance
            )
            ActionRowDivider()
            navRow(
                icon: AppIconSystem.Setting.characters.sfSymbol,
                setting: .characters,
                tint: Color.V2.Companion.blossom,
                glyph: Color.V2.onAccent,
                title: "Characters",
                value: "\(unlockedCharacters.count) of \(CharacterCreature.offeredCharacters.count)",
                destination: .characters
            )
            ActionRowDivider()
            toggleRow(
                icon: AppIconSystem.Setting.haptics.sfSymbol,
                setting: .haptics,
                tint: Color.V2.Companion.ember,
                glyph: Color.V2.onAccent,
                title: "Haptics",
                isOn: hapticsEnabled
            )
            ActionRowDivider()
            navRow(
                icon: "rectangle.3.group.fill",
                tint: Color.V2.accent,
                glyph: Color.V2.onAccent,
                title: "Home screen widgets",
                value: "3 sizes",
                destination: .about
            )
        }
    }

    // MARK: - 10. Data & support

    private var dataSupportSection: some View {
        group("Data & support") {
            navRow(
                icon: AppIconSystem.Setting.exportData.sfSymbol,
                setting: .exportData,
                tint: StressCategory.relaxed.fillColor,
                glyph: StressCategory.relaxed.onFillColor,
                title: "Export data",
                destination: .dataExport
            )
            ActionRowDivider()
            navRow(
                icon: AppIconSystem.Setting.manageData.sfSymbol,
                setting: .manageData,
                tint: Color.V2.surface3,
                glyph: Color.V2.ink2,
                title: "Manage data",
                destination: .dataManage
            )
            ActionRowDivider()
            navRow(
                icon: "books.vertical",
                tint: StressCategory.mild.fillColor,
                glyph: StressCategory.mild.onFillColor,
                title: "Science & sources",
                destination: .scienceSources(topic: nil)
            )
            ActionRowDivider()
            navRow(
                icon: AppIconSystem.Setting.helpPrivacy.sfSymbol,
                setting: .helpPrivacy,
                tint: Color.V2.surface3,
                glyph: Color.V2.ink2,
                title: "Help & privacy",
                destination: .about
            )
        }
    }

    private var versionFooter: some View {
        VStack(spacing: 2) {
            Text("Version \(versionText) · Build \(buildText)")
                .monospacedDigit()
            Text("Wellness app, not a medical device.")
        }
        .font(.footnote)
        .foregroundStyle(Color.V2.ink3)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func signInWithAppleTapped() {
        guard accountViewModel.linkedEmail == nil else { return }
        // ASAuthorizationController needs a UIKit presentation anchor.
        guard let viewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })?
            .keyWindow?
            .rootViewController
        else {
            accountViewModel.errorMessage = "Sign in with Apple is unavailable right now."
            showSignInErrorAlert = true
            return
        }

        Task {
            do {
                try await accountViewModel.signInWithApple(presenting: viewController)
            } catch {
                if accountViewModel.errorMessage != nil {
                    showSignInErrorAlert = true
                }
            }
        }
    }

    private func signInWithGoogleTapped() {
        guard accountViewModel.linkedEmail == nil else { return }
        // GIDSignIn requires a UIKit presenter, which pure SwiftUI does not expose.
        guard let viewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })?
            .keyWindow?
            .rootViewController
        else {
            accountViewModel.errorMessage = "Google Sign-In is unavailable right now."
            showSignInErrorAlert = true
            return
        }

        Task {
            do {
                try await accountViewModel.signInWithGoogle(presenting: viewController)
            } catch {
                if accountViewModel.errorMessage != nil {
                    showSignInErrorAlert = true
                }
            }
        }
    }

    // MARK: - Health data sync actions

    /// Reads ON unless the server explicitly refused (the 403
    /// CONSENT_REQUIRED path flipped `needsConsent`); writes route through
    /// `handleHealthSyncToggle` — a service-side change just re-renders.
    private var healthSyncToggleBinding: Binding<Bool> {
        Binding(
            get: { healthSyncOptedIn && !healthSync.needsConsent },
            set: { handleHealthSyncToggle($0) }
        )
    }

    /// Enable: the first enable this session opens the explanation sheet
    /// (its Allow performs the grant); later enables PUT consent directly.
    /// Disable always revokes (`granted: false`). A failed PUT reverts the
    /// optimistic flip and surfaces the footnote — the AI Coach pattern.
    private func handleHealthSyncToggle(_ enabled: Bool) {
        if enabled {
            if hasGrantedHealthConsent {
                setHealthSyncConsent(true)
            } else {
                showHealthConsentSheet = true
            }
        } else {
            setHealthSyncConsent(false)
        }
    }

    private func setHealthSyncConsent(_ granted: Bool) {
        Task { @MainActor in
            do {
                try await StressAPIClient().setHealthConsent(granted)
                // Success: the toggle lands on the server-confirmed value —
                // including revoke (granted=false → OFF), which previously
                // sprang back ON.
                healthSyncOptedIn = granted
                healthSyncError = nil
                if granted { healthSync.markConsentGranted() }
            } catch {
                // Failure: revert the optimistic flip and surface the
                // footnote — the AI Coach error pattern.
                healthSyncOptedIn = granted ? false : true
                healthSyncError = "Couldn't reach the server. Try again later."
            }
        }
    }

    // MARK: - Row builders

    /// Header + inset grouped card + optional footnote (UI V2 `group()`).
    private func group<Content: View>(
        _ title: String,
        footer: String? = nil,
        footerIsError: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let rows = content()
        return VStack(alignment: .leading, spacing: 6) {
            ActionGroupHeader(title: title)
            ActionGroupCard {
                VStack(spacing: 0) {
                    rows
                }
            }
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(footerIsError ? Color.V2.danger : Color.V2.ink3)
                    .padding(.horizontal, V2Metrics.margin)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func navRow(
        icon: String,
        setting: AppIconSystem.Setting? = nil,
        tint: Color,
        glyph: Color,
        title: String,
        titleColor: Color = Color.V2.ink,
        value: String? = nil,
        valueTint: Color? = nil,
        destination: Route? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        let row = SettingsRowLabel(
            icon: icon,
            setting: setting,
            tint: tint,
            glyph: glyph,
            title: title,
            titleColor: titleColor,
            value: value,
            valueColor: valueTint ?? Color.V2.ink3
        ) {
            if action != nil || destination != nil {
                ActionRowChevron()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title + (value.map { ", \($0)" } ?? ""))

        if let destination {
            return AnyView(
                Button {
                    HapticManager.shared.buttonPress()
                    router.settingsPath.append(destination)
                } label: { row }
                .buttonStyle(.plain)
            )
        }
        if let action {
            return AnyView(
                Button {
                    HapticManager.shared.buttonPress()
                    action()
                } label: { row }
                .buttonStyle(.plain)
            )
        }
        return AnyView(row)
    }

    private func toggleRow(
        icon: String,
        setting: AppIconSystem.Setting? = nil,
        tint: Color,
        glyph: Color,
        title: String,
        isOn: Binding<Bool>
    ) -> some View {
        SettingsRowLabel(
            icon: icon,
            setting: setting,
            tint: tint,
            glyph: glyph,
            title: title
        ) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.V2.accent)
                .frame(minHeight: V2Metrics.minTouchTarget)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    // MARK: - Derived

    private var activeCreature: CharacterCreature {
        activeUnlocks.first
            .flatMap { CharacterCreature.find(by: $0.characterId) }
            ?? CharacterCreature.allCharacters[0]
    }

    private var appearanceLabel: String {
        switch AppearanceManager.shared.preferredScheme {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    private var bioAgeText: String {
        viewModel.bioAge.map { "\($0) yrs" } ?? "—"
    }

    private var watchStatusText: String {
        PhoneConnectivityManager.shared.isWatchAppInstalled ? "Connected" : "Not paired"
    }

    private var versionText: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildText: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - HealthKit state

    @State private var healthAuthStatus: HKAuthorizationStatus = .notDetermined
    @State private var isRequestingHealthPermission = false
    @State private var showPermissionDeniedAlert = false
    @AppStorage(HapticPreference.disabledKey) private var hapticsDisabled = false

    /// The Haptics row reads "on", the stored flag is "disabled".
    private var hapticsEnabled: Binding<Bool> {
        Binding(get: { !hapticsDisabled }, set: { hapticsDisabled = !$0 })
    }

    // MARK: - Health data sync (server-side consent)

    /// Session-local UI state only — the `user_consents` server row is the
    /// consent authority (see StressAPIClient+Health.swift), so nothing here
    /// persists. Defaults optimistic: the toggle reads ON until the server
    /// explicitly refuses (a 403 CONSENT_REQUIRED flips `needsConsent`).
    @StateObject private var healthSync = HealthSyncService.shared
    @State private var healthSyncOptedIn = true
    @State private var hasGrantedHealthConsent = false
    @State private var showHealthConsentSheet = false
    @State private var healthSyncError: String?

    private var healthStatusText: String {
        switch healthAuthStatus {
        case .sharingAuthorized: return "Connected"
        case .sharingDenied:     return "Enable"
        case .notDetermined:     return "Enable"
        @unknown default:        return "Enable"
        }
    }

    private func refreshHealthAuthStatus() {
        healthAuthStatus = HKHealthStore().authorizationStatus(for: .quantityType(forIdentifier: .heartRateVariabilitySDNN)!)
    }

    private func requestHealthPermission() {
        isRequestingHealthPermission = true
        guard HKHealthStore.isHealthDataAvailable() else {
            isRequestingHealthPermission = false
            return
        }

        let store = HKHealthStore()
        let types: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKCategoryType(.sleepAnalysis),
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKCharacteristicType(.dateOfBirth),
        ]

        store.requestAuthorization(toShare: [], read: types) { _, _ in
            Task { @MainActor in
                isRequestingHealthPermission = false
                refreshHealthAuthStatus()
                if healthAuthStatus == .sharingDenied {
                    showPermissionDeniedAlert = true
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
                .stressNavigationDestinations()
        }
        .environment(AppRouter())
        .environment(PaywallController())
        .environment(PreferencesService())
        .modelContainer(for: [StressMeasurement.self, CharacterUnlock.self], inMemory: true)
    }
}
