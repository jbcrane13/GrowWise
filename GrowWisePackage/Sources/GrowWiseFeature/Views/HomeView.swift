import SwiftUI
import SwiftData
import PhotosUI
import UserNotifications
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
                        CompactReminderRowView(reminder: reminder)
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

struct CompactReminderRowView: View {
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
                    Text(plant.name ?? "Unknown Plant")
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
    @EnvironmentObject private var dataService: DataService
    
    // Form fields
    @State private var plantName = ""
    @State private var scientificName = ""
    @State private var selectedPlantType = PlantType.vegetable
    @State private var selectedDifficultyLevel = DifficultyLevel.beginner
    @State private var plantingDate = Date()
    @State private var notes = ""
    @State private var selectedGarden: Garden?
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoURLs: [String] = []
    
    // UI state
    @State private var availableGardens: [Garden] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information Section
                Section("Basic Information") {
                    TextField("Plant Name", text: $plantName)
                        .autocorrectionDisabled()
                    
                    TextField("Scientific Name (Optional)", text: $scientificName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                // Plant Type and Difficulty Section
                Section("Plant Details") {
                    Picker("Plant Type", selection: $selectedPlantType) {
                        ForEach(PlantType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Picker("Difficulty Level", selection: $selectedDifficultyLevel) {
                        ForEach(DifficultyLevel.allCases, id: \.self) { level in
                            HStack {
                                Text(level.displayName)
                                Spacer()
                                Text("(\(level.description))")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .tag(level)
                        }
                    }
                }
                
                // Planting Information Section
                Section("Planting Information") {
                    DatePicker("Planting Date", selection: $plantingDate, displayedComponents: .date)
                    
                    if !availableGardens.isEmpty {
                        Picker("Garden", selection: $selectedGarden) {
                            Text("No Garden Selected").tag(nil as Garden?)
                            ForEach(availableGardens, id: \.id) { garden in
                                Text(garden.name ?? "Unnamed Garden").tag(garden as Garden?)
                            }
                        }
                    }
                }
                
                // Notes Section
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                // Photo Section
                Section("Photos") {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 5,
                        matching: .images
                    ) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Add Photos")
                        }
                        .foregroundColor(.blue)
                    }
                    
                    if !selectedPhotos.isEmpty {
                        Text("\(selectedPhotos.count) photo(s) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await savePlant()
                        }
                    }
                    .disabled(plantName.isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                loadGardens()
            }
        }
    }
    
    private func loadGardens() {
        availableGardens = dataService.fetchGardens()
    }
    
    @MainActor
    private func savePlant() async {
        guard !plantName.isEmpty else { return }
        
        isSaving = true
        
        do {
            // Process selected photos (in a real app, you'd save these to persistent storage)
            var processedPhotoURLs: [String] = []
            for item in selectedPhotos {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    // In a real implementation, you'd save this to your photo service
                    // For now, we'll create a placeholder URL
                    let photoURL = "photo_\(UUID().uuidString)"
                    processedPhotoURLs.append(photoURL)
                }
            }
            
            // Create the plant using DataService
            let plant = try dataService.createPlant(
                name: plantName,
                type: selectedPlantType,
                difficultyLevel: selectedDifficultyLevel,
                garden: selectedGarden
            )
            
            // Update additional plant properties
            plant.scientificName = scientificName.isEmpty ? nil : scientificName
            plant.plantingDate = plantingDate
            plant.notes = notes.isEmpty ? nil : notes
            plant.photoURLs = processedPhotoURLs
            
            // Save the updated plant
            try dataService.updatePlant(plant)
            
            dismiss()
            
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
            isSaving = false
        }
    }
}

struct RemindersListView: View {
    @EnvironmentObject private var dataService: DataService
    @EnvironmentObject private var notificationService: NotificationService
    
