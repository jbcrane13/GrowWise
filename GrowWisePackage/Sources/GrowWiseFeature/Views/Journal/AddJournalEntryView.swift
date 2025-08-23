import SwiftUI
import SwiftData
import PhotosUI
import GrowWiseModels
import GrowWiseServices

public struct AddJournalEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var plants: [Plant]
    
    let photoService: PhotoService
    
    // Form fields
    @State private var title = ""
    @State private var content = ""
    @State private var selectedPlant: Plant?
    @State private var entryType: JournalEntryType = .observation
    @State private var tags: [String] = []
    @State private var newTag = ""
    
    // Measurements
    @State private var heightMeasurement: String = ""
    @State private var widthMeasurement: String = ""
    @State private var temperature: String = ""
    @State private var humidity: String = ""
    @State private var soilMoisture: SoilMoisture?
    @State private var weatherCondition: WeatherCondition?
    @State private var plantMood: PlantMood?
    
    // Care activities
    @State private var wateringAmount: String = ""
    @State private var fertilizer = ""
    @State private var fertilizerAmount = ""
    @State private var pruningNotes = ""
    @State private var pestObservations = ""
    
    // Photos
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var capturedImages: [UIImage] = []
    @State private var showingCamera = false
    @State private var isProcessingPhotos = false
    
    // UI state
    @State private var showingAdvancedFields = false
    @State private var isPrivate = false
    @State private var isSaving = false
    
    public init(photoService: PhotoService) {
        self.photoService = photoService
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                // Basic Information Section
                Section("Entry Details") {
                    TextField("Entry title (optional)", text: $title)
                    
                    Picker("Entry Type", selection: $entryType) {
                        ForEach(JournalEntryType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    
                    Picker("Plant", selection: $selectedPlant) {
                        Text("Select a plant")
                            .tag(nil as Plant?)
                        
                        ForEach(plants.filter { $0.isUserPlant ?? false }) { plant in
                            Text(plant.name ?? "Unknown Plant")
                                .tag(plant as Plant?)
                        }
                    }
                }
                
                // Content Section
                Section("Notes") {
                    TextField("What's happening with your plant?", text: $content, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Photos Section
                Section("Photos") {
                    PhotosSection(
                        selectedPhotos: $selectedPhotos,
                        capturedImages: $capturedImages,
                        showingCamera: $showingCamera,
                        isProcessingPhotos: $isProcessingPhotos
                    )
                }
                
                // Quick Measurements Section
                Section("Quick Measurements") {
                    HStack {
                        TextField("Height", text: $heightMeasurement)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                        Text("inches")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        TextField("Temperature", text: $temperature)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                        Text("°F")
                            .foregroundColor(.secondary)
                    }
                    
                    Picker("Soil Moisture", selection: $soilMoisture) {
                        Text("Not specified")
                            .tag(nil as SoilMoisture?)
                        
                        ForEach(SoilMoisture.allCases, id: \.self) { moisture in
                            Text(moisture.displayName)
                                .tag(moisture as SoilMoisture?)
                        }
                    }
                    
                    Picker("Plant Mood", selection: $plantMood) {
                        Text("Not specified")
                            .tag(nil as PlantMood?)
                        
                        ForEach(PlantMood.allCases, id: \.self) { mood in
                            HStack {
                                Text(mood.emoji)
                                Text(mood.displayName)
                            }
                            .tag(mood as PlantMood?)
                        }
                    }
                }
                
                // Advanced Fields (Collapsible)
                if showingAdvancedFields {
                    Section("Detailed Measurements") {
                        HStack {
                            TextField("Width", text: $widthMeasurement)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                            Text("inches")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            TextField("Humidity", text: $humidity)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                            Text("%")
                                .foregroundColor(.secondary)
                        }
                        
                        Picker("Weather", selection: $weatherCondition) {
                            Text("Not specified")
                                .tag(nil as WeatherCondition?)
                            
                            ForEach(WeatherCondition.allCases, id: \.self) { weather in
                                Label(weather.displayName, systemImage: weather.iconName)
                                    .tag(weather as WeatherCondition?)
                            }
                        }
                    }
                    
                    Section("Care Activities") {
                        if entryType == .watering {
                            HStack {
                                TextField("Water amount", text: $wateringAmount)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.decimalPad)
                                Text("fl oz")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if entryType == .fertilizing {
                            TextField("Fertilizer type", text: $fertilizer)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Amount used", text: $fertilizerAmount)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        if entryType == .pruning {
                            TextField("Pruning notes", text: $pruningNotes, axis: .vertical)
                                .lineLimit(2...4)
                        }
                        
                        if entryType == .problemReport {
                            TextField("Pest observations", text: $pestObservations, axis: .vertical)
                                .lineLimit(2...4)
                        }
                    }
                }
                
                // Show/Hide Advanced Fields
                Section {
                    Button {
                        withAnimation {
                            showingAdvancedFields.toggle()
                        }
                    } label: {
                        HStack {
                            Text(showingAdvancedFields ? "Hide Advanced Fields" : "Show Advanced Fields")
                            Spacer()
                            Image(systemName: showingAdvancedFields ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                    }
                }
                
                // Tags Section
                Section("Tags") {
                    TagsSection(tags: $tags, newTag: $newTag)
                }
                
                // Privacy Section
                Section {
                    Toggle("Private Entry", isOn: $isPrivate)
                }
            }
            .navigationTitle("New Journal Entry")
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
                            await saveEntry()
                        }
                    }
                    .disabled(isSaving || (title.isEmpty && content.isEmpty))
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView { image in
                    capturedImages.append(image)
                }
            }
            .onChange(of: selectedPhotos) { _, newValue in
                Task {
                    await processSelectedPhotos(newValue)
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView("Saving entry...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func saveEntry() async {
        isSaving = true
        defer { isSaving = false }
        
        do {
            // Create journal entry
            let entry = JournalEntry(
                title: title,
                content: content,
                entryType: entryType,
                plant: selectedPlant
            )
            
            // Set measurements
            entry.heightMeasurement = Double(heightMeasurement)
            entry.widthMeasurement = Double(widthMeasurement)
            entry.temperature = Double(temperature)
            entry.humidity = Double(humidity)
            entry.soilMoisture = soilMoisture
            entry.weatherConditions = weatherCondition
            entry.mood = plantMood
            
            // Set care activities
            entry.wateringAmount = Double(wateringAmount)
            entry.fertilizer = fertilizer.isEmpty ? nil : fertilizer
            entry.fertilizerAmount = fertilizerAmount.isEmpty ? nil : fertilizerAmount
            entry.pruningNotes = pruningNotes.isEmpty ? nil : pruningNotes
            entry.pestObservations = pestObservations.isEmpty ? nil : pestObservations
            
            // Set tags and privacy
            entry.tags = tags
            entry.isPrivate = isPrivate
            
            // Save photos if any
            if let plant = selectedPlant {
                for image in capturedImages {
                    let photoMetadata = try await photoService.savePhoto(
                        image,
                        for: plant,
                        type: entryType == .problemReport ? .problem : .general,
                        notes: "Journal entry: \(title.isEmpty ? entryType.displayName : title)"
                    )
                    entry.addPhoto(url: photoMetadata.filePath)
                }
            }
            
            // Save to model context
            modelContext.insert(entry)
            try modelContext.save()
            
            dismiss()
        } catch {
            print("Failed to save journal entry: \(error)")
            // In production, show error alert
        }
    }
    
    @MainActor
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        
        isProcessingPhotos = true
        defer { isProcessingPhotos = false }
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                capturedImages.append(image)
            }
        }
        
        selectedPhotos.removeAll()
    }
}

// MARK: - Supporting Views

private struct PhotosSection: View {
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var capturedImages: [UIImage]
    @Binding var showingCamera: Bool
    @Binding var isProcessingPhotos: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    Label("Choose Photos", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
                
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
                .buttonStyle(.bordered)
            }
            
            if isProcessingPhotos {
                ProgressView("Processing photos...")
                    .font(.caption)
            }
            
            if !capturedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(capturedImages.enumerated()), id: \.offset) { index, image in
                            VStack {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        Button {
                                            capturedImages.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Color.white, in: Circle())
                                        }
                                        .offset(x: 8, y: -8),
                                        alignment: .topTrailing
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                Text("\(capturedImages.count) photo\(capturedImages.count == 1 ? "" : "s") selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct TagsSection: View {
    @Binding var tags: [String]
    @Binding var newTag: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Add tag", text: $newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        addTag()
                    }
                
                Button("Add", action: addTag)
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            if !tags.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 80))
                ], spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text("#\(tag)")
                                .font(.caption)
                            
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            tags.append(trimmedTag)
            newTag = ""
        }
    }
}

private struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    AddJournalEntryView(photoService: PhotoService(dataService: try! DataService()))
        .modelContainer(for: [Plant.self, JournalEntry.self], inMemory: true)
}