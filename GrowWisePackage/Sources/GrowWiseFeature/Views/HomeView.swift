// HomeView: Main dashboard view composed of reusable components
// Components: WelcomeSection, StatsSection, WeatherSection, QuickActionsSection, CompactReminderRow
// Related Views: AddPlantSheet, RemindersListView

import SwiftUI
import SwiftData
import PhotosUI
import UserNotifications
import GrowWiseModels
import GrowWiseServices

public struct HomeView: View {
    @Environment(DataService.self) private var dataService
    @Environment(LocationService.self) private var locationService
    @Environment(NotificationService.self) private var notificationService
    
    @State private var gardeningStats = GardeningStats(totalPlants: 0, healthyPlants: 0, activeReminders: 0, totalJournalEntries: 0)
    @State private var upcomingReminders: [PlantReminder] = []
    @State private var recentJournalEntries: [JournalEntry] = []
    @State private var isLoading = true
    @State private var currentWeather: WeatherInfo?
    @State private var showingAddPlant = false
    @State private var photoService: PhotoService?
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Welcome Header
                    WelcomeSection()

                    // Quick Stats
                    StatsSection(stats: gardeningStats)

                    // Weather Widget
                    if let weather = currentWeather {
                        WeatherSection(weather: weather)
                    }

                    // Active Reminders
                    remindersSection

                    // Recent Journal Entries
                    recentJournalSection

                    // Quick Actions
                    QuickActionsSection(onActionTap: handleQuickAction)
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
            .task {
                await loadData()
                // Initialize PhotoService after DataService is available
                self.photoService = PhotoService(dataService: dataService)
            }
        }
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
                        CompactReminderRow(reminder: reminder)
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
                        if let photoService = photoService {
                            JournalEntryRow(entry: entry, photoService: photoService)
                        }
                    }
                }
            }
        }
    }
    
    private func handleQuickAction(_ action: QuickAction) {
        // TODO: Implement navigation for quick actions
        switch action {
        case .waterPlants:
            // Navigate to watering flow
            break
        case .addJournalEntry:
            // Navigate to journal entry creation
            break
        case .plantDatabase:
            // Navigate to plant database
            break
        case .myGarden:
            // Navigate to garden view
            break
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

#Preview {
    let dataService = try! DataService()
    let locationService = LocationService()
    let notificationService = NotificationService()

    HomeView()
        .environment(dataService)
        .environment(locationService)
        .environment(notificationService)
}
