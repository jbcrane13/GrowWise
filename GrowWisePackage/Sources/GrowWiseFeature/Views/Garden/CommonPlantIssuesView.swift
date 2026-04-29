import GrowWiseModels
import SwiftUI

// MARK: - PlantIssue

struct PlantIssue: Identifiable {
    let id = UUID()
    let name: String
    let symptoms: String
    let treatment: String
    let icon: String
}

// MARK: - CommonPlantIssuesView

/// Shows common issues for a given plant type with symptoms and treatments.
/// Includes a button to open PlantScannerView for a camera-based plant health check.
struct CommonPlantIssuesView: View {
    let plant: Plant

    @Environment(\.dismiss)
    private var dismiss

    @State private var showScanner = false

    private var issues: [PlantIssue] {
        commonIssues(for: plant.plantType ?? .houseplant)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.background.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                        // Header
                        VStack(spacing: 8) {
                            IconBubble(
                                systemName: "stethoscope",
                                color: CultivationTheme.Colors.statusWarning,
                                size: 64,
                                iconSize: 28
                            )
                            Text("Common Issues")
                                .font(.system(.title3, design: .serif))
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            Text("for \(plant.plantType?.displayName ?? "plants")")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                        // Issue cards
                        ForEach(issues) { issue in
                            IssueCard(issue: issue)
                        }

                        // Scanner button
                        VStack(spacing: 10) {
                            Text("Not sure what\u{2019}s wrong?")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(CultivationTheme.Colors.textSecondary)

                            Button {
                                showScanner = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                    Text("Scan with Camera")
                                }
                            }
                            .buttonStyle(GradientButtonStyle())
                            .accessibilityIdentifier("issues_button_scan")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Plant Health Guidance")
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("issues_button_done")
                }
            }
            .sheet(isPresented: $showScanner) {
                PlantScannerView()
            }
        }
    }

    // MARK: - Issue Database

    // swiftlint:disable:next function_body_length
    private func commonIssues(for type: PlantType) -> [PlantIssue] {
        switch type {
        case .vegetable:
            [
                PlantIssue(
                    name: "Blossom End Rot",
                    symptoms: "Dark, sunken spots on the bottom of fruits (tomatoes, peppers, squash)",
                    treatment: "Maintain consistent watering. Add calcium-rich amendments like crushed eggshells to soil.",
                    icon: "circle.bottomhalf.filled"
                ),
                PlantIssue(name: "Aphids", symptoms: "Tiny green or black insects clustered on new growth; sticky residue on leaves", treatment: "Spray with strong water stream. Apply neem oil or insecticidal soap weekly.", icon: "ant.fill"),
                PlantIssue(name: "Powdery Mildew", symptoms: "White powdery coating on leaves, starting from older foliage", treatment: "Improve air circulation. Spray with diluted milk solution (1:9 ratio) or baking soda mix.", icon: "cloud.fill"),
                PlantIssue(name: "Yellowing Leaves", symptoms: "Lower leaves turning yellow while upper leaves remain green", treatment: "Usually nitrogen deficiency. Apply balanced fertilizer. Check for overwatering.", icon: "leaf.fill"),
                PlantIssue(name: "Wilting", symptoms: "Drooping leaves and stems despite adequate water", treatment: "Check for root rot from overwatering. Ensure proper drainage. May indicate fusarium wilt.", icon: "arrow.down.to.line"),
            ]

        case .herb:
            [
                PlantIssue(name: "Leggy Growth", symptoms: "Tall, spindly stems with few leaves; reaching toward light", treatment: "Provide more direct light. Pinch growing tips regularly to encourage bushier growth.", icon: "arrow.up.right"),
                PlantIssue(name: "Root Rot", symptoms: "Mushy stems at soil level; yellowing leaves; foul smell from soil", treatment: "Reduce watering immediately. Repot in fresh well-draining soil. Remove affected roots.", icon: "exclamationmark.triangle.fill"),
                PlantIssue(name: "Bolting", symptoms: "Sudden flower stalk growth; leaves become bitter", treatment: "Harvest immediately. Provide afternoon shade in summer. Keep soil consistently moist.", icon: "arrow.up.circle.fill"),
                PlantIssue(name: "Spider Mites", symptoms: "Fine webbing on undersides of leaves; tiny dots; stippled leaves", treatment: "Mist plants regularly. Wipe leaves with soapy water. Apply neem oil.", icon: "ladybug.fill"),
            ]

        case .flower:
            [
                PlantIssue(name: "No Blooms", symptoms: "Healthy foliage but no flower buds forming", treatment: "Switch to phosphorus-rich fertilizer. Ensure adequate sunlight (6+ hours). Avoid excess nitrogen.", icon: "camera.macro"),
                PlantIssue(name: "Black Spot", symptoms: "Dark circular spots on leaves with yellow halos (common on roses)", treatment: "Remove affected leaves. Apply fungicide. Avoid overhead watering. Improve air circulation.", icon: "circle.fill"),
                PlantIssue(name: "Slugs & Snails", symptoms: "Irregular holes in petals and leaves; slime trails visible", treatment: "Set beer traps. Apply diatomaceous earth around base. Hand-pick at dusk.", icon: "tortoise.fill"),
                PlantIssue(name: "Drooping Flowers", symptoms: "Blooms wilting prematurely or failing to open fully", treatment: "Check watering schedule. Deadhead spent blooms. Ensure proper nutrient balance.", icon: "arrow.down"),
                PlantIssue(name: "Leaf Burn", symptoms: "Brown crispy edges on leaves; bleached patches", treatment: "Provide afternoon shade. Increase watering frequency. Mulch to retain moisture.", icon: "flame.fill"),
            ]

        case .houseplant:
            [
                PlantIssue(name: "Brown Leaf Tips", symptoms: "Tips of leaves turning brown and crispy", treatment: "Increase humidity with a pebble tray or misting. Check for salt buildup; flush soil monthly.", icon: "leaf.fill"),
                PlantIssue(name: "Overwatering", symptoms: "Yellow leaves, mushy stems, fungus gnats in soil", treatment: "Let soil dry out between waterings. Ensure drainage holes. Reduce watering frequency.", icon: "drop.fill"),
                PlantIssue(name: "Low Light Stress", symptoms: "Pale leaves, leggy growth, dropping lower leaves", treatment: "Move closer to a window. Consider a grow light. Rotate plant quarterly for even growth.", icon: "sun.min.fill"),
                PlantIssue(name: "Pest Infestation", symptoms: "Sticky residue, white cottony masses, tiny moving dots on leaves", treatment: "Isolate affected plant. Wipe leaves with rubbing alcohol. Apply neem oil every 7 days.", icon: "ant.fill"),
                PlantIssue(name: "Root Bound", symptoms: "Roots growing out of drainage holes; water runs straight through", treatment: "Repot into a container 1-2 inches larger. Gently loosen root ball when transplanting.", icon: "square.stack"),
            ]

        case .fruit:
            [
                PlantIssue(name: "Fruit Drop", symptoms: "Immature fruits falling off before ripening", treatment: "Ensure consistent watering. Thin excess fruit to reduce stress. Check for pest damage.", icon: "arrow.down.circle"),
                PlantIssue(name: "Brown Rot", symptoms: "Soft brown spots on fruit that spread rapidly; fuzzy mold", treatment: "Remove affected fruit immediately. Apply copper fungicide. Improve air circulation.", icon: "circle.fill"),
                PlantIssue(name: "Nutrient Deficiency", symptoms: "Pale leaves, poor fruit set, small or misshapen fruit", treatment: "Apply fruit-specific fertilizer. Test soil pH. Add compost to improve soil nutrition.", icon: "leaf.arrow.circlepath"),
                PlantIssue(name: "Birds & Critters", symptoms: "Pecked or partially eaten fruit; bite marks", treatment: "Install bird netting. Use reflective tape as deterrent. Harvest promptly when ripe.", icon: "bird.fill"),
            ]

        case .succulent:
            [
                PlantIssue(name: "Etiolation", symptoms: "Stretching toward light; pale color; widely spaced leaves", treatment: "Gradually move to brighter location. Cannot reverse existing stretch; propagate top cutting.", icon: "arrow.up.right"),
                PlantIssue(name: "Overwatering", symptoms: "Translucent, mushy leaves; black stem at soil line", treatment: "Stop watering immediately. Remove from wet soil. Let dry completely before replanting.", icon: "drop.fill"),
                PlantIssue(name: "Sunburn", symptoms: "White or brown patches on leaves exposed to direct sun", treatment: "Move to indirect bright light. Introduce direct sun gradually over 2 weeks.", icon: "sun.max.fill"),
                PlantIssue(name: "Mealybugs", symptoms: "White cottony clusters in leaf joints; sticky residue", treatment: "Dab with rubbing alcohol on cotton swab. Spray with diluted isopropyl alcohol.", icon: "ant.fill"),
            ]

        case .tree, .shrub:
            [
                PlantIssue(name: "Leaf Scorch", symptoms: "Brown, crispy leaf margins; premature leaf drop", treatment: "Deep water during drought. Mulch to retain moisture. Protect from drying winds.", icon: "flame.fill"),
                PlantIssue(name: "Canker Disease", symptoms: "Sunken, discolored patches on bark; oozing sap", treatment: "Prune affected branches well below canker. Sterilize tools between cuts. Improve tree vigor.", icon: "bandage.fill"),
                PlantIssue(name: "Scale Insects", symptoms: "Small bumps on stems and leaves; sticky honeydew; sooty mold", treatment: "Scrape off with soft brush. Apply horticultural oil in dormant season. Release beneficial insects.", icon: "ant.fill"),
                PlantIssue(name: "Chlorosis", symptoms: "Leaves turning yellow with green veins remaining visible", treatment: "Often iron deficiency from alkaline soil. Apply chelated iron. Test and adjust soil pH.", icon: "leaf.fill"),
            ]
        }
    }
}

// MARK: - IssueCard

private struct IssueCard: View {
    let issue: PlantIssue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                IconBubble(
                    systemName: issue.icon,
                    color: CultivationTheme.Colors.statusWarning,
                    size: CultivationTheme.Spacing.iconSizeSmall,
                    iconSize: 14
                )

                Text(issue.name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        .frame(width: 16)
                    Text(issue.symptoms)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CultivationTheme.Colors.statusHealthy)
                        .frame(width: 16)
                    Text(issue.treatment)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }
            }
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .accessibilityIdentifier("issues_card_\(issue.name)")
    }
}
