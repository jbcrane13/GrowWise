# GrowWise Accessibility Implementation Guide

## Overview

This guide provides comprehensive accessibility implementation guidelines for the GrowWise iOS gardening app, ensuring the app is usable by gardeners with diverse abilities and needs.

## 1. Accessibility Foundation Principles

### Universal Design Goals
- **Perceivable**: Information and UI components must be presentable in ways users can perceive
- **Operable**: UI components and navigation must be operable by all users
- **Understandable**: Information and operation of the UI must be understandable
- **Robust**: Content must be robust enough for interpretation by assistive technologies

### iOS Accessibility Standards
- Full VoiceOver support for screen readers
- Dynamic Type support for text scaling
- Voice Control compatibility for hands-free operation
- Switch Control support for alternative input methods
- Reduce Motion respect for vestibular disorders
- High Contrast mode support for visual impairments

## 2. VoiceOver Implementation

### Core VoiceOver Patterns

#### Plant Card Accessibility
```swift
struct PlantCard: View {
    let plant: Plant
    
    var body: some View {
        VStack(alignment: .leading) {
            PlantImageView(plant: plant)
            Text(plant.name)
            DifficultyBadge(level: plant.difficultyLevel)
            HealthStatusIndicator(status: plant.healthStatus)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(plantAccessibilityLabel)
        .accessibilityHint("Tap to view plant details and care instructions")
        .accessibilityAction(.activate) {
            navigateToPlantDetail()
        }
        .accessibilityAction(named: "Quick water") {
            performQuickWatering()
        }
        .accessibilityAction(named: "View journal") {
            navigateToJournal()
        }
    }
    
    private var plantAccessibilityLabel: String {
        var components: [String] = []
        
        // Plant name and type
        components.append(plant.name)
        components.append(plant.plantType.displayName)
        
        // Difficulty level
        components.append("\(plant.difficultyLevel.displayName) difficulty")
        
        // Health status with context
        components.append("Health status: \(plant.healthStatus.displayName)")
        
        // Care urgency
        if let nextWatering = plant.nextWateringDate {
            let daysUntilWatering = Calendar.current.dateComponents([.day], from: Date(), to: nextWatering).day ?? 0
            if daysUntilWatering <= 0 {
                components.append("Needs watering now")
            } else if daysUntilWatering == 1 {
                components.append("Needs watering tomorrow")
            } else {
                components.append("Needs watering in \(daysUntilWatering) days")
            }
        }
        
        // Growth stage if relevant
        if plant.isUserPlant {
            components.append("Growth stage: \(plant.growthStage.displayName)")
        }
        
        return components.joined(separator: ", ")
    }
}
```

#### Reminder List Accessibility
```swift
struct ReminderRow: View {
    let reminder: PlantReminder
    @State private var isCompleted = false
    
    var body: some View {
        HStack {
            PlantThumbnail(plant: reminder.plant)
            ReminderDetails(reminder: reminder)
            CompletionButton(isCompleted: $isCompleted)
        }
        .accessibilityElement(children: .ignore) // Custom accessibility
        .accessibilityLabel(reminderAccessibilityLabel)
        .accessibilityValue(reminderAccessibilityValue)
        .accessibilityHint(reminderAccessibilityHint)
        .accessibilityAction(.activate) {
            completeReminder()
        }
        .accessibilityAction(named: "Edit reminder") {
            editReminder()
        }
        .accessibilityAction(named: "Postpone 1 hour") {
            postponeReminder(hours: 1)
        }
        .accessibilityAction(named: "View plant") {
            navigateToPlant()
        }
    }
    
    private var reminderAccessibilityLabel: String {
        var label = reminder.title
        
        if let plant = reminder.plant {
            label += " for \(plant.name)"
        }
        
        // Time context
        let timeDescription: String
        if reminder.isOverdue {
            let overdueDays = Calendar.current.dateComponents([.day], from: reminder.scheduledDate, to: Date()).day ?? 0
            timeDescription = overdueDays == 0 ? "overdue today" : "overdue by \(overdueDays) days"
        } else {
            timeDescription = "scheduled \(reminder.scheduledDate.formatted(.relative(presentation: .named)))"
        }
        label += ", \(timeDescription)"
        
        return label
    }
    
    private var reminderAccessibilityValue: String {
        isCompleted ? "Completed" : "Not completed"
    }
    
    private var reminderAccessibilityHint: String {
        if isCompleted {
            return "Reminder has been marked as complete"
        } else {
            return "Tap to mark as complete, or use actions to edit or postpone"
        }
    }
}
```

