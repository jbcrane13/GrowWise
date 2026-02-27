# GROWWISEFEATURE/COMPONENTS KNOWLEDGE BASE

## OVERVIEW
Shared UI utilities and modular dashboard sections for the GrowWise app.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Plant Display | `PlantCardView.swift`, `PlantReminderCard.swift` | Core data display components |
| Dashboard Modules | `WelcomeSection.swift`, `StatsSection.swift`, `WeatherSection.swift` | HomeView specific sections |
| List Rows | `CompactReminderRow.swift`, `ReminderRowView.swift` | Reusable list items |
| Search | `SearchBarView.swift` | Reusable search utility |
| Quick Actions | `QuickActionsSection.swift` | Dashboard action buttons |
| Stats | `StatsSection.swift` | Garden statistics display |

## CONVENTIONS
- **Statelessness**: Components should be stateless where possible, receiving data via parameters. Avoid `@State` unless managing purely internal UI state (e.g., animation toggles).
- **Strict MV Logic**: Components must not contain business logic; they should only handle presentation. No data fetching or complex transformations.
- **Service Access**: Use `@Environment` only for global services (e.g., `DataService`) if absolutely necessary. Prefer passing data down from parent Views.
- **Accessibility**: Mandatory `.accessibilityIdentifier()` and `.accessibilityLabel()` on all interactive elements. Use semantic labels for icons.
- **Previews**: Every component must include a `#Preview` block with mock data to ensure visual consistency.
- **Layout**: Use `VStack` and `HStack` with explicit spacing to maintain consistent padding across the app.

## ANTI-PATTERNS
- **ValidatedTextField Layer Violation**: `ValidatedTextField` is currently defined in `GrowWiseServices/ValidationService.swift`. This is a major layer violation; UI components must reside in `GrowWiseFeature`.
- **Color Theme Inconsistency**: Avoid hardcoding colors (e.g., `.foregroundColor(.blue)`). Use semantic colors (`.primary`, `.secondary`) or project-specific theme extensions in `Color+Theme.swift`.
- **Logic in Components**: Do not perform data fetching or complex transformations inside components; use `DataTransformationService` or pass pre-processed data.
- **Direct Model Mutation**: Components should never mutate `@Model` objects directly; use `DataService` methods to ensure persistence and CloudKit sync.
- **Hardcoded Strings**: Avoid hardcoding user-facing strings; use localized strings where possible (though currently mostly hardcoded in this project).
- **Massive Components**: If a component exceeds 150 lines, break it down into smaller sub-components.
