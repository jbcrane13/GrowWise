import GrowWiseModels
import GrowWiseServices
import SwiftUI

/// A reusable stats section component that displays gardening statistics in a grid layout.
public struct StatsSection: View {
    let stats: GardeningStats

    public init(stats: GardeningStats) {
        self.stats = stats
    }

    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            StatCard(
                title: "Total Plants",
                value: "\(stats.totalPlants)",
                icon: "leaf.fill",
                color: .green
            )

            StatCard(
                title: "Healthy Plants",
                value: "\(stats.healthyPlants)",
                icon: "heart.fill",
                color: .pink
            )

            StatCard(
                title: "Active Reminders",
                value: "\(stats.activeReminders)",
                icon: "bell.fill",
                color: .orange
            )

            StatCard(
                title: "Journal Entries",
                value: "\(stats.totalJournalEntries)",
                icon: "book.fill",
                color: .blue
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Gardening statistics overview")
    }
}

/// A reusable stat card component for displaying individual statistics.
public struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityHint("Displays the number of \(title.lowercased())")
    }
}

#Preview {
    StatsSection(stats: GardeningStats(
        totalPlants: 12,
        healthyPlants: 10,
        activeReminders: 5,
        totalJournalEntries: 23
    ))
    .padding()
}
