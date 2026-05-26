import GrowWiseModels
import GrowWiseServices
import os
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable attributes line_length type_body_length

// MARK: - AddSeedSheet

/// Sheet form for adding a new seed to the inventory with optional packet scanning.
struct AddSeedSheet: View {
    @Environment(\.dismiss)
    private var dismiss
    @Environment(DataService.self)
    private var dataService

    private let logger = Logger(subsystem: "com.growwise.gardening", category: "AddSeedSheet")

    // Basic info
    @State private var varietyName: String = ""
    @State private var brand: String = ""
    @State private var plantType: PlantType = .vegetable
    @State private var quantity: Int = 1
    @State private var expirationYear: Int = Calendar.current.component(.year, from: Date()) + 2

    // Plant database link
    @State private var linkedPlantName: String?
    @State private var linkedPlantID: String?
    @State private var inventoryService = SeedInventoryService()
    @State private var plantDatabase: [Plant] = []

    // Growing requirements
    @State private var sunExposure: SunExposure?
    @State private var wateringFrequency: WateringFrequency?
    @State private var spaceRequirement: SpaceRequirement?
    @State private var depthInches: String = ""
    @State private var spacingInches: String = ""
    @State private var germinationDays: String = ""
    @State private var harvestDays: String = ""
    @State private var indoorStartWeeks: String = ""

    /// Notes
    @State private var notes: String = ""

