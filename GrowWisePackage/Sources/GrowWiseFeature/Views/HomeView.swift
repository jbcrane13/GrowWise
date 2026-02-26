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
    @Environment(PhotoService.self) private var photoService
    @Environment(CloudSyncService.self) private var cloudSyncService
    
    @State private var gardeningStats = GardeningStats(totalPlants: 0, healthyPlants: 0, activeReminders: 0, totalJournalEntries: 0)
    @State private var upcomingReminders: [PlantReminder] = []
    @State private var recentJournalEntries: [JournalEntry] = []
    @State private var isLoading = true
    @State private var currentWeather: WeatherInfo?
    @State private var showingAddPlant = false
    @State private var showingCreateGarden = false
    @State private var showGardenCreatedToast = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Welcome Header
                    WelcomeSection()
                    
                    if dataService.getGardenCount() == 0 {
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "leaf.fill").foregroundColor(.green)
                                Text("No gardens yet")
                                    .font(.headline)
                            }
                            Text("Create your first garden to start organizing your plants")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Create Garden") {
                                showingCreateGarden = true
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityLabel("Create your first garden")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Quick Stats
                    StatsSection(stats: gardeningStats)

                    // Weather Widget
                    weatherSection

                    syncStatusSection

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
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Plant") {
                        showingAddPlant = true
                    }
                }
            }
            .sheet(isPresented: $showingAddPlant) {
                AddPlantSheet()
            }
            .sheet(isPresented: $showingCreateGarden) {
                CreateGardenSheet()
            }
            .refreshable {
                await refreshData()
            }
            .task {
                await loadData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GardenCreated"))) { _ in
            showGardenCreatedToast = true
        }
        .overlay(alignment: .bottom) {
            if showGardenCreatedToast {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("Garden created! Add your first plant.")
                    Spacer()
                    Button("Add Plant") {
                        showGardenCreatedToast = false
                        showingAddPlant = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    withAnimation { showGardenCreatedToast = false }
                }
            }
        }
    }

    @ViewBuilder
    private var weatherSection: some View {
        if let weather = currentWeather {
            WeatherSection(weather: weather)
        } else if locationService.isLoading {
            HStack(spacing: 12) {
                ProgressView()
                Text("Fetching weather…")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .accessibilityIdentifier("weather_loading")
        } else if let locationError = locationService.error {
            HStack(spacing: 12) {
                Image(systemName: "cloud.slash.fill")
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weather unavailable")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(locationError.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .accessibilityIdentifier("weather_error")
        } else if !locationService.hasLocationPermission {
            HStack(spacing: 12) {
                Image(systemName: "location.slash.fill")
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weather unavailable")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Enable location access to see local weather.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .accessibilityIdentifier("weather_no_permission")
        }
    }

    private var syncStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: cloudSyncService.isSyncing ? "arrow.triangle.2.circlepath" : "icloud")
                Text("iCloud Sync")
                    .font(.headline)
                Spacer()
                if cloudSyncService.isSyncing {
                    Text("Syncing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            if let error = cloudSyncService.lastErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if let lastSyncDate = cloudSyncService.lastSyncDate {
                Text("Last synced: \(lastSyncDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .accessibilityIdentifier("homeCloudSyncSection")
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
                        JournalEntryRow(entry: entry, photoService: photoService)
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
        
        if ProcessInfo.processInfo.arguments.contains("--uitesting-mock-weather") {
            currentWeather = WeatherInfo.sample
        } else if locationService.hasLocationPermission {
            if locationService.currentLocation == nil {
                locationService.requestLocation()
            }
            await locationService.fetchWeatherData()
            if let weatherData = locationService.weatherData {
                currentWeather = mapWeatherData(weatherData)
            }
        }

        await cloudSyncService.refreshStatus()
        
        isLoading = false
    }
    
    @MainActor
    private func refreshData() async {
        await loadData()
    }

    private func mapWeatherData(_ weatherData: WeatherData) -> WeatherInfo {
        let temperatureF = weatherData.current.temperature.converted(to: .fahrenheit).value
        let humidityPercent = weatherData.current.humidity * 100
        let uvValue = Int(weatherData.current.uvIndex.value)
        let description = String(describing: weatherData.current.condition)
        let iconName = weatherData.current.symbolName
        let gardeningFriendly = temperatureF >= 45 && temperatureF <= 90 && uvValue <= 8

        return WeatherInfo(
            temperature: temperatureF,
            humidity: humidityPercent,
            uvIndex: uvValue,
            description: description,
            iconName: iconName,
            isGoodForGardening: gardeningFriendly
        )
    }
}

#Preview {
    let dataService = try! DataService()
    let locationService = LocationService()
    let photoService = PhotoService(dataService: dataService)
    let cloudSyncService = CloudSyncService()

    HomeView()
        .environment(dataService)
        .environment(locationService)
        .environment(photoService)
        .environment(cloudSyncService)
}
