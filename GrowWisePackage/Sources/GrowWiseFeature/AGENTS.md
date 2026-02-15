# GrowWiseFeature - Agent Instructions

## Purpose

SwiftUI view layer providing all user-facing screens. Depends on both `GrowWiseModels` and `GrowWiseServices`. Views access services via `@Environment` injection.

## Navigation Structure

The app uses a **TabView** with 5 tabs (defined in `MainAppView.swift`):

| Tab | View | Icon | Description |
|-----|------|------|-------------|
| Home | `HomeView` | house.fill | Dashboard with stats, reminders, weather, journal |
| My Garden | `MyGardenView` | leaf.fill | User's gardens and plants |
| Plant Guide | `PlantDatabaseView` | books.vertical.fill | Reference plant database with search/filter |
| Journal | `JournalView` | book.pages.fill | Plant journal entries |
| Learn | `TutorialsView` | graduationcap.fill | Gardening tutorials |

## File Organization

```
Main/
  MainAppView.swift          # Root view, tab navigation, DataService async init

Views/
  HomeView.swift             # Dashboard tab (composes WelcomeSection, StatsSection, etc.)
  MyGardenView.swift         # Garden management, plant listing
  PlantDatabaseView.swift    # Reference plant database with search/filter
  AddPlantSheet.swift        # Sheet for adding plants to garden
  AddReminderView.swift      # Reminder creation form
  RemindersListView.swift    # Full reminders list
  ReminderManagementView.swift  # Reminder editing
  ReminderSettingsView.swift # Reminder preferences
  PlantReminderDetailView.swift # Single reminder detail
  NotificationSettingsView.swift # Notification preferences
  ErrorView.swift            # Error display with retry
  TutorialData.swift         # Tutorial content definitions
  TutorialsView.swift        # Tutorials tab entry

  Journal/
    JournalView.swift        # Journal tab entry
    JournalEntryRow.swift    # Journal list cell
    JournalEntryDetailView.swift  # Full entry view
    AddJournalEntryView.swift    # New entry form

  Tutorials/
    TutorialView.swift       # Individual tutorial display
    TutorialDetailView.swift # Detailed tutorial content
    TutorialProgressView.swift  # Progress tracking

Components/
  WelcomeSection.swift       # Home welcome header
  StatsSection.swift         # Dashboard statistics cards
  WeatherSection.swift       # Weather widget
  QuickActionsSection.swift  # Quick action buttons
  PlantCardView.swift        # Plant display card
  PlantReminderCard.swift    # Reminder card in lists
  CompactReminderRow.swift   # Compact reminder row for dashboard
  ReminderRowView.swift      # Standard reminder list row
  SearchBarView.swift        # Reusable search bar

OnboardingFlow/
  OnboardingView.swift       # Onboarding coordinator
  Views/
    WelcomeStepView.swift    # Welcome screen
    SkillAssessmentView.swift  # Skill level selection
    GardeningGoalsView.swift # Goal selection
    LocationSetupView.swift  # Location permissions
    NotificationPermissionView.swift  # Notification permissions
    CompletionView.swift     # Onboarding complete
    OnboardingNavigationView.swift  # Navigation controls
    OnboardingProgressView.swift    # Step progress indicator
  Extensions/
    Color+Theme.swift        # Theme color definitions

ContentView.swift            # Test entry point (shows OnboardingView)
TestAppView.swift            # Development test view
```

## Key Patterns

### Service Access
```swift
@Environment(DataService.self) private var dataService
@Environment(LocationService.self) private var locationService
@Environment(NotificationService.self) private var notificationService
@Environment(PerformanceMonitor.self) private var performanceMonitor
```

### Data Loading
Views use `.task { await loadData() }` for async data loading and `.refreshable { await refreshData() }` for pull-to-refresh.

### Onboarding
Onboarding status stored in `UserDefaults` key `"hasCompletedOnboarding"`. `MainAppView` checks this before showing the main tab interface.

### MainAppView Initialization
`MainAppView` handles async `DataService` initialization with:
- Loading state with progress indicator
- Fallback mode detection (high memory delta)
- Error recovery with retry
- Background cache warming after init

## Critical Rules

1. **Always access DataService via `@Environment`** - never create instances directly in views.
2. **Use `LazyVStack`** for scrollable lists to prevent loading all items into memory.
3. **Prefix fetch limits**: Dashboard views should limit to 3-5 items with "View All" links.
4. **`#Preview` macros**: Include previews with mock service injection for development.
5. **Accessibility**: Include `.accessibilityLabel()` on interactive elements.
6. **Sheet pattern**: Use `@State private var showingSheet = false` + `.sheet(isPresented:)`.

## Adding a New View

1. Create in `Views/` (or appropriate subdirectory)
2. Mark as `public struct` with `public init() {}`
3. Access services via `@Environment`
4. Add navigation from parent view (tab, NavigationLink, or sheet)
5. Include a `#Preview` block
