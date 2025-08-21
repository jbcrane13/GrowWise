import SwiftUI
import SwiftData
import GrowWiseModels
import GrowWiseServices

public struct HomeView: View {
    @EnvironmentObject private var dataService: DataService
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var notificationService: NotificationService
    
    @State private var gardeningStats = GardeningStats(totalPlants: 0, healthyPlants: 0, activeReminders: 0, totalJournalEntries: 0)
    @State private var upcomingReminders: [PlantReminder] = []
    @State private var recentJournalEntries: [JournalEntry] = []
    @State private var isLoading = true
    @State private var currentWeather: WeatherInfo?
    @State private var showingAddPlant = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Welcome Header
                    welcomeSection
                    
                    // Quick Stats
                    statsSection
                    
                    // Weather Widget
                    if let weather = currentWeather {
                        weatherSection(weather)
                    }
                    
                    // Active Reminders
                    remindersSection
                    
                    // Recent Journal Entries
                    recentJournalSection
                    
                    // Quick Actions
                    quickActionsSection
                }
                .padding()
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Plant") {
                        showingAddPlant = true
                    }
                }
            }
            .sheet(isPresented: $showingAddPlant) {
                AddPlantSheet()
            }
            .refreshable {
                await refreshData()
            }
            .onAppear {
                Task {
                    await loadData()
                }
            }
        }
    }
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(welcomeMessage)
                .font(.title2)
                .fontWeight(.semibold)
            
            if let currentUser = dataService.getCurrentUser() {
                Text("Welcome back, \(currentUser.displayName)!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var statsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            StatCard(
                title: "Total Plants",
                value: "\(gardeningStats.totalPlants)",
                icon: "leaf.fill",
                color: .green
            )
            
            StatCard(
                title: "Healthy Plants",
                value: "\(gardeningStats.healthyPlants)",
                icon: "heart.fill",
                color: .pink
            )
            
            StatCard(
                title: "Active Reminders",
                value: "\(gardeningStats.activeReminders)",
                icon: "bell.fill",
                color: .orange
            )
            
            StatCard(
                title: "Journal Entries",
                value: "\(gardeningStats.totalJournalEntries)",
                icon: "book.fill",
                color: .blue
            )
        }
    }
    
    private func weatherSection(_ weather: WeatherInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: weather.iconName)
                    .foregroundColor(.blue)
                Text("Today's Weather")
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("\(Int(weather.temperature))°F")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text(weather.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Label("Humidity: \(Int(weather.humidity))%", systemImage: "drop.fill")
                        .font(.caption)
                    Label("UV Index: \(weather.uvIndex)", systemImage: "sun.max.fill")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            if weather.isGoodForGardening {
                Label("Great day for gardening!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Tasks")
                    .font(.headline)
                Spacer()
                if !upcomingReminders.isEmpty {
                    NavigationLink("View All") {
                        RemindersListView()
                    }
                    .font(.caption)
                }
            }
            
            if upcomingReminders.isEmpty {
                Text("No tasks for today - great job keeping up with your plants!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(upcomingReminders.prefix(3)), id: \.id) { reminder in
                        HomeReminderRowView(reminder: reminder)
                    }
                }
            }
        }
    }
    
    private var recentJournalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                NavigationLink("View All") {
                    JournalView()
                }
                .font(.caption)
            }
            
            if recentJournalEntries.isEmpty {
                Text("Start documenting your plant journey!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(recentJournalEntries.prefix(3)), id: \.id) { entry in
                        JournalEntryRow(entry: entry, photoService: PhotoService(dataService: try! DataService()))
                    }
                }
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickActionButton(
                    icon: "drop.fill",
                    label: "Water Plants",
                    color: .blue
                ) {
                    // Navigate to watering flow
                }
                
                QuickActionButton(
                    icon: "book.fill",
                    label: "Add Journal Entry",
                    color: .green
                ) {
                    // Navigate to journal entry creation
                }
                
                QuickActionButton(
                    icon: "books.vertical.fill",
                    label: "Plant Database",
                    color: .orange
                ) {
                    // Navigate to plant database
                }
                
                QuickActionButton(
                    icon: "leaf.fill",
                    label: "My Garden",
                    color: .mint
                ) {
                    // Navigate to garden view
                }
            }
        }
    }
    
    private var welcomeMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Night"
        }
    }
    
    @MainActor
    private func loadData() async {
        isLoading = true
        
        // Load stats
        gardeningStats = dataService.getGardeningStats()
        
        // Load reminders
        upcomingReminders = dataService.fetchActiveReminders()
        
        // Load recent journal entries
        recentJournalEntries = dataService.fetchRecentJournalEntries(limit: 5)
        
        // Load weather if location available
        if locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways,
           let _ = locationService.currentLocation {
            // In a real app, you'd call a weather API here
            currentWeather = WeatherInfo.sample
        }
        
        isLoading = false
    }
    
    @MainActor
    private func refreshData() async {
        await loadData()
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HomeReminderRowView: View {
    let reminder: PlantReminder
    
    var body: some View {
        HStack {
            Image(systemName: reminder.reminderType.iconName)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let plant = reminder.plant {
                    Text(plant.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(reminder.nextDueDate, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// Duplicate declarations removed - these are already defined in PlantCardView.swift

struct AddPlantSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Add Plant functionality will be implemented")
                    .padding()
                Spacer()
            }
            .navigationTitle("Add Plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RemindersListView: View {
    var body: some View {
        VStack {
            Text("Full reminders list will be implemented")
                .padding()
            Spacer()
        }
        .navigationTitle("All Reminders")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Weather Support

struct WeatherInfo {
    let temperature: Double
    let humidity: Double
    let uvIndex: Int
    let description: String
    let iconName: String
    let isGoodForGardening: Bool
    
    static let sample = WeatherInfo(
        temperature: 72,
        humidity: 65,
        uvIndex: 6,
        description: "Partly Cloudy",
        iconName: "cloud.sun.fill",
        isGoodForGardening: true
    )
}

#Preview {
    HomeView()
        .environmentObject(try! DataService())
        .environmentObject(LocationService.shared)
        .environmentObject(NotificationService.shared)
}