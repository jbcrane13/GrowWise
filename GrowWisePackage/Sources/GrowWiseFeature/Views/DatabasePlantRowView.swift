import SwiftUI
import GrowWiseModels
import GrowWiseServices

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
                            colors: [Color.green.opacity(0.3), Color.mint.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 50, height: 50)

                    Image(systemName: plantTypeIcon)
                        .font(.title3)
                        .foregroundColor(.green)
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
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var plantTypeIcon: String {
        switch plant.plantType {
        case .vegetable: return "carrot.fill"
        case .herb: return "leaf.fill"
        case .flower: return "rosette"
        case .houseplant: return "house.fill"
        case .fruit: return "apple.whole.fill"
        case .succulent: return "circle.grid.3x3.fill"
        case .tree: return "tree.fill"
        case .shrub: return "leaf.circle.fill"
        case .none: return "questionmark.circle.fill"
        }
    }
}
