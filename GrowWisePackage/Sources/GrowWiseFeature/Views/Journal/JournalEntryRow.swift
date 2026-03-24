#if canImport(UIKit)
import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct JournalEntryRow: View {
    let entry: JournalEntry
    let photoService: PhotoService

    @State private var thumbnailImage: UIImage?
    @State private var isLoadingThumbnail = false

    public init(entry: JournalEntry, photoService: PhotoService) {
        self.entry = entry
        self.photoService = photoService
    }

    // MARK: - Computed helpers

    private var entryColor: Color {
        Color(entry.entryType.color)
    }

    private var plantName: String {
        entry.plant?.name ?? "General"
    }

    private var actionLabel: String {
        entry.title.isEmpty ? entry.entryType.displayName : entry.title
    }

    private var timeLabel: String {
        Self.timeFormatter.string(from: entry.entryDate)
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 12) {
            // Left: icon bubble
            IconBubble(
                systemName: entry.entryType.iconName,
                color: entryColor,
                size: 40,
                iconSize: 16
            )

            // Center: content
            VStack(alignment: .leading, spacing: 4) {
                // Plant name row
                Text(plantName)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    .lineLimit(1)

                // Action + time row
                HStack {
                    Text(actionLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    Text(timeLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(CultivationTheme.Colors.textTertiary)
                }

                // Mood badge (if present)
                if let mood = entry.mood {
                    HStack(spacing: 4) {
                        Text(mood.emoji)
                            .font(.caption2)
                        Text(mood.displayName)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(mood.color))
                    }
                }

                // Notes preview
                if !entry.content.isEmpty {
                    Text(entry.content)
                        .font(.system(size: 12))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                // Photo thumbnail (inline)
                if !entry.photoURLs.isEmpty {
                    HStack(spacing: 8) {
                        Group {
                            if isLoadingThumbnail {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 52, height: 52)
                            } else if let thumbnailImage {
                                Image(uiImage: thumbnailImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 52, height: 52)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.caption2)
                                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                            Text("\(entry.photoURLs.count) photo\(entry.photoURLs.count == 1 ? "" : "s")")
                                .font(.system(size: 11))
                                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        }
                    }
                    .padding(.top, 2)
                }

                // Tags
                if !entry.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(entry.tags.prefix(2)), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(CultivationTheme.Colors.cardSurface)
                                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                                }
                        }

                        if entry.tags.count > 2 {
                            Text("+\(entry.tags.count - 2)")
                                .font(.caption2)
                                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                        }
                    }
                }

                // Measurement badges
                let hasMeasurements = entry.heightMeasurement != nil
                    || entry.temperature != nil
                    || entry.soilMoisture != nil
                if hasMeasurements {
                    HStack(spacing: 6) {
                        if let height = entry.heightMeasurement {
                            MeasurementBadge(
                                icon: "ruler",
                                value: "\(String(format: "%.1f", height))\"",
                                color: CultivationTheme.Colors.brandLeaf
                            )
                        }

                        if let temp = entry.temperature {
                            MeasurementBadge(
                                icon: "thermometer",
                                value: "\(Int(temp))°",
                                color: CultivationTheme.Colors.brandGold
                            )
                        }

                        if let moisture = entry.soilMoisture {
                            MeasurementBadge(
                                icon: "drop.fill",
                                value: String(moisture.displayName.prefix(1)),
                                color: Color(moisture.color)
                            )
                        }

                        Spacer()
                    }
                }
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(CultivationTheme.Colors.textTertiary)
        }
        .padding(CultivationTheme.Spacing.cardPadding)
        .glassCard()
        .task {
            await loadThumbnail()
        }
    }

    // MARK: - Helper Methods

    private static let timeFormatter: DateFormatter = {
        // swiftlint:disable:next identifier_name
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    @MainActor
    private func loadThumbnail() async {
        guard !entry.photoURLs.isEmpty,
              !isLoadingThumbnail,
              thumbnailImage == nil else { return }

        isLoadingThumbnail = true
        defer { isLoadingThumbnail = false }

        if let firstPhotoURL = entry.photoURLs.first,
           let url = URL(string: firstPhotoURL),
           FileManager.default.fileExists(atPath: url.path),
           let imageData = try? Data(contentsOf: url),
           let image = UIImage(data: imageData)
        {
            let size = CGSize(width: 52, height: 52)
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
        .foregroundStyle(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
    }
}

#Preview {
    Text("JournalEntryRow Preview")
        .padding()
}
#else
import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct JournalEntryRow: View {
    let entry: JournalEntry
    let photoService: PhotoService

    public init(entry: JournalEntry, photoService: PhotoService) {
        self.entry = entry
        self.photoService = photoService
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title)
                .font(.headline)
            Text("Journal thumbnails are available on iOS.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
#endif
