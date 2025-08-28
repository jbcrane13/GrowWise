import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import Photos
import CoreImage
import CoreImage.CIFilterBuiltins
import GrowWiseModels

#if canImport(UIKit)
@MainActor
public final class PhotoService: ObservableObject {
    private let dataService: DataService
    private let maxImageSize: CGFloat = 2048
    private let compressionQuality: CGFloat = 0.8
    
    // Image cache for memory management
    private let imageCache = NSCache<NSString, UIImage>()
    private let thumbnailCache = NSCache<NSString, UIImage>()
    
    // Background processing queue
    private let processingQueue = DispatchQueue(label: "com.growwise.photo.processing", qos: .userInitiated)
    
    // Photo storage paths
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private var photosPath: URL {
        documentsPath.appendingPathComponent("PlantPhotos")
    }
    
    public init(dataService: DataService) {
        self.dataService = dataService
        createPhotosDirectoryIfNeeded()
        
        // Configure caches for memory pressure handling
        imageCache.countLimit = 30  // Max 30 full images
        imageCache.totalCostLimit = 50 * 1024 * 1024  // 50MB max
        
        thumbnailCache.countLimit = 100  // Max 100 thumbnails
        thumbnailCache.totalCostLimit = 10 * 1024 * 1024  // 10MB max
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryPressure),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryPressure() {
        imageCache.removeAllObjects()
        thumbnailCache.removeAllObjects()
        print("📸 Cleared photo caches due to memory pressure")
    }
    
    // MARK: - Directory Management
    
