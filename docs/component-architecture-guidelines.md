# GrowWise Component Architecture Guidelines

## Overview

This document provides detailed guidelines for building reusable SwiftUI components for the GrowWise gardening app, based on research findings and iOS 17+ best practices.

## 1. Core Component Structure

### Base Component Pattern
```swift
// Protocol for consistent component behavior
protocol GrowWiseComponent: View {
    associatedtype Configuration
    var configuration: Configuration { get set }
}

// Base styling protocol
protocol ComponentStyling {
    var cornerRadius: CGFloat { get }
    var shadowRadius: CGFloat { get }
    var backgroundColor: Color { get }
}
```

### Standard Configuration
```swift
struct ComponentConfig: ComponentStyling {
    var cornerRadius: CGFloat = 12
    var shadowRadius: CGFloat = 2
    var backgroundColor: Color = .systemBackground
    var spacing: CGFloat = 8
    var padding: EdgeInsets = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
}
```

## 2. Plant-Related Components

### PlantCard Component
```swift
struct PlantCard: View {
    let plant: Plant
    let style: PlantCardStyle
    let onTap: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Plant Image
            PlantImageView(
                imageURL: plant.primaryImageURL,
                size: style.imageSize,
                cornerRadius: style.cornerRadius
            )
            
            // Plant Info
            VStack(alignment: .leading, spacing: 4) {
                Text(plant.name)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                HStack(spacing: 8) {
                    DifficultyBadge(level: plant.difficultyLevel)
                    Spacer()
                    if plant.isUserPlant {
                        HealthStatusIndicator(status: plant.healthStatus)
                    }
                }
            }
            .padding(.horizontal, style.contentPadding)
            .padding(.bottom, style.contentPadding)
        }
        .background(style.backgroundColor, in: RoundedRectangle(cornerRadius: style.cornerRadius))
        .shadow(radius: style.shadowRadius)
        .onTapGesture {
            onTap?()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(plantCardAccessibilityLabel)
        .accessibilityHint("Tap to view plant details")
        .accessibilityAction(.activate) {
            onTap?()
        }
    }
    
    private var plantCardAccessibilityLabel: String {
        var label = plant.name
        label += ", \(plant.difficultyLevel.displayName) difficulty"
        
        if plant.isUserPlant {
            label += ", \(plant.healthStatus.displayName) health"
            if let lastWatered = plant.lastWatered {
                let daysSinceWatering = Calendar.current.dateComponents([.day], from: lastWatered, to: Date()).day ?? 0
                label += ", last watered \(daysSinceWatering) days ago"
            }
        }
        
        return label
    }
}

enum PlantCardStyle {
    case compact
    case standard
    case featured
    
    var imageSize: CGSize {
        switch self {
        case .compact: return CGSize(width: 80, height: 80)
        case .standard: return CGSize(width: 120, height: 120)
        case .featured: return CGSize(width: 200, height: 150)
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .compact: return 8
        case .standard, .featured: return 12
        }
    }
    
    var contentPadding: CGFloat {
        switch self {
        case .compact: return 8
        case .standard: return 12
        case .featured: return 16
        }
    }
    
    var backgroundColor: Color { .systemBackground }
    var shadowRadius: CGFloat { 2 }
}
```

### PlantImageView Component
```swift
struct PlantImageView: View {
    let imageURL: URL?
    let size: CGSize
    let cornerRadius: CGFloat
    
    var body: some View {
        AsyncImage(url: imageURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            PlantImagePlaceholder()
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(.quaternary, lineWidth: 0.5)
        )
        .accessibilityHidden(true) // Image is decorative, info provided by parent
    }
}

struct PlantImagePlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .overlay {
                Image(systemName: "leaf")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
            }
    }
}
```

### DifficultyBadge Component
```swift
struct DifficultyBadge: View {
    let level: DifficultyLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.iconName)
                .font(.caption2)
            Text(level.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(level.backgroundColor, in: Capsule())
        .foregroundStyle(level.foregroundColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(level.displayName) difficulty level")
    }
}

extension DifficultyLevel {
    var iconName: String {
        switch self {
        case .beginner: return "leaf"
        case .intermediate: return "leaf.fill"
        case .advanced: return "tree"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .beginner: return .green.opacity(0.2)
        case .intermediate: return .orange.opacity(0.2)
        case .advanced: return .red.opacity(0.2)
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}
```

### HealthStatusIndicator Component
```swift
struct HealthStatusIndicator: View {
    let status: HealthStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text(status.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Plant health: \(status.displayName)")
    }
}

extension HealthStatus {
    var color: Color {
        switch self {
        case .healthy: return .green
        case .needsAttention: return .yellow
        case .sick: return .orange
        case .dying: return .red
        case .dead: return .gray
        }
    }
}
```

## 3. Care & Reminder Components

