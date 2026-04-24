import GrowWiseModels
import SwiftUI

struct PlantTypeBadge: View {
    let type: PlantType

    var body: some View {
        Text(type.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(CultivationTheme.Colors.accentSky.opacity(0.15))
            .foregroundColor(CultivationTheme.Colors.accentSky)
            .clipShape(RoundedRectangle(cornerRadius: 4))
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
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var backgroundColor: Color {
        switch level {
        case .beginner: CultivationTheme.Colors.statusHealthy
        case .intermediate: CultivationTheme.Colors.statusWarning
        case .advanced: CultivationTheme.Colors.statusAlert
        }
    }
}
