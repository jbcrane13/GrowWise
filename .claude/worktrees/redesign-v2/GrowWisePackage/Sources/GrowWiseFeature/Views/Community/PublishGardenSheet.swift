import CloudKit
import GrowWiseModels
import GrowWiseServices
import SwiftUI

struct PublishGardenSheet: View {
    @Environment(CloudSyncService.self)
    private var cloudSyncService
    @Environment(DataService.self)
    private var dataService
    @Environment(\.dismiss)
    private var dismiss

    @State private var gardens: [Garden] = []
    @State private var selectedGarden: Garden?
    @State private var authorName: String = ""
    @State private var gardenDescription: String = ""
    @State private var isPublishing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                    headerSection
                    gardenPickerSection
                    authorSection
                    descriptionSection
                    publishButton
                }
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                .padding(.vertical, CultivationTheme.Spacing.sectionGap)
            }
            .background(CultivationTheme.Colors.background)
            .navigationTitle("Publish Garden")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .accessibilityIdentifier("publish_button_cancel")
                    }
                }
                .task {
                    gardens = dataService.fetchGardens(offset: 0, limit: 50)
                }
                .alert("Error", isPresented: $showError, presenting: errorMessage) { _ in
                    Button("OK", role: .cancel) {}
                        .accessibilityIdentifier("publish_alert_ok")
                } message: { message in
                    Text(message)
                }
                .alert("Published!", isPresented: $showSuccess) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("publish_alert_done")
                } message: {
                    Text("Your garden is now visible in the community showcase.")
                }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(CultivationTheme.Gradients.warmAccent)
                    .frame(width: 64, height: 64)
                Image(systemName: "globe")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
            }

            Text("Share with the Community")
                .font(.system(.title3, design: .serif, weight: .regular))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)

            Text("Publish one of your gardens for others to discover and get inspired by.")
                .font(.system(.subheadline))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Garden Picker

    private var gardenPickerSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Select Garden")
                .sectionLabelStyle()
                .padding(.leading, 4)

            if gardens.isEmpty {
                Text("No gardens available. Create a garden first.")
                    .font(.system(.subheadline))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(CultivationTheme.Spacing.cardPadding)
                    .glassCard()
            } else {
                ForEach(gardens, id: \.id) { garden in
                    gardenRow(garden)
                }
            }
        }
    }

    private func gardenRow(_ garden: Garden) -> some View {
        let isSelected = selectedGarden?.id == garden.id
        return Button {
            withAnimation(CultivationTheme.Animation.selection) {
                selectedGarden = garden
            }
        } label: {
            HStack(spacing: 12) {
                IconBubble(
                    systemName: "leaf.fill",
                    color: isSelected ? CultivationTheme.Colors.accentCoral : CultivationTheme.Colors.textTertiary,
                    size: 36,
                    iconSize: 16
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(garden.name ?? "Unnamed Garden")
                        .font(.system(.body, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)

                    if let gardenType = garden.gardenType {
                        Text(gardenType.displayName)
                            .font(.system(.caption))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(CultivationTheme.Colors.accentCoral)
                }
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: CultivationTheme.Radius.card)
                        .stroke(CultivationTheme.Colors.accentCoral.opacity(0.4), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("publish_garden_row_\(garden.id?.uuidString ?? "unknown")")
    }

    // MARK: - Author Name

    private var authorSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Display Name")
                .sectionLabelStyle()
                .padding(.leading, 4)

            TextField("Your name or nickname", text: $authorName)
                .font(.system(.body))
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()
                .accessibilityIdentifier("publish_textfield_author")
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: CultivationTheme.Spacing.rowGap) {
            Text("Description")
                .sectionLabelStyle()
                .padding(.leading, 4)

            TextField("Tell others about your garden...", text: $gardenDescription, axis: .vertical)
                .font(.system(.body))
                .lineLimit(3 ... 6)
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()
                .accessibilityIdentifier("publish_textfield_description")
        }
    }

    // MARK: - Publish Button

    private var publishButton: some View {
        Group {
            if isPublishing {
                ProgressView("Publishing...")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .accessibilityIdentifier("publish_loading")
            } else {
                Button {
                    Task<Void, Never> {
                        await publish()
                    }
                } label: {
                    Text("Publish Garden")
                }
                .buttonStyle(GradientButtonStyle(isDisabled: !canPublish))
                .disabled(!canPublish)
                .accessibilityIdentifier("publish_button_submit")
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Logic

    private var canPublish: Bool {
        selectedGarden != nil && !authorName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func publish() async {
        guard let garden = selectedGarden else { return }

        isPublishing = true
        defer { isPublishing = false }

        do {
            let desc = gardenDescription.trimmingCharacters(in: .whitespaces).isEmpty ? nil : gardenDescription.trimmingCharacters(in: .whitespaces)
            _ = try await cloudSyncService.publishGarden(
                garden,
                authorName: authorName.trimmingCharacters(in: .whitespaces),
                description: desc
            )
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