#### Journal Entry Accessibility
```swift
struct JournalEntryCard: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading) {
            EntryHeader(entry: entry)
            PhotoGallery(photoURLs: entry.photoURLs)
            EntryContent(entry: entry)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entryAccessibilityLabel)
        .accessibilityHint("Tap to view full journal entry")
        .accessibilityAction(.activate) {
            navigateToFullEntry()
        }
        .accessibilityAction(named: "View photos") {
            showPhotoGallery()
        }
        .accessibilityAction(named: "Edit entry") {
            editEntry()
        }
    }
    
    private var entryAccessibilityLabel: String {
        var components: [String] = []
        
        // Entry title and date
        let title = entry.title.isEmpty ? "Journal entry" : entry.title
        components.append(title)
        components.append("from \(entry.date.formatted(date: .abbreviated, time: .omitted))")
        
        // Associated plant
        if let plant = entry.plant {
            components.append("for \(plant.name)")
        }
        
        // Photo count
        if !entry.photoURLs.isEmpty {
            let photoText = entry.photoURLs.count == 1 ? "1 photo" : "\(entry.photoURLs.count) photos"
            components.append(photoText)
        }
        
        // Growth stage or notable content
        if let growthStage = entry.growthStage {
            components.append("Growth stage: \(growthStage.displayName)")
        }
        
        // Content preview
        if !entry.notes.isEmpty {
            let preview = String(entry.notes.prefix(100))
            components.append("Notes: \(preview)")
        }
        
        return components.joined(separator: ", ")
    }
}
```

### VoiceOver Navigation Patterns

#### Header Navigation
```swift
struct SectionHeaderView: View {
    let title: String
    let subtitle: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headerAccessibilityLabel)
        .accessibilityAddTraits(.isHeader)
    }
    
    private var headerAccessibilityLabel: String {
        if let subtitle = subtitle {
            return "\(title), \(subtitle)"
        }
        return title
    }
}
```

#### Skip Navigation
```swift
struct MainContentView: View {
    @FocusState private var skipToContentFocus: Bool
    
    var body: some View {
        VStack {
            // Skip to content button (hidden visually)
            Button("Skip to main content") {
                skipToContentFocus = true
            }
            .accessibilityHidden(false)
            .opacity(0)
            .allowsHitTesting(false)
            
            NavigationHeader()
            
            ScrollView {
                LazyVStack {
                    MainContent()
                }
                .focused($skipToContentFocus)
            }
            
            TabBar()
        }
    }
}
```

## 3. Dynamic Type Implementation

### Text Scaling Support
```swift
struct ScalableText: View {
    let text: String
    let style: Font.TextStyle
    let maxScale: CGFloat
    
    var body: some View {
        Text(text)
            .font(.system(style))
            .dynamicTypeSize(...DynamicTypeSize.accessibility3) // Limit extreme scaling
            .minimumScaleFactor(0.8) // Allow slight compression if needed
            .lineLimit(nil) // Allow text wrapping
    }
}

// Custom font with Dynamic Type support
extension Font {
    static func customGardening(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .rounded)
    }
    
    static var gardeningTitle: Font {
        .customGardening(28, weight: .bold)
    }
    
    static var gardeningBody: Font {
        .customGardening(16)
    }
    
    static var gardeningCaption: Font {
        .customGardening(12)
    }
}
```