    private func createPhotosDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: photosPath, withIntermediateDirectories: true)
        } catch {
            print("Failed to create photos directory: \(error)")
        }
    }
    
    private func plantPhotoPath(for plantId: UUID) -> URL {
        return photosPath.appendingPathComponent("plant_\(plantId.uuidString)")
    }
    
    private func createPlantDirectoryIfNeeded(for plantId: UUID) {
        let plantPath = plantPhotoPath(for: plantId)
        do {
            try FileManager.default.createDirectory(at: plantPath, withIntermediateDirectories: true)
        } catch {
            print("Failed to create plant photo directory: \(error)")
        }
    }
    
    // MARK: - Photo Saving
    
    public func savePhoto(_ image: UIImage, for plant: Plant, type: PhotoType = .general, notes: String = "") async throws -> PlantPhoto {
        guard let plantId = plant.id else {
            throw PhotoError.invalidPlantID
        }
        
        // Create directory if needed
        createPlantDirectoryIfNeeded(for: plantId)
        
        // Process and compress image in background
        let processedImage = await Task.detached(priority: .userInitiated) {
            await self.processImage(image)
        }.value
        
        // Generate unique filename
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "\(type.rawValue)_\(formatter.string(from: timestamp)).jpg"
        
        let filePath = plantPhotoPath(for: plantId).appendingPathComponent(filename)
        
        // Save image to disk in background
        guard let imageData = processedImage.jpegData(compressionQuality: compressionQuality) else {
            throw PhotoError.compressionFailed
        }
        
        try await Task.detached(priority: .background) {
            try imageData.write(to: filePath)
        }.value
        
        // Create and save photo metadata
        let photoMetadata = PlantPhoto(
            id: UUID(),
            plantId: plantId,
            filename: filename,
            filePath: filePath.path,
            photoType: type,
            dateTaken: timestamp,
            notes: notes,
            fileSize: imageData.count,
            dimensions: PhotoDimensions(
                width: Int(processedImage.size.width),
                height: Int(processedImage.size.height)
            )
        )
        
        // Store metadata in UserDefaults or Core Data
        await savePhotoMetadata(photoMetadata)
        
        return photoMetadata
    }
    
    public func savePhotoFromCamera(_ image: UIImage, for plant: Plant, type: PhotoType = .general, notes: String = "") async throws -> PlantPhoto {
        return try await savePhoto(image, for: plant, type: type, notes: notes)
    }
    
    public func savePhotoFromLibrary(_ image: UIImage, for plant: Plant, type: PhotoType = .general, notes: String = "") async throws -> PlantPhoto {
        return try await savePhoto(image, for: plant, type: type, notes: notes)
    }
    
    // MARK: - Photo Loading
    
    public func loadPhoto(from metadata: PlantPhoto) async -> UIImage? {
        let cacheKey = NSString(string: metadata.id.uuidString)
        
        // Check cache first
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        // Load from disk in background
        let metadataFilePath = metadata.filePath
        let cacheKeyString = metadata.id.uuidString // Use String instead of NSString for Sendable
        return await Task.detached(priority: .userInitiated) { @Sendable in
            let filePath = URL(fileURLWithPath: metadataFilePath)
            
            guard FileManager.default.fileExists(atPath: metadataFilePath),
                  let imageData = try? Data(contentsOf: filePath),
                  let image = UIImage(data: imageData) else {
                return nil
            }
            
            // Cache the image on main actor
            await MainActor.run {
                let nsKey = NSString(string: cacheKeyString)
                self.imageCache.setObject(image, forKey: nsKey, cost: imageData.count)
            }
            
            return image
        }.value
    }
    
    public func loadThumbnail(from metadata: PlantPhoto, size: CGSize = CGSize(width: 150, height: 150)) async -> UIImage? {
        let cacheKey = NSString(string: "thumb_\(metadata.id.uuidString)_\(Int(size.width))x\(Int(size.height))")
        
        // Check thumbnail cache first
        if let cachedThumbnail = thumbnailCache.object(forKey: cacheKey) {
            return cachedThumbnail
        }
        
        guard let fullImage = await loadPhoto(from: metadata) else {
            return nil
        }
        
        let thumbnail = await createThumbnail(from: fullImage, size: size)
        
        // Cache the thumbnail
        thumbnailCache.setObject(thumbnail, forKey: cacheKey)
        
        return thumbnail
    }
    
    public func getPhotos(for plant: Plant, type: PhotoType? = nil, limit: Int = 50) async -> [PlantPhoto] {
        guard let plantId = plant.id else { return [] }
        
        // Load metadata progressively
        let allPhotos = await getAllPhotosMetadata(for: plantId)
        
        var filtered = allPhotos
        if let type = type {
            filtered = allPhotos.filter { $0.photoType == type }
        }
        
        // Apply limit for memory management
        let sorted = filtered.sorted { $0.dateTaken > $1.dateTaken }
        return Array(sorted.prefix(limit))
    }
    
    public func getRecentPhotos(for plant: Plant, limit: Int = 5) async -> [PlantPhoto] {
        let allPhotos = await getPhotos(for: plant)
        return Array(allPhotos.prefix(limit))
    }
    
    // MARK: - Photo Organization
    
    public func getPhotosByType(for plant: Plant) async -> [PhotoType: [PlantPhoto]] {
        let allPhotos = await getPhotos(for: plant)
        return Dictionary(grouping: allPhotos) { $0.photoType }
    }
    
    public func getPhotosByDate(for plant: Plant) async -> [String: [PlantPhoto]] {
        let allPhotos = await getPhotos(for: plant)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        return Dictionary(grouping: allPhotos) { photo in
            formatter.string(from: photo.dateTaken)
        }
    }
    
    // MARK: - Photo Deletion
    
    public func deletePhoto(_ photo: PlantPhoto) async throws {
        let filePath = URL(fileURLWithPath: photo.filePath)
        
        // Delete file from disk
        if FileManager.default.fileExists(atPath: photo.filePath) {
            try FileManager.default.removeItem(at: filePath)
        }
        
        // Remove metadata
        await removePhotoMetadata(photo)
    }
    
    public func deleteAllPhotos(for plant: Plant) async throws {
        guard let plantId = plant.id else { throw PhotoError.invalidPlantID }
        let plantPath = plantPhotoPath(for: plantId)
        
        // Delete all files in plant directory
        if FileManager.default.fileExists(atPath: plantPath.path) {
            try FileManager.default.removeItem(at: plantPath)
        }
        
        // Remove all metadata for this plant
        await removeAllPhotoMetadata(for: plantId)
    }
    
    // MARK: - Image Processing
    
    private func processImage(_ image: UIImage) async -> UIImage {
        let maxSize = self.maxImageSize
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                Task { @MainActor in
                    let processedImage = self.resizeImage(image, maxSize: maxSize)
                    continuation.resume(returning: processedImage)
                }
            }
        }
    }
    
    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: min(maxSize, size.width), height: min(maxSize, size.width) / aspectRatio)
        } else {
            newSize = CGSize(width: min(maxSize, size.height) * aspectRatio, height: min(maxSize, size.height))
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    private func createThumbnail(from image: UIImage, size: CGSize) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let renderer = UIGraphicsImageRenderer(size: size)
                let thumbnail = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
                continuation.resume(returning: thumbnail)
            }
        }
    }
    
    // MARK: - Metadata Management
    
    private func savePhotoMetadata(_ photo: PlantPhoto) async {
        // Batch metadata updates
        let plantId = photo.plantId
        await Task.detached(priority: .background) { @Sendable in
            // Get existing photos without capturing self
            let key = "plant_photos_\(plantId.uuidString)"
            let existingData = try? KeychainManager.shared.retrieve(for: key)
            var existingPhotos = (try? JSONDecoder().decode([PlantPhoto].self, from: existingData ?? Data())) ?? []
            existingPhotos.append(photo)
            
            if let encodedData = try? JSONEncoder().encode(existingPhotos) {
                await MainActor.run {
                    try? KeychainManager.shared.store(encodedData, for: key)
                }
            }
        }.value
    }
    
    private func getAllPhotosMetadata(for plantId: UUID) async -> [PlantPhoto] {
        let key = "plant_photos_\(plantId.uuidString)"
        guard let data = try? KeychainManager.shared.retrieve(for: key),
              let photos = try? JSONDecoder().decode([PlantPhoto].self, from: data) else {
            return []
        }
        return photos
    }
    
    private func removePhotoMetadata(_ photo: PlantPhoto) async {
        var existingPhotos = await getAllPhotosMetadata(for: photo.plantId)
        existingPhotos.removeAll { $0.id == photo.id }
        
        let key = "plant_photos_\(photo.plantId.uuidString)"
        if let encodedData = try? JSONEncoder().encode(existingPhotos) {
            try? KeychainManager.shared.store(encodedData, for: key)
        }
    }
    
    private func removeAllPhotoMetadata(for plantId: UUID) async {
        let key = "plant_photos_\(plantId.uuidString)"
        try? KeychainManager.shared.delete(for: key)
    }
    
    // MARK: - Storage Statistics
    
    public func getStorageStatistics() async -> PhotoStorageStats {
        let totalSize = await calculateTotalStorageSize()
        let photoCount = await calculateTotalPhotoCount()
        
        return PhotoStorageStats(
            totalSizeBytes: totalSize,
            totalPhotos: photoCount,
            averageSizeBytes: photoCount > 0 ? totalSize / photoCount : 0
        )
    }
    
    private func calculateTotalStorageSize() async -> Int {
        let photosDirectory = photosPath
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var totalSize = 0
                
                guard let enumerator = FileManager.default.enumerator(at: photosDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
                    continuation.resume(returning: 0)
                    return
                }
                
                for case let fileURL as URL in enumerator {
                    if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalSize += fileSize
                    }
                }
                
                continuation.resume(returning: totalSize)
            }
        }
    }
    
    private func calculateTotalPhotoCount() async -> Int {
        let photosDirectory = photosPath
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let contents = try? FileManager.default.contentsOfDirectory(at: photosDirectory, includingPropertiesForKeys: nil) else {
                    continuation.resume(returning: 0)
                    return
                }
                
                var count = 0
                for plantDirectory in contents {
                    if let plantContents = try? FileManager.default.contentsOfDirectory(at: plantDirectory, includingPropertiesForKeys: nil) {
                        count += plantContents.count
                    }
                }
                
                continuation.resume(returning: count)
            }
        }
    }
    
    // MARK: - Cleanup
    
    public func cleanupOrphanedPhotos() async throws {
        // Remove photo files that don't have corresponding metadata
        guard let plantDirectories = try? FileManager.default.contentsOfDirectory(at: photosPath, includingPropertiesForKeys: nil) else {
            return
        }
        
        for plantDirectory in plantDirectories {
            let plantIdString = plantDirectory.lastPathComponent.replacingOccurrences(of: "plant_", with: "")
            guard let plantId = UUID(uuidString: plantIdString) else { continue }
            
            let metadata = await getAllPhotosMetadata(for: plantId)
            let metadataFilenames = Set(metadata.map { $0.filename })
            
            if let photoFiles = try? FileManager.default.contentsOfDirectory(at: plantDirectory, includingPropertiesForKeys: nil) {
                for photoFile in photoFiles {
                    let filename = photoFile.lastPathComponent
                    if !metadataFilenames.contains(filename) {
                        try FileManager.default.removeItem(at: photoFile)
                    }
                }
            }
        }
    }
    
    // MARK: - Backup and Export
    
    public func exportPhotos(for plant: Plant) async throws -> URL {
        guard let plantId = plant.id else { throw PhotoError.invalidPlantID }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("plant_\(plantId.uuidString)_photos.zip")
        
        // Create zip archive of all photos for this plant
        let plantPath = plantPhotoPath(for: plantId)
        
        // This is a simplified implementation - in a real app you'd use a zip library
        try FileManager.default.copyItem(at: plantPath, to: tempURL)
        
        return tempURL
    }
}
#else
// Placeholder for non-iOS platforms  
@MainActor
public final class PhotoService: ObservableObject {
    public init() {}
    
