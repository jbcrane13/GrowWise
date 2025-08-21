import SwiftUI

/// Simple test view to validate deployment without SwiftData/CloudKit dependencies
public struct TestAppView: View {
    @State private var selectedTab = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            VStack(spacing: 20) {
                Text("🌱 GrowWise")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Welcome to your gardening companion!")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                        Text("Track your plants")
                    }
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text("Set care reminders")
                    }
                    
                    HStack {
                        Image(systemName: "book.pages")
                            .foregroundColor(.orange)
                        Text("Keep a garden journal")
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)
            
            // My Garden Tab
            VStack(spacing: 15) {
                Text("My Garden")
                    .font(.title)
                    .fontWeight(.bold)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 15) {
                    ForEach(mockPlants, id: \.name) { plant in
                        TestPlantCardView(plant: plant)
                    }
                }
                .padding()
                
                Spacer()
            }
            .tabItem {
                Image(systemName: "leaf.fill")
                Text("My Garden")
            }
            .tag(1)
            
            // Plant Guide Tab
            NavigationView {
                List(mockPlantDatabase, id: \.name) { plant in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(plant.name)
                                .font(.headline)
                            Text(plant.type.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(plant.difficulty)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(difficultyColor(plant.difficulty))
                            .cornerRadius(8)
                    }
                }
                .navigationTitle("Plant Guide")
            }
            .tabItem {
                Image(systemName: "books.vertical.fill")
                Text("Plant Guide")
            }
            .tag(2)
            
            // Journal Tab
            VStack(spacing: 15) {
                Text("Garden Journal")
                    .font(.title)
                    .fontWeight(.bold)
                
                List(mockJournalEntries, id: \.title) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.title)
                            .font(.headline)
                        Text(entry.content)
                            .font(.body)
                            .foregroundColor(.secondary)
                        Text(entry.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .tabItem {
                Image(systemName: "book.pages.fill")
                Text("Journal")
            }
            .tag(3)
            
            // Tutorials Tab
            VStack(spacing: 15) {
                Text("Learn & Grow")
                    .font(.title)
                    .fontWeight(.bold)
                
                List(mockTutorials, id: \.title) { tutorial in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(tutorial.title)
                                .font(.headline)
                            Text(tutorial.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tabItem {
                Image(systemName: "graduationcap.fill")
                Text("Learn")
            }
            .tag(4)
        }
    }
    
    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "beginner": return .green
        case "intermediate": return .orange
        case "advanced": return .red
        default: return .gray
        }
    }
}

struct TestPlantCardView: View {
    let plant: MockPlant
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plant.emoji)
                .font(.largeTitle)
            
            Text(plant.name)
                .font(.headline)
            
            Text(plant.status)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Mock Data

struct MockPlant {
    let name: String
    let emoji: String
    let status: String
}

struct MockPlantData {
    let name: String
    let type: String
    let difficulty: String
}

struct MockJournalEntry {
    let title: String
    let content: String
    let date: Date
}

struct MockTutorial {
    let title: String
    let description: String
}

private let mockPlants = [
    MockPlant(name: "Basil", emoji: "🌿", status: "Healthy"),
    MockPlant(name: "Tomato", emoji: "🍅", status: "Growing"),
    MockPlant(name: "Rose", emoji: "🌹", status: "Blooming"),
    MockPlant(name: "Mint", emoji: "🌱", status: "Healthy")
]

private let mockPlantDatabase = [
    MockPlantData(name: "Basil", type: "herb", difficulty: "Beginner"),
    MockPlantData(name: "Tomato", type: "vegetable", difficulty: "Intermediate"),
    MockPlantData(name: "Rose", type: "flower", difficulty: "Advanced"),
    MockPlantData(name: "Mint", type: "herb", difficulty: "Beginner"),
    MockPlantData(name: "Lettuce", type: "vegetable", difficulty: "Beginner"),
    MockPlantData(name: "Lavender", type: "herb", difficulty: "Intermediate")
]

private let mockJournalEntries = [
    MockJournalEntry(
        title: "First Planting Day",
        content: "Planted my first herbs today! Excited to start this gardening journey.",
        date: Date().addingTimeInterval(-86400 * 7)
    ),
    MockJournalEntry(
        title: "Watering Schedule",
        content: "Set up a consistent watering schedule. Plants are responding well.",
        date: Date().addingTimeInterval(-86400 * 3)
    ),
    MockJournalEntry(
        title: "First Harvest",
        content: "Harvested fresh basil for dinner. Nothing beats home-grown herbs!",
        date: Date().addingTimeInterval(-86400)
    )
]

private let mockTutorials = [
    MockTutorial(
        title: "Getting Started with Herbs",
        description: "Learn the basics of growing herbs at home"
    ),
    MockTutorial(
        title: "Watering Best Practices",
        description: "Master the art of proper plant watering"
    ),
    MockTutorial(
        title: "Soil Preparation",
        description: "Prepare the perfect soil for your plants"
    ),
    MockTutorial(
        title: "Pest Control",
        description: "Natural ways to protect your garden"
    )
]

#Preview {
    TestAppView()
}