import SwiftUI
import SwiftData
import PhotosUI
import GrowWiseModels
import GrowWiseServices

public struct JournalEntryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State var entry: JournalEntry
    let photoService: PhotoService
    
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var photosWithImages: [(PlantPhoto?, UIImage?)] = []
    @State private var isLoadingPhotos = false
    @State private var selectedPhotoIndex: Int?
    
    // Edit mode states
    @State private var editTitle: String = ""
    @State private var editContent: String = ""
    @State private var editTags: [String] = []
    @State private var newTag = ""
    
    public init(entry: JournalEntry, photoService: PhotoService) {
        self._entry = State(initialValue: entry)
        self.photoService = photoService
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 12) {
                        // Entry type and date
                        HStack {
                            Label(entry.entryType.displayName, systemImage: entry.entryType.iconName)
                                .font(.headline)
                                .foregroundColor(Color(entry.entryType.color))
                            
                            Spacer()
                            
                            Text(formatFullDate(entry.entryDate))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Title
                        if isEditing {
                            TextField("Entry title", text: $editTitle)
                                .font(.title2)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else if !entry.title.isEmpty {
                            Text(entry.title)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        // Plant info
                        if let plant = entry.plant {
                            HStack {
                                Image(systemName: "leaf.fill")
                                    .foregroundColor(.green)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plant.name ?? "Unknown Plant")
                                        .font(.headline)
                                    
                                    Text(plant.plantType?.displayName ?? "Unknown Type")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if let mood = entry.mood {
                                    VStack {
                                        Text(mood.emoji)
                                            .font(.title2)
                                        
                                        Text(mood.displayName)
                                            .font(.caption)
                                            .foregroundColor(Color(mood.color))
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    
                    // Photos Gallery
                    if !photosWithImages.isEmpty {
                        PhotosGallerySection(
                            photosWithImages: photosWithImages,
                            selectedPhotoIndex: $selectedPhotoIndex
                        )
                    }
                    
                    // Content Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.headline)
                        
                        if isEditing {
                            TextField("Entry content", text: $editContent, axis: .vertical)
                                .lineLimit(5...10)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else if !entry.content.isEmpty {
                            Text(entry.content)
                                .font(.body)
                        } else {
                            Text("No notes added")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    
                    // Measurements Section
                    if hasMeasurements {
                        MeasurementsSection(entry: entry)
                    }
                    
                    // Care Activities Section
                    if hasCareActivities {
                        CareActivitiesSection(entry: entry)
                    }
                    
                    // Environmental Conditions Section
                    if hasEnvironmentalData {
                        EnvironmentalSection(entry: entry)
                    }
                    
                    // Tags Section
                    if isEditing || !entry.tags.isEmpty {
                        TagsSection(
                            entry: entry,
                            isEditing: isEditing,
                            editTags: $editTags,
                            newTag: $newTag
                        )
                    }
                    
                    // Metadata Section
                    MetadataSection(entry: entry)
                }
                .padding()
            }
            .navigationTitle("Journal Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if isEditing {
                            Button("Save Changes") {
                                saveChanges()
                            }
                            
                            Button("Cancel Edit") {
                                cancelEdit()
                            }
                        } else {
                            Button("Edit Entry") {
                                startEditing()
                            }
                            
                            Button("Share Entry") {
                                showingShareSheet = true
                            }
                            
                            Divider()
                            
                            Button("Delete Entry", role: .destructive) {
                                showingDeleteAlert = true
                            }
                        }
                    } label: {
                        Image(systemName: isEditing ? "checkmark" : "ellipsis.circle")
                    }
                }
            }
            .alert("Delete Entry", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteEntry()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this journal entry? This action cannot be undone.")
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(entry: entry)
            }
            .sheet(item: Binding<PhotoIndex?>(
                get: { selectedPhotoIndex.map(PhotoIndex.init) },
                set: { selectedPhotoIndex = $0?.index }
            )) { photoIndex in
                if let image = photosWithImages[photoIndex.index].1 {
                    PhotoDetailView(image: image)
                }
            }
            .task {
                await loadPhotos()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasMeasurements: Bool {
        entry.heightMeasurement != nil ||
        entry.widthMeasurement != nil ||
        entry.temperature != nil ||
        entry.humidity != nil
    }
    
    private var hasCareActivities: Bool {
        entry.wateringAmount != nil ||
        entry.fertilizer != nil ||
        entry.pruningNotes != nil ||
        entry.pestObservations != nil
    }
    
    private var hasEnvironmentalData: Bool {
        entry.soilMoisture != nil ||
        entry.weatherConditions != nil
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func loadPhotos() async {
        guard !entry.photoURLs.isEmpty, !isLoadingPhotos else { return }
        
        isLoadingPhotos = true
        defer { isLoadingPhotos = false }
        
        var loadedPhotos: [(PlantPhoto?, UIImage?)] = []
        
        for photoURL in entry.photoURLs {
            guard let url = URL(string: photoURL),
                  FileManager.default.fileExists(atPath: url.path),
                  let imageData = try? Data(contentsOf: url),
                  let image = UIImage(data: imageData) else {
                loadedPhotos.append((nil, nil))
                continue
            }
            
            loadedPhotos.append((nil, image))
        }
        
        photosWithImages = loadedPhotos
    }
    
    private func startEditing() {
        editTitle = entry.title
        editContent = entry.content
        editTags = entry.tags
        isEditing = true
    }
    
    private func cancelEdit() {
        editTitle = ""
        editContent = ""
        editTags = []
        newTag = ""
        isEditing = false
    }
    
    private func saveChanges() {
        entry.title = editTitle
        entry.content = editContent
        entry.tags = editTags
        entry.lastModified = Date()
        
        try? modelContext.save()
        isEditing = false
    }
    
    private func deleteEntry() {
        modelContext.delete(entry)
        try? modelContext.save()
        dismiss()
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

private struct PhotosGallerySection: View {
    let photosWithImages: [(PlantPhoto?, UIImage?)]
    @Binding var selectedPhotoIndex: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos (\(photosWithImages.count))")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(photosWithImages.enumerated()), id: \.offset) { index, photoData in
                        Button {
                            selectedPhotoIndex = index
                        } label: {
                            Group {
                                if let image = photoData.1 {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.secondary)
                                        )
                                }
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

private struct MeasurementsSection: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Measurements")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                if let height = entry.heightMeasurement {
                    MeasurementCard(
                        title: "Height",
                        value: "\(String(format: "%.1f", height))\"",
                        icon: "ruler",
                        color: .blue
                    )
                }
                
                if let width = entry.widthMeasurement {
                    MeasurementCard(
                        title: "Width",
                        value: "\(String(format: "%.1f", width))\"",
                        icon: "ruler.fill",
                        color: .blue
                    )
                }
                
                if let temp = entry.temperature {
                    MeasurementCard(
                        title: "Temperature",
                        value: "\(Int(temp))°F",
                        icon: "thermometer",
                        color: .orange
                    )
                }
                
                if let humidity = entry.humidity {
                    MeasurementCard(
                        title: "Humidity",
                        value: "\(Int(humidity))%",
                        icon: "humidity",
                        color: .cyan
                    )
                }
            }
        }
    }
}

private struct CareActivitiesSection: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Care Activities")
                .font(.headline)
            
            VStack(spacing: 8) {
                if let waterAmount = entry.wateringAmount {
                    ActivityRow(
                        icon: "drop.fill",
                        title: "Watering",
                        detail: "\(String(format: "%.1f", waterAmount)) fl oz",
                        color: .blue
                    )
                }
                
                if let fertilizer = entry.fertilizer {
                    ActivityRow(
                        icon: "leaf.fill",
                        title: "Fertilizer",
                        detail: "\(fertilizer) \(entry.fertilizerAmount ?? "")",
                        color: .green
                    )
                }
                
                if let pruning = entry.pruningNotes, !pruning.isEmpty {
                    ActivityRow(
                        icon: "scissors",
                        title: "Pruning",
                        detail: pruning,
                        color: .orange
                    )
                }
                
                if let pests = entry.pestObservations, !pests.isEmpty {
                    ActivityRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "Pest Issues",
                        detail: pests,
                        color: .red
                    )
                }
            }
        }
    }
}

