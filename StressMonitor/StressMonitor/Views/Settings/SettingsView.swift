import SwiftUI
import SwiftData
import HealthKit

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
    @State private var showSignInErrorAlert = false

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
            VStack(spacing: 22) {
                meHeroSection
                companionBannerSection
                sectionLabel("Companion")
                companionGroupSection
                sectionLabel("Sync & devices")
                syncDevicesSection
                sectionLabel("Habits & tracking")
                habitsSection
                sectionLabel("Notifications")
                notificationsSection
                sectionLabel("Preferences")
                preferencesSection
                sectionLabel("AI Coach")
                aiCoachSection
                sectionLabel("Data & support")
                dataSupportSection
                versionFooter
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.Wellness.adaptiveBackground)
        .accessibleDynamicType()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showChatSheet) {
            ChatBottomSheetView(stressResult: nil, baseline: nil)
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

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, -8)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - 1. Me-hero

    private var meHeroSection: some View {
        MeHeroCard(
            bioAge: viewModel.bioAge,
            stressLevel: viewModel.latestStressLevel,
            streakDays: viewModel.streakDays,
            displayName: viewModel.displayName,
            email: viewModel.displayEmail ?? accountViewModel.linkedEmail,
            onPlusTap: { paywall.present(reason: .general) }
        )
    }

    // MARK: - 2. Active companion banner

    private var companionBannerSection: some View {
        CompanionBanner(
            companionName: activeCreature.displayName,
            companionSubtitle: activeCreature.element.rawValue.capitalized,
            mood: RippleMood.from(stressLevel: viewModel.latestStressLevel),
            onSwitch: { router.settingsPath.append(Route.characters) }
        )
    }

    // MARK: - 3. Companion group

    private var companionGroupSection: some View {
        SettingsCard {
            VStack(spacing: 0) {
                navRow(
                    icon: AppIconSystem.Setting.characters.sfSymbol,
                    setting: .characters,
                    tint: HomeCharacterDesignTokens.Ripple.deep,
                    title: "Characters",
                    value: "\(unlockedCharacters.count) of \(CharacterCreature.allCharacters.count)",
                    destination: .characters
                )
                hairlineDivider
                navRow(
                    icon: AppIconSystem.Setting.rippleCoach.sfSymbol,
                    setting: .rippleCoach,
                    tint: .settingsIconPurple,
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
            }
        }
    }

    // MARK: - 4. Sync & devices

    private var syncDevicesSection: some View {
        // Card split out so the wrapper can add the consent-failure
        // footnote — same optimistic-then-revert shape as aiCoachSection.
        VStack(spacing: 6) {
            syncDevicesCard
            if let healthSyncError {
                Text(healthSyncError)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var syncDevicesCard: some View {
        SettingsCard {
            VStack(spacing: 0) {
                navRow(
                    icon: AppIconSystem.Setting.appleHealth.sfSymbol,
                    setting: .appleHealth,
                    tint: .primaryGreen,
                    title: "Apple Health",
                    value: healthStatusText,
                    action: healthAuthStatus == .sharingAuthorized ? nil : { requestHealthPermission() }
                )
                hairlineDivider
                toggleRow(
                    icon: AppIconSystem.Setting.dailySummary.sfSymbol,
                    setting: .dailySummary,
                    tint: .primaryGreen,
                    title: "Health Data Sync",
                    isOn: healthSyncToggleBinding
                )
                if FeatureFlags.agentChatEnabled {
                    hairlineDivider
                    navRow(
                        icon: AppIconSystem.Setting.rippleCoach.sfSymbol,
                        setting: .rippleCoach,
                        tint: .settingsIconPurple,
                        title: "Health Coach",
                        value: "New",
                        destination: .agentChat
                    )
                }
                hairlineDivider
                navRow(
                    icon: "g.circle",
                    tint: .settingsRippleBlue,
                    title: "Sign in with Google",
                    value: accountViewModel.linkedEmail ?? "Link account",
                    action: signInWithGoogleTapped
                )
                hairlineDivider
                navRow(
                    icon: AppIconSystem.Setting.appleWatch.sfSymbol,
                    setting: .appleWatch,
                    tint: .settingsRippleBlue,
                    title: "Apple Watch",
                    value: watchStatusText,
                    destination: .watchFace
                )
                hairlineDivider
                navRow(
                    icon: AppIconSystem.Setting.biologicalAge.sfSymbol,
                    setting: .biologicalAge,
                    tint: .primaryGreen,
                    title: "Biological Age",
                    value: bioAgeText,
                    destination: .bioAge
                )
            }
        }
    }

    // MARK: - 5. Habits & tracking

    private var habitsSection: some View {
        SettingsCard {
            VStack(spacing: 0) {
                if let habitVM = habitViewModel {
                    ForEach(Array(HabitType.allCases.enumerated()), id: \.element.id) { index, type in
                        if let habit = habitVM.habit(for: type) {
                            HabitLogRow(habit: habit) {
                                habitVM.logManual(type)
                            }
                            if index < HabitType.allCases.count - 1 {
                                hairlineDivider
                            }
                        }
                    }
                } else {
                    ForEach(Array(HabitType.allCases.enumerated()), id: \.element.id) { index, _ in
                        HabitLogRow(habit: Habit(type: HabitType.allCases[index]))
                        if index < HabitType.allCases.count - 1 {
                            hairlineDivider
                        }
                    }
                }
            }
        }
    }

    // MARK: - 6. Notifications

    private var notificationsSection: some View {
        SettingsCard {
            VStack(spacing: 0) {
                toggleRow(
                    icon: AppIconSystem.Setting.stressAlerts.sfSymbol,
                    setting: .stressAlerts,
                    tint: .settingsIconPurple,
                    title: "Stress alerts",
                    isOn: $viewModel.notificationSettings.stressAlertsEnabled
                )
                hairlineDivider
                toggleRow(
                    icon: AppIconSystem.Setting.waterReminder.sfSymbol,
                    setting: .waterReminder,
                    tint: .settingsRippleBlue,
                    title: "Water reminder",
                    isOn: $viewModel.notificationSettings.waterReminderEnabled
                )
                hairlineDivider
                toggleRow(
                    icon: AppIconSystem.Setting.dailySummary.sfSymbol,
                    setting: .dailySummary,
                    tint: Color(hex: "#FE9901"),
                    title: "Daily summary",
                    isOn: $viewModel.notificationSettings.dailySummaryEnabled
                )
            }
        }
        .onChange(of: viewModel.notificationSettings.stressAlertsEnabled) { _, _ in viewModel.notificationSettings.persist() }
        .onChange(of: viewModel.notificationSettings.waterReminderEnabled) { _, _ in viewModel.notificationSettings.persist() }
        .onChange(of: viewModel.notificationSettings.dailySummaryEnabled) { _, _ in viewModel.notificationSettings.persist() }
    }

    // MARK: - 7. Preferences

    private var preferencesSection: some View {
        SettingsCard {
            VStack(spacing: 0) {
                navRow(
                    icon: AppIconSystem.Setting.stressMonitorPlus.sfSymbol,
                    setting: .stressMonitorPlus,
                    tint: .premiumGold,
                    title: "StressMonitor Plus",
                    value: CreditBalanceFormatter.plusRowValue(creditService.balance),
                    valueTint: .premiumGold,
                    action: { paywall.present(reason: .general) }
                )
                hairlineDivider
                navRow(
                    icon: AppIconSystem.Setting.appearance.sfSymbol,
                    setting: .appearance,
                    tint: Color.Wellness.adaptiveSecondaryText,
                    title: "Appearance",
                    value: appearanceLabel,
                    destination: .appearance
                )
                hairlineDivider
                toggleRow(
                    icon: AppIconSystem.Setting.haptics.sfSymbol,
                    setting: .haptics,
                    tint: .orange,
                    title: "Haptics",
                    isOn: $hapticsEnabled
                )
                hairlineDivider
                navRow(
                    icon: "rectangle.3.group.fill",
                    tint: .settingsIconPurple,
                    title: "Home screen widgets",
                    value: "3 sizes",
                    destination: .about
                )
            }
        }
    }

    // MARK: - 7b. AI Coach (server-synced preference pair)

    /// Language + coaching-style pickers riding `PreferencesService`. The
    /// closed option sets mirror the backend's accepted vocabulary; a current
    /// value outside the set still displays (the row text comes from state,
    /// not the option list). A failed PUT reverts inside the service — the
    /// footnote under the card is the user-facing signal.
    private var aiCoachSection: some View {
        VStack(spacing: 6) {
            SettingsCard {
                VStack(spacing: 0) {
                    aiCoachPickerRow(
                        icon: "globe",
                        tint: .settingsRippleBlue,
                        title: "Language",
                        currentValue: preferencesService.language,
                        options: [("en", "English"), ("vi", "Tiếng Việt")],
                        pickerLabel: "AI Coach language"
                    ) { newValue in
                        Task { await preferencesService.update(language: newValue) }
                    }
                    hairlineDivider
                    aiCoachPickerRow(
                        icon: "text.bubble.fill",
                        tint: .settingsIconPurple,
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
            if let message = preferencesService.errorMessage {
                Text(message)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func aiCoachPickerRow(
        icon: String,
        tint: Color,
        title: String,
        currentValue: String,
        options: [(raw: String, label: String)],
        pickerLabel: String,
        onChange: @escaping (String) -> Void
    ) -> some View {
        HStack(spacing: 12) {
            iconBadge(systemName: icon, tint: tint)
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                .lineLimit(1)
            Spacer(minLength: 8)
            if !options.contains(where: { $0.raw == currentValue }) {
                Text(currentValue.capitalized)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText)
            }
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
            .tint(Color.Wellness.adaptiveSecondaryText)
            .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
            .accessibilityLabel(pickerLabel)
        }
        .padding(.vertical, 10)
    }

    // MARK: - 8. Data & support

    private var dataSupportSection: some View {
        SettingsCard {
            VStack(spacing: 0) {
                navRow(
                    icon: AppIconSystem.Setting.exportData.sfSymbol,
                    setting: .exportData,
                    tint: .primaryGreen,
                    title: "Export data",
                    destination: .dataExport
                )
                hairlineDivider
                navRow(
                    icon: AppIconSystem.Setting.manageData.sfSymbol,
                    setting: .manageData,
                    tint: Color.error,
                    title: "Manage data",
                    destination: .dataManage
                )
                hairlineDivider
                navRow(
                    icon: AppIconSystem.Setting.helpPrivacy.sfSymbol,
                    setting: .helpPrivacy,
                    tint: Color.Wellness.adaptiveSecondaryText,
                    title: "Help & privacy",
                    destination: .about
                )
            }
        }
    }

    private var versionFooter: some View {
        Text("Version \(versionText) · Build \(buildText)")
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
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

    private func navRow(
        icon: String,
        setting: AppIconSystem.Setting? = nil,
        tint: Color,
        title: String,
        value: String? = nil,
        valueTint: Color? = nil,
        destination: Route? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        let row = HStack(spacing: 12) {
            iconBadge(systemName: icon, setting: setting, tint: tint)
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(valueTint ?? Color.Wellness.adaptiveSecondaryText)
            }
            if action != nil || destination != nil {
                Image(systemName: AppIconSystem.Nav.forward.sfSymbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.Wellness.adaptiveSecondaryText.opacity(0.5))
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 10)
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
        title: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            iconBadge(systemName: icon, setting: setting, tint: tint)
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.Wellness.adaptivePrimaryText)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.primaryGreen)
                .minimumTouchTarget(DesignTokens.Layout.minTouchTarget)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    private func iconBadge(systemName: String, setting: AppIconSystem.Setting? = nil, tint: Color) -> some View {
        Group {
            if let setting {
                SettingsIconView(setting, color: tint)
            } else {
                SettingsIconView(systemName: systemName, color: tint)
            }
        }
        .accessibilityHidden(true)
    }

    private var hairlineDivider: some View {
        Rectangle()
            .fill(Color.Wellness.adaptiveSecondaryText.opacity(0.14))
            .frame(height: 0.5)
            .padding(.leading, 40)
            .accessibilityHidden(true)
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
    @State private var hapticsEnabled: Bool = !UserDefaults.standard.bool(forKey: "appearance.hapticsDisabled")

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
