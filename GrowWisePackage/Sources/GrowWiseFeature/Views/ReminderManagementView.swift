import SwiftUI
import GrowWiseModels
import GrowWiseServices

public struct ReminderManagementView: View {
    @StateObject private var reminderService: ReminderService
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var dataService: DataService
    
    @State private var selectedPlant: Plant?
    @State private var showingAddReminder = false
    @State private var showingReminderSettings = false
    @State private var reminderSettings: GrowWiseServices.ReminderSettings
    @State private var searchText = ""
    
    public init(dataService: DataService, notificationService: NotificationService) {
        let reminderService = ReminderService(dataService: dataService, notificationService: notificationService)
        self._reminderService = StateObject(wrappedValue: reminderService)
        self._dataService = StateObject(wrappedValue: dataService)
        self._reminderSettings = State(initialValue: reminderService.getReminderSettings())
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with settings button
                headerView
                
                // Quick stats
                statsCardView
                
                // Search bar
                SearchBarView(text: $searchText, placeholder: "Search reminders...")
                    .padding(.horizontal)
                
                // Reminder sections
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Today's reminders
                        todaysRemindersSection
                        
                        // Overdue reminders
                        overdueRemindersSection
                        
                        // Upcoming reminders
                        upcomingRemindersSection
                        
                        // All plants with reminders
                        allPlantsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Plant Reminders")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add Reminder", systemImage: "plus") {
                            showingAddReminder = true
                        }
                        
                        Button("Settings", systemImage: "gear") {
                            showingReminderSettings = true
                        }
                        
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            Task {
                                await refreshReminders()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddReminder) {
                AddReminderView(reminderService: reminderService, dataService: dataService)
            }
            .sheet(isPresented: $showingReminderSettings) {
                ReminderSettingsView(
                    reminderService: reminderService,
                    reminderSettings: $reminderSettings
                )
            }
            .onAppear {
                // NotificationService automatically checks authorization status
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Your Garden Care")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Stay on top of plant care")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Notification status indicator
            notificationStatusView
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private var notificationStatusView: some View {
        HStack(spacing: 4) {
            Image(systemName: notificationService.isEnabled ? "bell.fill" : "bell.slash")
                .foregroundColor(notificationService.isEnabled ? .green : .red)
                .font(.caption)
            
            Text(notificationService.isEnabled ? "On" : "Off")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(notificationService.isEnabled ? .green : .red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(notificationService.isEnabled ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        )
    }
    
    // MARK: - Stats Card View
    
    private var statsCardView: some View {
        HStack(spacing: 16) {
            ReminderStatCard(
                title: "Today",
                count: reminderService.getTodaysWateringReminders().count,
                icon: "drop.fill",
                color: .blue
            )
            
            ReminderStatCard(
                title: "Overdue",
                count: reminderService.getOverdueWateringReminders().count,
                icon: "exclamationmark.triangle.fill",
                color: .red
            )
            
            ReminderStatCard(
                title: "Total Plants",
                count: dataService.fetchPlants().count,
                icon: "leaf.fill",
                color: .green
            )
        }
        .padding()
    }
    
    // MARK: - Reminder Sections
    
    private var todaysRemindersSection: some View {
        ReminderSectionView(
            title: "Today's Care",
            icon: "calendar.circle",
            reminders: reminderService.getTodaysWateringReminders(),
            reminderService: reminderService,
            emptyMessage: "No care tasks for today"
        )
    }
    
    private var overdueRemindersSection: some View {
        let overdueReminders = reminderService.getOverdueWateringReminders()
        
        return Group {
            if !overdueReminders.isEmpty {
                ReminderSectionView(
                    title: "Overdue Care",
                    icon: "exclamationmark.triangle",
                    reminders: overdueReminders,
                    reminderService: reminderService,
                    emptyMessage: "No overdue tasks",
                    accentColor: .red
                )
            }
        }
    }
    
    private var upcomingRemindersSection: some View {
        let allReminders = reminderService.getWateringReminders()
        let upcomingReminders = allReminders.filter { 
            $0.nextDueDate > Date() && Calendar.current.isDate($0.nextDueDate, inSameDayAs: Date().addingTimeInterval(86400))
        }
        
        return Group {
            if !upcomingReminders.isEmpty {
                ReminderSectionView(
                    title: "Tomorrow",
                    icon: "calendar.badge.clock",
                    reminders: upcomingReminders,
                    reminderService: reminderService,
                    emptyMessage: "No tasks tomorrow",
                    accentColor: .orange
                )
            }
        }
    }
    
    private var allPlantsSection: some View {
        PlantReminderGridView(
            plants: filteredPlants,
            reminderService: reminderService,
            onPlantSelected: { plant in
                selectedPlant = plant
            }
        )
    }
    
    // MARK: - Helper Properties
    
    private var filteredPlants: [Plant] {
        let plants = dataService.fetchPlants()
        
        if searchText.isEmpty {
            return plants
        } else {
            return plants.filter { plant in
                (plant.name ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func refreshReminders() async {
        await notificationService.checkAuthorizationStatus()
        reminderSettings = reminderService.getReminderSettings()
    }
}

// MARK: - Supporting Views

struct ReminderStatCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct ReminderSectionView: View {
    let title: String
    let icon: String
    let reminders: [PlantReminder]
    let reminderService: ReminderService
    let emptyMessage: String
    let accentColor: Color
    
    init(
        title: String,
        icon: String,
        reminders: [PlantReminder],
        reminderService: ReminderService,
        emptyMessage: String,
        accentColor: Color = .blue
    ) {
        self.title = title
        self.icon = icon
        self.reminders = reminders
        self.reminderService = reminderService
        self.emptyMessage = emptyMessage
        self.accentColor = accentColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(accentColor)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(reminders.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
            }
            
            if reminders.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text(emptyMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    Spacer()
                }
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(reminders, id: \.id) { reminder in
                        ReminderRowView(
                            reminder: reminder,
                            reminderService: reminderService
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct PlantReminderGridView: View {
    let plants: [Plant]
    let reminderService: ReminderService
    let onPlantSelected: (Plant) -> Void
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
                
                Text("All Plants")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(plants, id: \.id) { plant in
                    PlantReminderCard(
                        plant: plant,
                        reminderService: reminderService,
                        onTap: { onPlantSelected(plant) }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    let dataService = try! DataService()
    let notificationService = NotificationService.shared
    
    ReminderManagementView(
        dataService: dataService,
        notificationService: notificationService
    )
}