### Layout Adaptation for Text Scaling
```swift
struct AdaptiveLayoutView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        Group {
            if dynamicTypeSize >= .accessibility1 {
                // Large text: use vertical layout
                VStack(alignment: .leading, spacing: 12) {
                    PlantImageView(plant: plant)
                        .frame(maxHeight: 200)
                    PlantInfoView(plant: plant)
                }
            } else {
                // Normal text: use horizontal layout
                HStack(spacing: 16) {
                    PlantImageView(plant: plant)
                        .frame(width: 120, height: 120)
                    PlantInfoView(plant: plant)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: dynamicTypeSize)
    }
}

struct ResponsiveGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var gridColumns: [GridItem] {
        let columnCount: Int
        switch dynamicTypeSize {
        case .xSmall, .small, .medium:
            columnCount = 3
        case .large, .xLarge, .xxLarge:
            columnCount = 2
        default: // Accessibility sizes
            columnCount = 1
        }
        
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)
    }
    
    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(plants) { plant in
                PlantCard(plant: plant)
            }
        }
    }
}
```

## 4. Color and Contrast Implementation

### Semantic Color System
```swift
extension Color {
    // Plant health status colors with high contrast support
    static var plantHealthy: Color {
        Color("PlantHealthy") // Defined in asset catalog with variants
    }
    
    static var plantNeedsAttention: Color {
        Color("PlantNeedsAttention")
    }
    
    static var plantSick: Color {
        Color("PlantSick")
    }
    
    static var plantCritical: Color {
        Color("PlantCritical")
    }
    
    // Adaptive background colors
    static var cardBackground: Color {
        Color(UIColor.systemBackground)
    }
    
    static var secondaryBackground: Color {
        Color(UIColor.secondarySystemBackground)
    }
}

// High contrast mode detection
struct HighContrastAwareView: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    var body: some View {
        PlantStatusIndicator(status: plant.healthStatus)
            .background(
                reduceTransparency ? 
                .regularMaterial : 
                .ultraThinMaterial
            )
    }
}
```

### Color-Independent Information Display
```swift
struct PlantStatusIndicator: View {
    let status: HealthStatus
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    
    var body: some View {
        HStack(spacing: 6) {
            // Always show icon for color-independent recognition
            Image(systemName: status.iconName)
                .foregroundStyle(differentiateWithoutColor ? .primary : status.color)
            
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(differentiateWithoutColor ? .primary : status.color)
            
            // Additional visual indicator for differentiation
            if differentiateWithoutColor {
                status.patternView
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(differentiateWithoutColor ? .quaternary : status.color.opacity(0.2))
        )
        .overlay(
            Capsule()
                .stroke(differentiateWithoutColor ? .secondary : status.color.opacity(0.5), lineWidth: 1)
        )
    }
}

extension HealthStatus {
    var iconName: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        case .sick: return "cross.circle.fill"
        case .dying: return "x.circle.fill"
        case .dead: return "minus.circle.fill"
        }
    }
    
    @ViewBuilder
    var patternView: some View {
        switch self {
        case .healthy:
            Circle()
                .fill(.green)
                .frame(width: 6, height: 6)
        case .needsAttention:
            Triangle()
                .fill(.orange)
                .frame(width: 8, height: 8)
        case .sick:
            Rectangle()
                .fill(.red)
                .frame(width: 6, height: 6)
        case .dying:
            Crosshatch()
                .stroke(.red, lineWidth: 1)
                .frame(width: 8, height: 8)
        case .dead:
            Circle()
                .stroke(.gray, lineWidth: 2)
                .frame(width: 6, height: 6)
        }
    }
}
```

## 5. Voice Control Support

