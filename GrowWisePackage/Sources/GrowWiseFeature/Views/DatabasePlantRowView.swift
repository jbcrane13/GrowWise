import GrowWiseModels
import GrowWiseServices
import SwiftUI

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable line_length

// MARK: - Database Plant Row View

struct DatabasePlantRowView: View {
    let plant: Plant
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Plant icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [CultivationTheme.Colors.brandLeaf.opacity(0.15), CultivationTheme.Colors.brandMint.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 50, height: 50)

                    Image(systemName: plantTypeIcon)
                        .font(.title3)
                        .foregroundColor(CultivationTheme.Colors.brandLeaf)
                }

                // Plant info
                VStack(alignment: .leading, spacing: 4) {
                    Text(plant.name ?? "Unknown Plant")
                        .font(.headline)
                        .multilineTextAlignment(.leading)

                    if let scientificName = plant.scientificName, !scientificName.isEmpty {
                        Text(scientificName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }

                    HStack(spacing: 8) {
                        if let plantType = plant.plantType {
                            PlantTypeBadge(type: plantType)
                        }
                        if let difficultyLevel = plant.difficultyLevel {
                            DifficultyBadge(level: difficultyLevel)
                        }
                        Spacer()
                    }

                    if let notes = plant.notes, !notes.isEmpty {
                        Text(notes.prefix(100) + (notes.count > 100 ? "..." : ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(CultivationTheme.Colors.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: CultivationTheme.Radius.card))
            .shadow(color: CultivationTheme.Colors.brandForest.opacity(0.06), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var accessibilityIdentifier: String {
        "database_plant_row_\(plant.id?.uuidString ?? accessibilityFallbackSuffix)"
    }

    private var accessibilityFallbackSuffix: String {
        let components = [plant.name, plant.scientificName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: "_") }
        let fallback = components.joined(separator: "_")
        return fallback.isEmpty ? "unknown" : fallback
    }

    private var plantTypeIcon: String {
        switch plant.plantType {
        case .vegetable: "carrot.fill"
        case .herb: "leaf.fill"
        case .flower: "rosette"
        case .houseplant: "house.fill"
        case .fruit: "apple.whole.fill"
        case .succulent: "circle.grid.3x3.fill"
        case .tree: "tree.fill"
        case .shrub: "leaf.circle.fill"
        case .none: "questionmark.circle.fill"
        }
    }
}

// swiftlint:enable line_length