    @State private var reminders: [PlantReminder] = []
    @State private var isLoading = false
    @State private var selectedReminder: PlantReminder?
    @State private var showingDeleteAlert = false
    @State private var reminderToDelete: PlantReminder?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading reminders...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if reminders.isEmpty {
                emptyStateView
            } else {
                remindersList
            }
        }
        .navigationTitle("All Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadReminders()
        }
        .onAppear {
            Task {
                await loadReminders()
            }
        }
        .alert("Delete Reminder", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let reminder = reminderToDelete {
                    deleteReminder(reminder)
                }
            }
        } message: {
            Text("Are you sure you want to delete this reminder? This action cannot be undone.")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Reminders")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("You don't have any plant reminders set up yet. Create some reminders to stay on top of your plant care schedule!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var remindersList: some View {
        List {
            ForEach(groupedReminders.keys.sorted(), id: \.self) { dateGroup in
                Section(dateGroup) {
                    ForEach(groupedReminders[dateGroup] ?? [], id: \.id) { reminder in
                        HomeReminderRowView(
                            reminder: reminder,
                            onComplete: {
                                completeReminder(reminder)
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                reminderToDelete = reminder
                                showingDeleteAlert = true
                            }
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private var groupedReminders: [String: [PlantReminder]] {
        let calendar = Calendar.current
        let today = Date()
        
        var groups: [String: [PlantReminder]] = [:]
        
        for reminder in reminders {
            let dateGroup: String
            let reminderDate = reminder.nextDueDate
            
            if calendar.isDateInToday(reminderDate) {
                dateGroup = "Today"
            } else if calendar.isDateInTomorrow(reminderDate) {
                dateGroup = "Tomorrow"
            } else if calendar.dateInterval(of: .weekOfYear, for: today)?.contains(reminderDate) == true {
                dateGroup = "This Week"
            } else {
                dateGroup = "Later"
            }
            
            if groups[dateGroup] == nil {
                groups[dateGroup] = []
            }
            groups[dateGroup]?.append(reminder)
        }
        
        // Sort reminders within each group by due date
        for key in groups.keys {
            groups[key]?.sort { $0.nextDueDate < $1.nextDueDate }
        }
        
        return groups
    }
    
    @MainActor
    private func loadReminders() async {
        isLoading = true
        
        // Use dataService methods to fetch reminders
        let allActiveReminders = dataService.fetchActiveReminders()
        let upcomingReminders = dataService.fetchUpcomingReminders(days: 365) // Get all reminders within a year
        
        // Combine and deduplicate based on ID
        var reminderIds = Set<UUID>()
        var uniqueReminders: [PlantReminder] = []
        
        for reminder in allActiveReminders + upcomingReminders {
            if !reminderIds.contains(reminder.id) {
                reminderIds.insert(reminder.id)
                uniqueReminders.append(reminder)
            }
        }
        
        reminders = uniqueReminders.sorted { $0.nextDueDate < $1.nextDueDate }
        
        isLoading = false
    }
    
    private func completeReminder(_ reminder: PlantReminder) {
        do {
            try dataService.completeReminder(reminder)
            Task {
                await loadReminders()
            }
            
            // Update notification service if needed
            if let notificationId = reminder.notificationIdentifier {
                Task {
                    await notificationService.cancelNotification(with: notificationId)
                    
                    // If it's a recurring reminder, schedule the next notification
                    if reminder.isRecurring {
                        await scheduleNotificationForReminder(reminder)
                    }
                }
            }
        } catch {
            print("Error completing reminder: \(error)")
        }
    }
    
    private func deleteReminder(_ reminder: PlantReminder) {
        // Cancel associated notification
        if let notificationId = reminder.notificationIdentifier {
            Task {
                await notificationService.cancelNotification(with: notificationId)
            }
        }
        
        // Delete reminder using DataService
        do {
            try dataService.deleteReminder(reminder)
            Task {
                await loadReminders()
            }
        } catch {
            print("Error deleting reminder: \(error)")
        }
        
        reminderToDelete = nil
    }
    
    private func scheduleNotificationForReminder(_ reminder: PlantReminder) async {
        guard notificationService.isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.message
        content.sound = .default
        content.badge = NSNumber(value: notificationService.badgeCount + 1)
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.nextDueDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: reminder.notificationIdentifier ?? UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error scheduling notification: \(error)")
        }
    }
}

// MARK: - Home Reminder Row View

struct HomeReminderRowView: View {
    let reminder: PlantReminder
    let onComplete: () -> Void
    
    @State private var isCompleted = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion checkbox
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCompleted = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onComplete()
                }
            }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isCompleted ? .green : .gray)
                    .animation(.easeInOut(duration: 0.2), value: isCompleted)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Reminder type icon
            Image(systemName: reminder.reminderType.iconName)
                .font(.title3)
                .foregroundColor(priorityColor)
                .frame(width: 24)
            
            // Reminder details
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let plantName = reminder.plant?.name {
                    Text(plantName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text(dueDateText)
                        .font(.caption)
                        .foregroundColor(dueDateColor)
                    
                    if reminder.priority != .medium {
                        Text("• \(reminder.priority.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Due date
            VStack(alignment: .trailing, spacing: 2) {
                Text(reminder.nextDueDate, style: .time)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if !Calendar.current.isDateInToday(reminder.nextDueDate) {
                    Text(reminder.nextDueDate, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(isCompleted ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isCompleted)
    }
    
    private var priorityColor: Color {
        switch reminder.priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    private var dueDateText: String {
        let calendar = Calendar.current
        let now = Date()
        let dueDate = reminder.nextDueDate
        
        if dueDate < now {
            return "Overdue"
        } else if calendar.isDateInToday(dueDate) {
            return "Due today"
        } else if calendar.isDateInTomorrow(dueDate) {
            return "Due tomorrow"
        } else {
            let days = calendar.dateComponents([.day], from: now, to: dueDate).day ?? 0
            if days <= 7 {
                return "Due in \(days) day\(days == 1 ? "" : "s")"
            } else {
                return "Due \(dueDate.formatted(date: .abbreviated, time: .omitted))"
            }
        }
    }
    
    private var dueDateColor: Color {
        let now = Date()
        let dueDate = reminder.nextDueDate
        
        if dueDate < now {
            return .red
        } else if Calendar.current.isDateInToday(dueDate) {
            return .orange
        } else {
            return .secondary
        }
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