    public func requestPhotoLibraryPermission() async -> Bool {
        return false
    }
    
    public func requestCameraPermission() async -> Bool {
        return false
    }
}
#endif

// MARK: - Supporting Types

public struct PlantPhoto: Identifiable, Codable, Sendable {
    public let id: UUID
    public let plantId: UUID
    public let filename: String
    public let filePath: String
    public let photoType: PhotoType
    public let dateTaken: Date
    public let notes: String
    public let fileSize: Int
    public let dimensions: PhotoDimensions
    
    public init(id: UUID, plantId: UUID, filename: String, filePath: String, photoType: PhotoType, dateTaken: Date, notes: String, fileSize: Int, dimensions: PhotoDimensions) {
        self.id = id
        self.plantId = plantId
        self.filename = filename
        self.filePath = filePath
        self.photoType = photoType
        self.dateTaken = dateTaken
        self.notes = notes
        self.fileSize = fileSize
        self.dimensions = dimensions
    }
}

public struct PhotoDimensions: Codable, Sendable {
    public let width: Int
    public let height: Int
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public enum PhotoType: String, CaseIterable, Codable, Sendable {
    case general = "general"
    case progress = "progress"
    case problem = "problem"
    case harvest = "harvest"
    case flower = "flower"
    case seedling = "seedling"
    case mature = "mature"
    
    public var displayName: String {
        switch self {
        case .general: return "General"
        case .progress: return "Progress"
        case .problem: return "Problem"
        case .harvest: return "Harvest"
        case .flower: return "Flowering"
        case .seedling: return "Seedling"
        case .mature: return "Mature Plant"
        }
    }
    
    public var icon: String {
        switch self {
        case .general: return "photo"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .problem: return "exclamationmark.triangle"
        case .harvest: return "basket"
        case .flower: return "leaf"
        case .seedling: return "sprout"
        case .mature: return "tree"
        }
    }
}

public struct PhotoStorageStats: Sendable {
    public let totalSizeBytes: Int
    public let totalPhotos: Int
    public let averageSizeBytes: Int
    
    public var totalSizeMB: Double {
        return Double(totalSizeBytes) / (1024 * 1024)
    }
    
    public var averageSizeMB: Double {
        return Double(averageSizeBytes) / (1024 * 1024)
    }
    
    public init(totalSizeBytes: Int, totalPhotos: Int, averageSizeBytes: Int) {
        self.totalSizeBytes = totalSizeBytes
        self.totalPhotos = totalPhotos
        self.averageSizeBytes = averageSizeBytes
    }
}

public enum PhotoError: Error, Sendable {
    case compressionFailed
    case saveLocationUnavailable
    case fileNotFound
    case permissionDenied
    case invalidPlantID
    
    public var localizedDescription: String {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .saveLocationUnavailable:
            return "Photo save location is unavailable"
        case .fileNotFound:
            return "Photo file not found"
        case .permissionDenied:
            return "Permission denied to access photos"
        case .invalidPlantID:
            return "Invalid plant ID provided"
        }
    }
}