### CareReminderRow Component
```swift
struct CareReminderRow: View {
    let reminder: PlantReminder
    @State private var isCompleted = false
    let onComplete: (PlantReminder) -> Void
    let onEdit: (PlantReminder) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Plant thumbnail
            PlantImageView(
                imageURL: reminder.plant?.primaryImageURL,
                size: CGSize(width: 50, height: 50),
                cornerRadius: 8
            )
            
            // Reminder details
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let plant = reminder.plant {
                    Text(plant.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text(reminder.scheduledDate, style: .relative)
                        .font(.caption)
                        .foregroundStyle(reminder.isOverdue ? .red : .tertiary)
                    
                    if reminder.isOverdue {
                        Text("• Overdue")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fontWeight(.medium)
                    }
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button {
                    onEdit(reminder)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Edit reminder")
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCompleted = true
                    }
                    onComplete(reminder)
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isCompleted ? .green : .secondary)
                }
                .accessibilityLabel(isCompleted ? "Reminder completed" : "Mark reminder as complete")
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reminderAccessibilityLabel)
        .accessibilityAction(named: "Complete") {
            onComplete(reminder)
        }
        .accessibilityAction(named: "Edit") {
            onEdit(reminder)
        }
    }
    
    private var reminderAccessibilityLabel: String {
        var label = reminder.title
        if let plant = reminder.plant {
            label += " for \(plant.name)"
        }
        label += ", scheduled \(reminder.scheduledDate.formatted(.relative(presentation: .named)))"
        if reminder.isOverdue {
            label += ", overdue"
        }
        return label
    }
}
```

### CareActionButton Component
```swift
struct CareActionButton: View {
    let action: CareAction
    let isEnabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: action.iconName)
                    .font(.title2)
                    .foregroundStyle(isEnabled ? action.color : .secondary)
                
                Text(action.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isEnabled ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? action.color.opacity(0.1) : .quaternary.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isEnabled ? action.color.opacity(0.3) : .quaternary, lineWidth: 1)
            )
        }
        .disabled(!isEnabled)
        .accessibilityLabel(action.accessibilityLabel)
        .accessibilityHint(isEnabled ? "Tap to \(action.title.lowercased())" : "Action not available")
    }
}

enum CareAction: CaseIterable {
    case water
    case fertilize
    case prune
    case repot
    
    var title: String {
        switch self {
        case .water: return "Water"
        case .fertilize: return "Fertilize"
        case .prune: return "Prune"
        case .repot: return "Repot"
        }
    }
    
    var iconName: String {
        switch self {
        case .water: return "drop"
        case .fertilize: return "leaf.arrow.circlepath"
        case .prune: return "scissors"
        case .repot: return "arrow.up.and.down.and.arrow.left.and.right"
        }
    }
    
    var color: Color {
        switch self {
        case .water: return .blue
        case .fertilize: return .green
        case .prune: return .orange
        case .repot: return .purple
        }
    }
    
    var accessibilityLabel: String {
        switch self {
        case .water: return "Water plant"
        case .fertilize: return "Fertilize plant"
        case .prune: return "Prune plant"
        case .repot: return "Repot plant"
        }
    }
}
```

## 4. Journal & Photo Components

### JournalEntryCard Component
```swift
struct JournalEntryCard: View {
    let entry: JournalEntry
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Entry header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title.isEmpty ? "Journal Entry" : entry.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let plant = entry.plant {
                    PlantImageView(
                        imageURL: plant.primaryImageURL,
                        size: CGSize(width: 40, height: 40),
                        cornerRadius: 6
                    )
                }
            }
            
            // Entry photos
            if !entry.photoURLs.isEmpty {
                PhotoGrid(photoURLs: Array(entry.photoURLs.prefix(4)), maxPhotos: 4)
            }
            
            // Entry content preview
            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundStyle(.secondary)
            }
            
            // Growth stage or care actions
            if let growthStage = entry.growthStage {
                GrowthStageBadge(stage: growthStage)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entryAccessibilityLabel)
        .accessibilityHint("Tap to view full journal entry")
    }
    
    private var entryAccessibilityLabel: String {
        var label = entry.title.isEmpty ? "Journal Entry" : entry.title
        label += " from \(entry.date.formatted(date: .abbreviated, time: .omitted))"
        if let plant = entry.plant {
            label += " for \(plant.name)"
        }
        if !entry.photoURLs.isEmpty {
            label += ", \(entry.photoURLs.count) photos"
        }
        return label
    }
}

struct PhotoGrid: View {
    let photoURLs: [String]
    let maxPhotos: Int
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2), spacing: 4) {
            ForEach(Array(photoURLs.prefix(maxPhotos).enumerated()), id: \.offset) { index, url in
                AsyncImage(url: URL(string: url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                }
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .bottomTrailing) {
                    if index == maxPhotos - 1 && photoURLs.count > maxPhotos {
                        MorePhotosOverlay(count: photoURLs.count - maxPhotos)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(photoURLs.count) photos in journal entry")
    }
}

struct MorePhotosOverlay: View {
    let count: Int
    
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.black.opacity(0.7))
            .frame(width: 30, height: 20)
            .overlay {
                Text("+\(count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .padding(4)
    }
}
```