### Voice Control Optimization
```swift
struct VoiceControlOptimizedButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel(title)
        .accessibilityIdentifier(title.lowercased().replacingOccurrences(of: " ", with: "_"))
        // Voice Control will automatically number this button
        // User can say "Tap [number]" or "Tap \(title)"
    }
}

struct VoiceControlGrid: View {
    let plants: [Plant]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2)) {
            ForEach(Array(plants.enumerated()), id: \.element.id) { index, plant in
                PlantCard(plant: plant)
                    .accessibilityLabel("\(plant.name) plant card")
                    .accessibilityIdentifier("plant_card_\(index + 1)")
                    // Voice Control: "Tap plant card 1", "Tap tomato plant card"
            }
        }
    }
}
```

## 6. Switch Control Support

### Focus Management
```swift
struct SwitchControlOptimizedView: View {
    @FocusState private var focusedField: FocusedField?
    @State private var groupIndex = 0
    
    enum FocusedField {
        case plantName
        case plantType
        case notes
        case saveButton
    }
    
    var body: some View {
        Form {
            Section("Plant Information") {
                TextField("Plant Name", text: $plantName)
                    .focused($focusedField, equals: .plantName)
                    .accessibilityLabel("Plant name")
                
                Picker("Plant Type", selection: $selectedType) {
                    ForEach(PlantType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .focused($focusedField, equals: .plantType)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Plant information section")
            
            Section("Notes") {
                TextEditor(text: $notes)
                    .focused($focusedField, equals: .notes)
                    .frame(minHeight: 100)
                    .accessibilityLabel("Plant notes")
            }
            
            Section {
                Button("Save Plant") {
                    savePlant()
                }
                .focused($focusedField, equals: .saveButton)
                .accessibilityLabel("Save plant to garden")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape) {
            // Allow switch control users to dismiss
            dismiss()
        }
    }
}
```

## 7. Reduce Motion Support

### Motion-Sensitive Animations
```swift
struct MotionAwareView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            Button("Toggle Details") {
                if reduceMotion {
                    isExpanded.toggle()
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }
            }
            
            if isExpanded {
                PlantDetailsView()
                    .transition(
                        reduceMotion ? 
                        .identity : 
                        .slide.combined(with: .opacity)
                    )
            }
        }
    }
}

struct ReducedMotionCarousel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentIndex = 0
    
    var body: some View {
        VStack {
            TabView(selection: $currentIndex) {
                ForEach(0..<plants.count, id: \.self) { index in
                    PlantCard(plant: plants[index])
                        .tag(index)
                }
            }
            .tabViewStyle(
                reduceMotion ? 
                .automatic : 
                .page(indexDisplayMode: .always)
            )
            .animation(
                reduceMotion ? .none : .easeInOut, 
                value: currentIndex
            )
            
            // Alternative navigation for reduced motion
            if reduceMotion {
                HStack {
                    Button("Previous") {
                        if currentIndex > 0 {
                            currentIndex -= 1
                        }
                    }
                    .disabled(currentIndex == 0)
                    
                    Spacer()
                    
                    Text("Plant \(currentIndex + 1) of \(plants.count)")
                        .font(.caption)
                    
                    Spacer()
                    
                    Button("Next") {
                        if currentIndex < plants.count - 1 {
                            currentIndex += 1
                        }
                    }
                    .disabled(currentIndex == plants.count - 1)
                }
                .padding()
            }
        }
    }
}
```

## 8. Testing and Validation

### Accessibility Testing Checklist

#### VoiceOver Testing
- [ ] All interactive elements are accessible
- [ ] Reading order is logical and meaningful
- [ ] Grouped elements read as cohesive information
- [ ] Custom actions are available and functional
- [ ] Images have appropriate alt text or are marked decorative
- [ ] Status updates are announced appropriately

#### Dynamic Type Testing
- [ ] Text scales appropriately across all size categories
- [ ] Layouts adapt to larger text sizes
- [ ] Information remains accessible at maximum sizes
- [ ] Interactive elements maintain proper touch targets
- [ ] Critical information is never truncated

#### Color and Contrast Testing
- [ ] All text meets WCAG AA contrast requirements (4.5:1 for normal text)
- [ ] Large text meets WCAG AA requirements (3:1 for 18pt+ text)
- [ ] Color is not the only way to convey information
- [ ] High contrast mode is properly supported
- [ ] Focus indicators are clearly visible

