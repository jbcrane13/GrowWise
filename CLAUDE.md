# GrowWise - iOS Gardening App

## Project Overview

GrowWise is a SwiftUI-based iOS gardening application that helps users manage their gardens, track plant care, and monitor growth progress.

## Technology Stack

- **Platform**: iOS 18+
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Data Persistence**: SwiftData
- **Concurrency**: Swift Async/Await
- **Testing**: XCTest, XCUITest

## Project Structure

```
GrowWise/
├── GrowWise/              # Main app target
│   ├── Views/            # SwiftUI views
│   ├── Models/           # SwiftData models
│   ├── ViewModels/       # View models and business logic
│   └── Services/         # API and data services
├── GrowWisePackage/       # Swift Package with shared code
├── GrowWiseUITests/       # UI tests
├── tests/                 # Unit tests
├── docs/                  # Documentation
└── scripts/               # Build and utility scripts
```

## File Organization Rules

**NEVER save working files to the root folder. Use these directories:**
- `/GrowWise/` - Swift source code files
- `/tests/` - Test files
- `/docs/` - Documentation and markdown files
- `/scripts/` - Utility scripts
- `/config/` - Configuration files

## Code Style & Best Practices

### Swift/SwiftUI Standards
- Use `@Observable` instead of `ObservableObject`
- Use SwiftData for persistence (not CoreData)
- Use async/await for concurrency (not DispatchQueue)
- All interactive UI elements must have `.accessibilityIdentifier()`
- Follow modern iOS 18+ patterns

### Architecture
- **Modular Design**: Keep files focused and under 500 lines
- **Clean Architecture**: Separate views, view models, models, and services
- **Environment Safety**: Never hardcode secrets or API keys
- **Test-First**: Write tests before implementation (TDD)

### Accessibility Requirements

Every interactive element MUST have an accessibility identifier following this pattern:
```swift
// Pattern: {screen}_{element}_{descriptor}
Button("Save") { }
    .accessibilityIdentifier("settings_button_save")

TextField("Name", text: $name)
    .accessibilityIdentifier("profile_textfield_name")

Toggle("Notifications", isOn: $enabled)
    .accessibilityIdentifier("settings_toggle_notifications")

// List items include unique ID
ForEach(plants) { plant in
    PlantRow(plant: plant)
        .accessibilityIdentifier("garden_cell_plant_\(plant.id)")
}
```

## Development Workflow

### Starting New Features
1. Review requirements and user stories
2. Plan the implementation approach
3. Write failing tests first (TDD)
4. Implement minimal code to pass tests
5. Refactor while keeping tests green
6. Request code review before completion

### Quality Gates (Before Commit)
- [ ] All tests passing
- [ ] No legacy Swift patterns (`ObservableObject`, `@Published`, `CoreData`, etc.)
- [ ] All interactive UI has accessibility identifiers
- [ ] Build succeeds with zero warnings
- [ ] Code reviewed and approved

## Common Commands

### Build & Test
```bash
# Build the app
xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -configuration Debug build

# Run unit tests
xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWise -destination 'platform=iOS Simulator,name=iPhone 15' test

# Run UI tests
xcodebuild -workspace GrowWise.xcworkspace -scheme GrowWiseUITests -destination 'platform=iOS Simulator,name=iPhone 15' test
```

### Simulator Management
```bash
# List available simulators
xcrun simctl list devices

# Boot a simulator
xcrun simctl boot "iPhone 15"

# Install app on simulator
xcrun simctl install booted /path/to/GrowWise.app
```

## Important Reminders

- **File Creation**: NEVER create files unless absolutely necessary
- **Editing First**: ALWAYS prefer editing existing files to creating new ones
- **No Documentation Sprawl**: NEVER proactively create documentation files (*.md) or README files unless explicitly requested
- **Organized Files**: Never save working files, text/mds and tests to the root folder
- **Do What's Asked**: Nothing more, nothing less

## Resources

- [Swift Documentation](https://swift.org/documentation/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/ios)