private struct EnvironmentalSection: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Environmental Conditions")
                .font(.headline)
            
            VStack(spacing: 8) {
                if let moisture = entry.soilMoisture {
                    HStack {
                        Image(systemName: "drop.circle.fill")
                            .foregroundColor(Color(moisture.color))
                        
                        VStack(alignment: .leading) {
                            Text("Soil Moisture")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(moisture.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                if let weather = entry.weatherConditions {
                    HStack {
                        Image(systemName: weather.iconName)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading) {
                            Text("Weather")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(weather.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct TagsSection: View {
    let entry: JournalEntry
    let isEditing: Bool
    @Binding var editTags: [String]
    @Binding var newTag: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)
            
            if isEditing {
                HStack {
                    TextField("Add tag", text: $newTag)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            addTag()
                        }
                    
                    Button("Add", action: addTag)
                        .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            
            let tagsToShow = isEditing ? editTags : entry.tags
            
            if !tagsToShow.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 80))
                ], spacing: 8) {
                    ForEach(tagsToShow, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text("#\(tag)")
                                .font(.caption)
                            
                            if isEditing {
                                Button {
                                    editTags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption2)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .clipShape(Capsule())
                    }
                }
            } else if !isEditing {
                Text("No tags added")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !editTags.contains(trimmedTag) {
            editTags.append(trimmedTag)
            newTag = ""
        }
    }
}

private struct MetadataSection: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Entry Information")
                .font(.headline)
            
            VStack(spacing: 4) {
                HStack {
                    Text("Created:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDate(entry.entryDate))
                }
                
                HStack {
                    Text("Last modified:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDate(entry.lastModified))
                }
                
                if entry.isPrivate {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.secondary)
                        Text("Private entry")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Components

private struct MeasurementCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ActivityRow: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PhotoDetailView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZoomableImageView(image: image)
                .background(Color.black)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

private struct ZoomableImageView: View {
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1.0 {
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            },
                        
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if scale == 1.0 {
                            scale = 2.0
                            lastScale = 2.0
                        } else {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
                }
        }
    }
}

private struct ShareSheet: View {
    let entry: JournalEntry
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Share functionality would be implemented here")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Share Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Helper Types

private struct PhotoIndex: Identifiable {
    let id = UUID()
    let index: Int
}

#Preview {
    let sampleEntry = JournalEntry(
        title: "First flowering!",
        content: "My tomato plant is finally flowering! The first blossoms appeared today and they look healthy. I'm excited to see the first tomatoes soon.",
        entryType: .milestone
    )
    
    sampleEntry.heightMeasurement = 24.5
    sampleEntry.temperature = 75.0
    sampleEntry.humidity = 65.0
    sampleEntry.soilMoisture = .moist
    sampleEntry.weatherConditions = .sunny
    sampleEntry.mood = .thriving
    sampleEntry.tags = ["flowering", "milestone", "tomatoes"]
    
    let plant = Plant(name: "Cherokee Purple Tomato", plantType: .vegetable)
    sampleEntry.plant = plant
    
    return JournalEntryDetailView(
        entry: sampleEntry,
        photoService: PhotoService(dataService: try! DataService())
    )
    .modelContainer(for: [JournalEntry.self, Plant.self], inMemory: true)
}