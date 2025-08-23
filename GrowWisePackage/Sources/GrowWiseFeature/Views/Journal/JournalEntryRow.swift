import SwiftUI
import GrowWiseModels
import GrowWiseServices

public struct JournalEntryRow: View {
    let entry: JournalEntry
    let photoService: PhotoService
    
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = false
    
    public init(entry: JournalEntry, photoService: PhotoService) {
        self.entry = entry
        self.photoService = photoService
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Entry type icon and thumbnail
            VStack(spacing: 4) {
                // Entry type icon
                Image(systemName: entry.entryType.iconName)
                    .font(.title3)
                    .foregroundColor(Color(entry.entryType.color))
                    .frame(width: 24, height: 24)
                
                // Photo thumbnail or placeholder
                Group {
                    if isLoadingThumbnail {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if let thumbnailImage = thumbnailImage {
                        Image(uiImage: thumbnailImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 40, height: 40)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            }
            
            // Entry content
            VStack(alignment: .leading, spacing: 4) {
                // Header row
                HStack {
                    // Entry title or type
                    Text(entry.title.isEmpty ? entry.entryType.displayName : entry.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Time
                    Text(formatTime(entry.entryDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Plant name and mood
                HStack {
                    if let plant = entry.plant {
                        Text(plant.name ?? "Unknown Plant")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let mood = entry.mood {
                        Text(mood.emoji)
                            .font(.caption)
                        
                        Text(mood.displayName)
                            .font(.caption)
                            .foregroundColor(Color(mood.color))
                    }
                    
                    Spacer()
                }
                
                // Content preview
                if !entry.content.isEmpty {
                    Text(entry.content)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Tags and measurements
                HStack {
                    // Tags
                    if !entry.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(entry.tags.prefix(2)), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.secondary)
                                    .clipShape(Capsule())
                            }
                            
                            if entry.tags.count > 2 {
                                Text("+\(entry.tags.count - 2)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Quick measurements display
                    HStack(spacing: 8) {
                        if let height = entry.heightMeasurement {
                            MeasurementBadge(
                                icon: "ruler",
                                value: "\(String(format: "%.1f", height))\"",
                                color: .blue
                            )
                        }
                        
                        if let temp = entry.temperature {
                            MeasurementBadge(
                                icon: "thermometer",
                                value: "\(Int(temp))°",
                                color: .orange
                            )
                        }
                        
                        if let moisture = entry.soilMoisture {
                            MeasurementBadge(
                                icon: "drop",
                                value: String(moisture.displayName.prefix(1)),
                                color: Color(moisture.color)
                            )
                        }
                    }
                }
                
                // Photo count indicator
                if !entry.photoURLs.isEmpty {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(entry.photoURLs.count) photo\(entry.photoURLs.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .task {
            await loadThumbnail()
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    @MainActor
    private func loadThumbnail() async {
        guard !entry.photoURLs.isEmpty,
              !isLoadingThumbnail,
              thumbnailImage == nil else { return }
        
        isLoadingThumbnail = true
        defer { isLoadingThumbnail = false }
        
        // Try to load the first photo as thumbnail
        // Note: This is simplified - in production you'd have proper photo metadata
        if let firstPhotoURL = entry.photoURLs.first,
           let url = URL(string: firstPhotoURL),
           FileManager.default.fileExists(atPath: url.path),
           let imageData = try? Data(contentsOf: url),
           let image = UIImage(data: imageData) {
            
            // Create thumbnail
            let size = CGSize(width: 40, height: 40)
            let renderer = UIGraphicsImageRenderer(size: size)
            thumbnailImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }
    }
}

// MARK: - Supporting Views

private struct MeasurementBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

#Preview {
    let sampleEntry = JournalEntry(
        title: "Morning watering",
        content: "Plants are looking healthy this morning. Added some fertilizer to the tomatoes.",
        entryType: .watering
    )
    sampleEntry.tags = ["morning", "fertilizer"]
    sampleEntry.heightMeasurement = 12.5
    sampleEntry.temperature = 72.0
    sampleEntry.soilMoisture = .moist
    sampleEntry.mood = .happy
    
    let plant = Plant(name: "Tomato Plant", plantType: .vegetable)
    sampleEntry.plant = plant
    
    return List {
        JournalEntryRow(
            entry: sampleEntry,
            photoService: PhotoService(dataService: try! DataService())
        )
    }
    .listStyle(InsetGroupedListStyle())
}