    // Scanner
    @State private var showScanner = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var canSave: Bool {
        !varietyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                    scanButton
                    basicInfoSection
                    linkSuggestion
                    growingRequirementsSection
                    notesSection
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.bottom, 32)
            }
            .background(CultivationTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Add Seed")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
                    .accessibilityIdentifier("add_seed_button_error_ok")
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
            #if canImport(UIKit)
            .sheet(isPresented: $showScanner) {
                SeedScannerView { result in
                    applyScanResult(result)
                }
            }
            #endif
        }
        .task { await loadPlantDatabase() }
        .onChange(of: varietyName) { _, _ in
            checkPlantDatabaseLink()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
            .font(.system(.body, design: .rounded))
            .accessibilityIdentifier("add_seed_button_cancel")
        }

        ToolbarItem(placement: .primaryAction) {
            Button("Save") {
                saveSeed()
            }
            .font(.system(.body, design: .rounded, weight: .semibold))
            .disabled(!canSave)
            .accessibilityIdentifier("add_seed_button_save")
        }
    }

    // MARK: - Scan Button

    private var scanButton: some View {
        Button {
            showScanner = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 18, weight: .semibold))
                Text("Scan Seed Packet")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                RoundedRectangle(cornerRadius: CultivationTheme.Radius.button)
                    .fill(CultivationTheme.Gradients.warmAccent)
                    .shadow(
                        color: CultivationTheme.Colors.accentCoral.opacity(0.30),
                        radius: 8,
                        y: 3
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("add_seed_button_scan")
    }

    // MARK: - Basic Info Section

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("BASIC INFO")
                .sectionLabelStyle()

            VStack(spacing: 12) {
                // Variety name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Variety Name")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    TextField("e.g. Roma Tomato", text: $varietyName)
                        .font(.system(.body, design: .rounded))
                        .padding(12)
                        .glassCard()
                        .accessibilityIdentifier("add_seed_field_variety")
                }

                // Brand
                VStack(alignment: .leading, spacing: 6) {
                    Text("Brand")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    TextField("e.g. Burpee", text: $brand)
                        .font(.system(.body, design: .rounded))
                        .padding(12)
                        .glassCard()
                        .accessibilityIdentifier("add_seed_field_brand")
                }

                // Plant type picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Plant Type")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    Picker("Plant Type", selection: $plantType) {
                        ForEach(PlantType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(.body, design: .rounded))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                    .accessibilityIdentifier("add_seed_picker_type")
                }

                // Quantity
                HStack {
                    Text("Quantity")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    Spacer()
                    Stepper("\(quantity)", value: $quantity, in: 1 ... 999)
                        .font(.system(.body, design: .rounded))
                        .accessibilityIdentifier("add_seed_stepper_quantity")
                }
                .padding(12)
                .glassCard()

                // Expiration year
                HStack {
                    Text("Expiration Year")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    Spacer()
                    Stepper("\(String(expirationYear))", value: $expirationYear, in: 2020 ... 2040)
                        .font(.system(.body, design: .rounded))
                        .accessibilityIdentifier("add_seed_stepper_expiration")
                }
                .padding(12)
                .glassCard()
            }
        }
    }

    // MARK: - Link Suggestion

    @ViewBuilder
    private var linkSuggestion: some View {
        if let name = linkedPlantName {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(CultivationTheme.Colors.statusHealthy)
                Text("Linked to \(name)")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Spacer()
                Button {
                    linkedPlantName = nil
                    linkedPlantID = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("add_seed_button_unlink")
            }
            .padding(12)
            .glassCard()
            .accessibilityIdentifier("add_seed_link_suggestion")
        }
    }

    // MARK: - Growing Requirements Section

    private var growingRequirementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("GROWING REQUIREMENTS")
                .sectionLabelStyle()

            VStack(spacing: 12) {
                // Sun exposure
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sun Exposure")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    Picker("Sun Exposure", selection: $sunExposure) {
                        Text("Not Set").tag(SunExposure?.none)
                        ForEach(SunExposure.allCases, id: \.self) { exposure in
                            Text(exposure.displayName).tag(SunExposure?.some(exposure))
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(.body, design: .rounded))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                    .accessibilityIdentifier("add_seed_picker_sun")
                }

                // Watering frequency
                VStack(alignment: .leading, spacing: 6) {
                    Text("Watering Frequency")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    Picker("Watering Frequency", selection: $wateringFrequency) {
                        Text("Not Set").tag(WateringFrequency?.none)
                        ForEach(WateringFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(WateringFrequency?.some(freq))
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(.body, design: .rounded))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                    .accessibilityIdentifier("add_seed_picker_water")
                }

                // Space requirement
                VStack(alignment: .leading, spacing: 6) {
                    Text("Space Requirement")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    Picker("Space Requirement", selection: $spaceRequirement) {
                        Text("Not Set").tag(SpaceRequirement?.none)
                        ForEach(SpaceRequirement.allCases, id: \.self) { space in
                            Text(space.displayName).tag(SpaceRequirement?.some(space))
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(.body, design: .rounded))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                    .accessibilityIdentifier("add_seed_picker_space")
                }

                // Depth
                fieldRow(label: "Planting Depth (inches)", text: $depthInches, id: "add_seed_field_depth")

                // Spacing
                fieldRow(label: "Seed Spacing (inches)", text: $spacingInches, id: "add_seed_field_spacing")

                // Germination days
                fieldRow(label: "Days to Germination", text: $germinationDays, id: "add_seed_field_germination")

                // Harvest days
                fieldRow(label: "Days to Harvest", text: $harvestDays, id: "add_seed_field_harvest")

                // Indoor start weeks
                fieldRow(label: "Indoor Start (weeks before last frost)", text: $indoorStartWeeks, id: "add_seed_field_indoor_start")
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NOTES")
                .sectionLabelStyle()

            TextEditor(text: $notes)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(12)
                .glassCard()
                .accessibilityIdentifier("add_seed_field_notes")
        }
    }

    // MARK: - Reusable Field Row

    private func fieldRow(label: String, text: Binding<String>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
            TextField("", text: text)
                .accessibilityIdentifier(id)
            #if canImport(UIKit)
                .keyboardType(.decimalPad)
            #endif
                .font(.system(.body, design: .rounded))
                .padding(12)
                .glassCard()
        }
    }

    // MARK: - Actions

    private func saveSeed() {
        let trimmedName = varietyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let seed = Seed(varietyName: trimmedName, plantType: plantType, quantity: quantity)
        seed.brand = brand.isEmpty ? nil : brand
        seed.expirationYear = expirationYear
        seed.plantDatabaseID = linkedPlantID
        seed.sunRequirement = sunExposure
        seed.wateringFrequency = wateringFrequency
        seed.spaceRequirement = spaceRequirement
        seed.plantingDepthInches = Double(depthInches)
        seed.seedSpacingInches = Double(spacingInches)
        seed.daysToGermination = Int(germinationDays)
        seed.daysToHarvest = Int(harvestDays)
        seed.indoorStartWeeks = Int(indoorStartWeeks)
        seed.notes = notes.isEmpty ? nil : notes

        do {
            try dataService.seeds.add(seed)
            dismiss()
        } catch {
            logger.error("Failed to save seed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Failed to save seed. Please try again."
            showError = true
        }
    }

    private func loadPlantDatabase() async {
        do {
            plantDatabase = try dataService.plants.fetchAll()
        } catch {
            logger.warning("Failed to load plant database: \(error.localizedDescription, privacy: .public)")
            plantDatabase = []
        }
    }

    private func checkPlantDatabaseLink() {
        let trimmed = varietyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            linkedPlantName = nil
            linkedPlantID = nil
            return
        }

        // Create a temporary seed to pass to the service
        let tempSeed = Seed(varietyName: trimmed)
        if let matchID = inventoryService.suggestPlantDatabaseLink(for: tempSeed, plantDatabase: plantDatabase) {
            linkedPlantID = matchID
            linkedPlantName = plantDatabase.first(where: { $0.id?.uuidString == matchID })?.name
        } else {
            linkedPlantID = nil
            linkedPlantName = nil
        }
    }

    #if canImport(UIKit)
    private func applyScanResult(_ result: SeedScanResult) {
        if let variety = result.suggestedVariety {
            varietyName = variety
        }
        if let scannedBrand = result.suggestedBrand {
            brand = scannedBrand
        }
        if let depth = result.suggestedDepth {
            depthInches = String(format: "%.1f", depth)
        }
        if let spacing = result.suggestedSpacing {
            spacingInches = String(format: "%.1f", spacing)
        }
        if let germination = result.suggestedDaysToGermination {
            germinationDays = "\(germination)"
        }
        if let harvest = result.suggestedDaysToHarvest {
            harvestDays = "\(harvest)"
        }
        if let sun = result.suggestedSun {
            sunExposure = sun
        }
    }
    #endif
}

// swiftlint:enable attributes line_length type_body_length
