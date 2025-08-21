import SwiftUI
import GrowWiseModels

public struct PlantCardView: View {
    let plant: Plant
    @State private var showingMoreInfo = false
    
    public init(plant: Plant) {
        self.plant = plant
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with plant photo placeholder and health status
            headerSection
            
            // Plant info
            plantInfoSection
            
            // Care indicators
            careIndicatorsSection
            
            // Quick actions
            quickActionsSection
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var headerSection: some View {
        HStack {
            // Plant photo placeholder
            plantImagePlaceholder
            
            Spacer()
            
            // Health status badge
            HealthStatusBadge(status: plant.healthStatus)
        }
    }
    
    private var plantImagePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [Color.green.opacity(0.3), Color.mint.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 60, height: 60)
            
            Image(systemName: plantTypeIcon)
                .font(.title2)
                .foregroundColor(.green)
        }
    }
    
    private var plantInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plant.name)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            if let scientificName = plant.scientificName, !scientificName.isEmpty {
                Text(scientificName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .lineLimit(1)
            }
            
            HStack(spacing: 8) {
                PlantTypeBadge(type: plant.plantType)
                DifficultyBadge(level: plant.difficultyLevel)
                Spacer()
            }
        }
    }
    
    private var careIndicatorsSection: some View {
        HStack(spacing: 16) {
            CareIndicator(
                icon: "drop.fill",
                color: .blue,
                status: wateringStatus,
                label: "Water"
            )
            
            CareIndicator(
                icon: "sun.max.fill",
                color: .yellow,
                status: sunlightStatus,
                label: "Light"
            )
            
            CareIndicator(
                icon: "leaf.fill",
                color: .green,
                status: growthStatus,
                label: "Growth"
            )
        }
    }
    
    private var quickActionsSection: some View {
        HStack(spacing: 8) {
            QuickActionButton(
                icon: "drop.fill",
                label: "Water",
                color: .blue
            ) {
                // Handle watering action
            }
            
            QuickActionButton(
                icon: "note.text",
                label: "Note",
                color: .orange
            ) {
                // Handle add note action
            }
            
            Spacer()
            
            Button(action: { showingMoreInfo = true }) {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Computed Properties
    
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
        }
    }
    
    private var wateringStatus: CareStatus {
        guard let lastWatered = plant.lastWatered else {
            return .overdue
        }
        
        let daysSinceWatering = Calendar.current.dateComponents([.day], from: lastWatered, to: Date()).day ?? 0
        let wateringInterval = plant.wateringFrequency.days
        
        if daysSinceWatering >= wateringInterval + 1 {
            return .overdue
        } else if daysSinceWatering >= wateringInterval {
            return .due
        } else {
            return .good
        }
    }
    
    private var sunlightStatus: CareStatus {
        // In a real app, this would check if the plant is getting appropriate sunlight
        // For now, we'll return good status
        return .good
    }
    
    private var growthStatus: CareStatus {
        switch plant.healthStatus {
        case .healthy: return .good
        case .needsAttention: return .due
        case .sick, .dying: return .overdue
        case .dead: return .overdue
        }
    }
}

// MARK: - Supporting Views

struct HealthStatusBadge: View {
    let status: HealthStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(status.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .healthy: return .green
        case .needsAttention: return .yellow
        case .sick: return .orange
        case .dying: return .red
        case .dead: return .gray
        }
    }
}

struct CareIndicator: View {
    let icon: String
    let color: Color
    let status: CareStatus
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(statusBackgroundColor)
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(statusForegroundColor)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusBackgroundColor: Color {
        switch status {
        case .good: return color.opacity(0.2)
        case .due: return Color.yellow.opacity(0.2)
        case .overdue: return Color.red.opacity(0.2)
        }
    }
    
    private var statusForegroundColor: Color {
        switch status {
        case .good: return color
        case .due: return .yellow
        case .overdue: return .red
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PlantTypeBadge: View {
    let type: PlantType
    
    var body: some View {
        Text(type.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue.opacity(0.2))
            .foregroundColor(.blue)
            .cornerRadius(4)
    }
}

struct DifficultyBadge: View {
    let level: DifficultyLevel
    
    var body: some View {
        Text(level.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
    
    private var backgroundColor: Color {
        switch level {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}

// MARK: - Supporting Types

enum CareStatus {
    case good
    case due
    case overdue
}

#Preview {
    VStack(spacing: 16) {
        PlantCardView(plant: Plant(
            name: "Tomato",
            plantType: .vegetable,
            difficultyLevel: .intermediate
        ))
        
        PlantCardView(plant: Plant(
            name: "Spider Plant",
            plantType: .houseplant,
            difficultyLevel: .beginner
        ))
    }
    .padding()
}