#### Motor Accessibility Testing
- [ ] Touch targets are at least 44x44 points
- [ ] Switch control navigation is logical
- [ ] Voice control commands work reliably
- [ ] Alternative input methods are supported
- [ ] Timeout periods are sufficient or adjustable

### Automated Testing Implementation
```swift
// XCTest accessibility testing
func testPlantCardAccessibility() {
    let app = XCUIApplication()
    app.launch()
    
    let plantCard = app.buttons["Tomato plant card"]
    XCTAssertTrue(plantCard.exists)
    XCTAssertTrue(plantCard.isHittable)
    
    // Test accessibility label
    let expectedLabel = "Tomato, Vegetable, Beginner difficulty, Health status: Healthy, Needs watering in 2 days, Growth stage: Flowering"
    XCTAssertEqual(plantCard.label, expectedLabel)
    
    // Test custom actions
    XCTAssertTrue(plantCard.customActions.contains { $0.name == "Quick water" })
    XCTAssertTrue(plantCard.customActions.contains { $0.name == "View journal" })
}

func testDynamicTypeSupport() {
    let app = XCUIApplication()
    
    // Test with different text sizes
    let textSizes: [UIContentSizeCategory] = [
        .small, .medium, .large, .extraLarge, 
        .accessibilityMedium, .accessibilityExtraLarge
    ]
    
    for textSize in textSizes {
        app.launchArguments.append("-UIPreferredContentSizeCategory")
        app.launchArguments.append(textSize.rawValue)
        app.launch()
        
        // Verify key elements are still accessible and readable
        let plantCard = app.buttons.firstMatch
        XCTAssertTrue(plantCard.exists)
        XCTAssertTrue(plantCard.isHittable)
        
        app.terminate()
    }
}
```

### Accessibility Audit Tools
```swift
// Custom accessibility audit helpers
struct AccessibilityAudit {
    static func auditView(_ view: some View) -> [AccessibilityIssue] {
        var issues: [AccessibilityIssue] = []
        
        // Check for missing accessibility labels
        // Check for appropriate traits
        // Check for logical focus order
        // Check for sufficient contrast
        
        return issues
    }
}

struct AccessibilityIssue {
    let severity: Severity
    let description: String
    let suggestion: String
    
    enum Severity {
        case error      // Blocks accessibility
        case warning    // Impacts usability
        case suggestion // Enhancement opportunity
    }
}
```

## 9. Accessibility Settings Integration

### Respecting User Preferences
```swift
struct AccessibilityPreferences: ObservableObject {
    @Published var isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
    @Published var isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
    @Published var isDifferentiateWithoutColorEnabled = UIAccessibility.shouldDifferentiateWithoutColor
    @Published var isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
    @Published var isSwitchControlEnabled = UIAccessibility.isSwitchControlRunning
    @Published var isVoiceControlEnabled = UIAccessibility.isVoiceControlRunning
    
    init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        }
        
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        }
        
        // Add other accessibility preference observers...
    }
}
```

## 10. Implementation Priorities

### Phase 1: Foundation (Weeks 1-2)
- VoiceOver support for core navigation
- Basic Dynamic Type implementation
- Semantic color system setup
- Touch target size compliance

### Phase 2: Content Accessibility (Weeks 3-4)
- Plant card accessibility optimization
- Reminder list VoiceOver support
- Journal entry accessibility
- Image alt text implementation

### Phase 3: Advanced Features (Weeks 5-6)
- Custom VoiceOver actions
- Switch Control optimization
- Voice Control command support
- Reduce Motion adaptations

### Phase 4: Testing and Refinement (Weeks 7-8)
- Comprehensive accessibility testing
- User testing with assistive technology users
- Performance optimization
- Documentation and training

This accessibility implementation guide ensures that GrowWise will be usable by gardeners with diverse abilities, following iOS accessibility best practices and exceeding basic compliance requirements.