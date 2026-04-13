import GrowWiseModels
import GrowWiseServices
import os
import StoreKit
import SwiftUI

public struct AppSettingsView: View {
    @Environment(DataService.self) private var dataService
    @Environment(\.dismiss) private var dismiss

    // User preferences (loaded on appear, saved on change)
    @State private var measurementSystem: MeasurementSystem = .imperial
    @State private var skillLevel: GardeningSkillLevel = .beginner
    @State private var hardinessZone: String = ""

    // App preferences (UserDefaults-backed)
    @AppStorage("app_appearance") private var appearance: AppAppearance = .system
    @AppStorage("app_haptics_enabled") private var hapticsEnabled = true

    // Alerts
    @State private var showDeleteConfirmation = false
    @State private var showExportSuccess = false
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    @State private var isExporting = false
    @State private var saveErrorMessage: String?

    public init() {}

    // MARK: - Computed

    private var currentUser: User? {
        dataService.getCurrentUser()
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                gardenPreferencesSection
                displaySection
                dataSection
                aboutSection
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.vertical, CultivationTheme.Spacing.sectionGap)
        }
        .background(CultivationTheme.Colors.background)
        .navigationTitle("Settings")
        .task { loadUserPreferences() }
        .alert("Delete All Data", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will permanently delete all your gardens, plants, journal entries, and reminders. This cannot be undone.")
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your garden data has been exported successfully.")
        }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
        .alert("Save Failed", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
                .accessibilityIdentifier("settings_button_save_error_dismiss")
        } message: {
            Text(saveErrorMessage ?? "An unexpected error occurred.")
        }
    }

    // MARK: - Garden Preferences

    private var gardenPreferencesSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Garden Preferences")
                .sectionLabelStyle()
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Measurement System
                settingsPickerRow(
                    icon: "ruler",
                    color: .blue,
                    title: "Units",
                    id: "settings_units"
                ) {
                    Picker("", selection: $measurementSystem) {
                        ForEach(MeasurementSystem.allCases, id: \.self) { system in
                            Text(system.shortLabel).tag(system)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(CultivationTheme.Colors.textSecondary)
                    .onChange(of: measurementSystem) { _, newValue in
                        saveUserPreference(\.measurementSystem, value: newValue)
                    }
                }

                settingsDivider

                // Skill Level
                settingsPickerRow(
                    icon: "star.fill",
                    color: .yellow,
                    title: "Skill Level",
                    id: "settings_skill_level"
                ) {
                    Picker("", selection: $skillLevel) {
                        ForEach(GardeningSkillLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(CultivationTheme.Colors.textSecondary)
                    .onChange(of: skillLevel) { _, newValue in
                        saveUserPreference(\.skillLevel, value: newValue)
                    }
                }

                settingsDivider

                // Hardiness Zone
                settingsPickerRow(
                    icon: "thermometer.sun",
                    color: CultivationTheme.Colors.accentCoral,
                    title: "Hardiness Zone",
                    id: "settings_zone"
                ) {
                    Picker("", selection: $hardinessZone) {
                        Text("Not Set").tag("")
                        ForEach(hardinessZones, id: \.self) { zone in
                            Text(zone).tag(zone)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(CultivationTheme.Colors.textSecondary)
                    .onChange(of: hardinessZone) { _, newValue in
                        saveUserPreference(\.hardinessZone, value: newValue.isEmpty ? nil : newValue)
                    }
                }
            }
            .glassCard()
        }
    }

    // MARK: - Display Section

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Display")
                .sectionLabelStyle()
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Appearance
                settingsPickerRow(
                    icon: "circle.lefthalf.filled",
                    color: .purple,
                    title: "Appearance",
                    id: "settings_appearance"
                ) {
                    Picker("", selection: $appearance) {
                        ForEach(AppAppearance.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(CultivationTheme.Colors.textSecondary)
                }

                settingsDivider

                // Haptics
                settingsToggleRow(
                    icon: "hand.tap",
                    color: .orange,
                    title: "Haptic Feedback",
                    id: "settings_haptics",
                    isOn: $hapticsEnabled
                )
            }
            .glassCard()
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Data & Privacy")
                .sectionLabelStyle()
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Export Data
                settingsActionRow(
                    icon: "square.and.arrow.up",
                    color: CultivationTheme.Colors.brandLeaf,
                    title: "Export Garden Data",
                    id: "settings_export",
                    isLoading: isExporting
                ) {
                    exportData()
                }

                settingsDivider

                // Delete All Data
                settingsActionRow(
                    icon: "trash",
                    color: CultivationTheme.Colors.statusAlert,
                    title: "Delete All Data",
                    id: "settings_delete_data",
                    titleColor: CultivationTheme.Colors.statusAlert
                ) {
                    showDeleteConfirmation = true
                }
            }
            .glassCard()
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("About")
                .sectionLabelStyle()
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Rate the App
                settingsLinkRow(
                    icon: "heart.fill",
                    color: .pink,
                    title: "Rate Cultivation",
                    id: "settings_rate"
                ) {
                    requestReview()
                }

                settingsDivider

                // Privacy Policy
                settingsLinkRow(
                    icon: "hand.raised.fill",
                    color: .blue,
                    title: "Privacy Policy",
                    id: "settings_privacy"
                ) {
                    openURL("https://growwiser.app/privacy")
                }

                settingsDivider

                // Terms of Service
                settingsLinkRow(
                    icon: "doc.text",
                    color: .gray,
                    title: "Terms of Service",
                    id: "settings_terms"
                ) {
                    openURL("https://growwiser.app/terms")
                }

                settingsDivider

                // Version
                HStack(spacing: 14) {
                    IconBubble(
                        systemName: "info.circle",
                        color: CultivationTheme.Colors.textTertiary,
                        size: 36,
                        iconSize: 16
                    )
                    Text("Version")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    Spacer()
                    Text(appVersion)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
                .padding(CultivationTheme.Spacing.cardPadding)
                .accessibilityIdentifier("settings_version")
            }
            .glassCard()
        }
    }

    // MARK: - Row Builders

    private func settingsPickerRow(
        icon: String,
        color: Color,
        title: String,
        id: String,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(spacing: 14) {
            IconBubble(systemName: icon, color: color, size: 36, iconSize: 16)
            Text(title)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            Spacer()
            trailing()
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .accessibilityIdentifier(id)
    }

    private func settingsToggleRow(
        icon: String,
        color: Color,
        title: String,
        id: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 14) {
            IconBubble(systemName: icon, color: color, size: 36, iconSize: 16)
            Text(title)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(CultivationTheme.Colors.brandLeaf)
                .labelsHidden()
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .accessibilityIdentifier(id)
    }

    private func settingsActionRow(
        icon: String,
        color: Color,
        title: String,
        id: String,
        titleColor: Color? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                IconBubble(systemName: icon, color: color, size: 36, iconSize: 16)
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(titleColor ?? CultivationTheme.Colors.textPrimary)
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
            }
            .padding(CultivationTheme.Spacing.cardPadding)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityIdentifier(id)
    }

    private func settingsLinkRow(
        icon: String,
        color: Color,
        title: String,
        id: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                IconBubble(systemName: icon, color: color, size: 36, iconSize: 16)
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
            .padding(CultivationTheme.Spacing.cardPadding)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private var settingsDivider: some View {
        Divider()
            .background(CultivationTheme.Colors.divider)
            .padding(.leading, 64)
    }

    // MARK: - Data

    private let hardinessZones: [String] = [
        "1a", "1b", "2a", "2b", "3a", "3b", "4a", "4b",
        "5a", "5b", "6a", "6b", "7a", "7b", "8a", "8b",
        "9a", "9b", "10a", "10b", "11a", "11b", "12a", "12b", "13a", "13b",
    ]

    // MARK: - Actions

    private func loadUserPreferences() {
        guard let user = currentUser else { return }
        measurementSystem = user.measurementSystem
        skillLevel = user.skillLevel
        hardinessZone = user.hardinessZone ?? ""
    }

    private func saveUserPreference<T>(_ keyPath: ReferenceWritableKeyPath<User, T>, value: T) {
        guard let user = currentUser else { return }
        user[keyPath: keyPath] = value
        user.lastModified = Date()
        do {
            try dataService.updateUser(user)
        } catch {
            Logger(subsystem: "com.growwise", category: "AppSettingsView")
                .error("Failed to save user preference: \(error.localizedDescription, privacy: .public)")
            saveErrorMessage = "Failed to save preference: \(error.localizedDescription)"
        }
    }

    private func exportData() {
        isExporting = true
        Task {
            do {
                let data = try await dataService.exportUserData()
                await MainActor.run {
                    isExporting = false
                    shareData(data)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportErrorMessage = error.localizedDescription
                    showExportError = true
                }
            }
        }
    }

    private func shareData(_ data: Data) {
        #if canImport(UIKit) && !os(macOS)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cultivation-export-\(Date().ISO8601Format()).json")
        do {
            try data.write(to: tempURL)
            let activityVC = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController
            {
                var presenter = rootVC
                while let presented = presenter.presentedViewController {
                    presenter = presented
                }
                presenter.present(activityVC, animated: true)
            }
        } catch {
            exportErrorMessage = error.localizedDescription
            showExportError = true
        }
        #endif
    }

    private func resetAllData() {
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
    }

    private func requestReview() {
        #if canImport(UIKit) && !os(macOS)
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        AppStore.requestReview(in: scene)
        #endif
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        #if canImport(UIKit) && !os(macOS)
        UIApplication.shared.open(url)
        #endif
    }
}

// MARK: - Supporting Types

public enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark

    public var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

// MARK: - MeasurementSystem Short Label

extension MeasurementSystem {
    var shortLabel: String {
        switch self {
        case .imperial: "Imperial"
        case .metric: "Metric"
        }
    }
}

#Preview {
    NavigationStack {
        AppSettingsView()
            .environment(DataService.createFallback())
    }
}