### PhotoCaptureButton Component
```swift
struct PhotoCaptureButton: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    let onPhotosSelected: ([UIImage]) -> Void
    
    var body: some View {
        Menu {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 5,
                matching: .images,
                selectionBehavior: .continuous
            ) {
                Label("Choose from Library", systemImage: "photo")
            }
            
            Button {
                showingCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
            }
        } label: {
            Label("Add Photos", systemImage: "photo.badge.plus")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.blue, in: Capsule())
        }
        .onChange(of: selectedItems) { newItems in
            Task {
                let images = await loadSelectedPhotos(from: newItems)
                await MainActor.run {
                    onPhotosSelected(images)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView { image in
                onPhotosSelected([image])
            }
        }
        .accessibilityLabel("Add photos to journal entry")
        .accessibilityHint("Choose photos from library or take new photos")
    }
    
    private func loadSelectedPhotos(from items: [PhotosPickerItem]) async -> [UIImage] {
        var images: [UIImage] = []
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        
        return images
    }
}
```

## 5. Search & Filter Components

### PlantSearchBar Component
```swift
struct PlantSearchBar: View {
    @Binding var searchText: String
    @State private var isEditing = false
    let onSearchSubmit: () -> Void
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search plants...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit(onSearchSubmit)
                    .onTapGesture {
                        isEditing = true
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            
            if isEditing {
                Button("Cancel") {
                    searchText = ""
                    isEditing = false
                    hideKeyboard()
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
        .accessibilityElement(children: .contain)
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
```

### FilterChipGroup Component
```swift
struct FilterChipGroup<T: Hashable & CaseIterable & CustomStringConvertible>: View {
    let title: String
    let options: [T]
    @Binding var selectedOptions: Set<T>
    let allowsMultipleSelection: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            FlowLayout(spacing: 8) {
                ForEach(Array(options), id: \.self) { option in
                    FilterChip(
                        title: option.description,
                        isSelected: selectedOptions.contains(option)
                    ) {
                        toggleSelection(for: option)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title) filter options")
    }
    
    private func toggleSelection(for option: T) {
        if allowsMultipleSelection {
            if selectedOptions.contains(option) {
                selectedOptions.remove(option)
            } else {
                selectedOptions.insert(option)
            }
        } else {
            selectedOptions = selectedOptions.contains(option) ? [] : [option]
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? .blue : .quaternary.opacity(0.5))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? .blue : .quaternary, lineWidth: 1)
                )
        }
        .accessibilityRole(.button)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

// FlowLayout for wrapping filter chips
struct FlowLayout: Layout {
    let spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        
        for (index, subview) in subviews.enumerated() {
            subview.place(at: result.positions[index], proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        let size: CGSize
        let positions: [CGPoint]
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var currentRow: [LayoutSubviews.Element] = []
            var currentRowWidth: CGFloat = 0
            var y: CGFloat = 0
            var maxHeight: CGFloat = 0
            
            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)
                
                if !currentRow.isEmpty && currentRowWidth + spacing + subviewSize.width > maxWidth {
                    // Place current row
                    let rowHeight = currentRow.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
                    var x: CGFloat = 0
                    
                    for rowSubview in currentRow {
                        positions.append(CGPoint(x: x, y: y))
                        x += rowSubview.sizeThatFits(.unspecified).width + spacing
                    }
                    
                    y += rowHeight + spacing
                    maxHeight = max(maxHeight, y)
                    currentRow = []
                    currentRowWidth = 0
                }
                
                currentRow.append(subview)
                currentRowWidth += subviewSize.width + (currentRow.count > 1 ? spacing : 0)
            }
            
            // Place remaining row
            if !currentRow.isEmpty {
                let rowHeight = currentRow.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
                var x: CGFloat = 0
                
                for rowSubview in currentRow {
                    positions.append(CGPoint(x: x, y: y))
                    x += rowSubview.sizeThatFits(.unspecified).width + spacing
                }
                
                maxHeight = max(maxHeight, y + rowHeight)
            }
            
            self.positions = positions
            self.size = CGSize(width: maxWidth, height: maxHeight)
        }
    }
}
```

## 6. Usage Guidelines

### Component Composition
- **Single Responsibility**: Each component should have one clear purpose
- **Configurable Styling**: Use style enums or configuration structs
- **Accessibility First**: Include accessibility labels and hints from the start
- **Consistent Spacing**: Use standard spacing values (4, 8, 12, 16, 20, 24)

### State Management
- **Local State**: Use `@State` for component-specific UI state
- **Shared State**: Pass down through `@Binding` or `@ObservableObject`
- **Environment Values**: Use for app-wide settings and theming

### Performance Considerations
- **Lazy Loading**: Use `LazyVGrid` and `LazyVStack` for large collections
- **Image Optimization**: Implement appropriate caching and sizing
- **Animation**: Use `.animation()` modifier judiciously for smooth transitions

### Testing Strategy
- **Preview Testing**: Include comprehensive SwiftUI Previews with different states
- **Accessibility Testing**: Test with VoiceOver and different Dynamic Type sizes
- **Snapshot Testing**: Capture component appearances for regression testing

This component architecture provides a solid foundation for building the GrowWise app with consistent, accessible, and maintainable UI components.