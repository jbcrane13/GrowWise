# GROWWISEFEATURE/VIEWS KNOWLEDGE BASE

## OVERVIEW
Main SwiftUI screens for GrowWise, mapped to the TabView layout (Home, My Garden, Plant Guide, Journal, Learn).

## STRUCTURE
```
Views/
├── Journal/             # Journal-specific lists, details, and entry forms
├── Tutorials/           # Tutorial progress and display screens
├── HomeView.swift       # Dashboard tab with stats/reminders
├── MyGardenView.swift   # Garden & plant management
└── PlantDatabaseView.swift # Plant reference guide
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Reminders UI | `RemindersListView.swift`, `AddReminderView.swift`, `ReminderManagementView.swift` |
| Plant UI | `AddPlantSheet.swift`, `PlantDatabaseView.swift` |
| Dashboard UI | `HomeView.swift` | Composed of modular sections |

## CONVENTIONS
- Views access services directly via `@Environment` (e.g. `@Environment(DataService.self)`).
- Data Loading: Use `.task { await loadData() }` and `.refreshable { await refreshData() }`.
- Scrollable lists must use `LazyVStack` to preserve memory.
- Fetch limits prefix dashboard views (3-5 items with "View All").
- Sheets use `@State private var showingSheet = false` with `.sheet(isPresented:)`.

## ANTI-PATTERNS
- **NEVER** initialize services locally in views; always use Environment.
- **DO NOT** implement complex data transformations here; push to `DataTransformationService`.
