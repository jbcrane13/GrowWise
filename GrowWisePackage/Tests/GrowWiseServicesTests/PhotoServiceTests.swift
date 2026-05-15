import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import GrowWiseModels
@testable import GrowWiseServices

// MARK: - PlantPhoto value-type tests

struct PlantPhotoInitTests {
    @Test("PlantPhoto init stores all provided fields correctly")
    func plantPhotoInit() {
        let id = UUID()
        let plantId = UUID()
        let taken = Date()
        let dims = PhotoDimensions(width: 1920, height: 1080)
        let photo = PlantPhoto(
            id: id,
            plantId: plantId,
            filename: "progress_20260226_120000.jpg",
            filePath: "/documents/PlantPhotos/plant_\(plantId)/progress_20260226_120000.jpg",
            photoType: .progress,
            dateTaken: taken,
            notes: "Looking healthy",
            fileSize: 204_800,
            dimensions: dims
        )

        #expect(photo.id == id)
        #expect(photo.plantId == plantId)
        #expect(photo.filename == "progress_20260226_120000.jpg")
        #expect(photo.photoType == .progress)
        #expect(photo.dateTaken == taken)
        #expect(photo.notes == "Looking healthy")
        #expect(photo.fileSize == 204_800)
        #expect(photo.dimensions.width == 1920)
        #expect(photo.dimensions.height == 1080)
    }

    @Test("PlantPhoto Identifiable uses the id property")
    func plantPhotoIdentifiable() {
        let id = UUID()
        let photo = PlantPhoto(
            id: id,
            plantId: UUID(),
            filename: "f.jpg",
            filePath: "/p/f.jpg",
            photoType: .general,
            dateTaken: Date(),
            notes: "",
            fileSize: 0,
            dimensions: PhotoDimensions(width: 1, height: 1)
        )
        #expect(photo.id == id)
    }

    @Test("PlantPhoto Codable round-trip preserves all fields")
    func plantPhotoCodableRoundTrip() throws {
        let original = PlantPhoto(
            id: UUID(),
            plantId: UUID(),
            filename: "harvest_20260301_090000.jpg",
            filePath: "/photos/harvest.jpg",
            photoType: .harvest,
            dateTaken: Date(timeIntervalSince1970: 1_740_000_000),
            notes: "First harvest",
            fileSize: 512_000,
            dimensions: PhotoDimensions(width: 3024, height: 4032)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PlantPhoto.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.plantId == original.plantId)
        #expect(decoded.filename == original.filename)
        #expect(decoded.filePath == original.filePath)
        #expect(decoded.photoType == original.photoType)
        #expect(decoded.notes == original.notes)
        #expect(decoded.fileSize == original.fileSize)
        #expect(decoded.dimensions.width == original.dimensions.width)
        #expect(decoded.dimensions.height == original.dimensions.height)
        // Date encoding may have sub-second loss; compare to within 1s
        #expect(abs(decoded.dateTaken.timeIntervalSince(original.dateTaken)) < 1.0)
    }

    @Test("Two PlantPhoto values with different IDs are not equal via Identifiable")
    func plantPhotoDistinctIDs() {
        let p1 = PlantPhoto(
            id: UUID(),
            plantId: UUID(),
            filename: "a.jpg",
            filePath: "/a.jpg",
            photoType: .general,
            dateTaken: Date(),
            notes: "",
            fileSize: 1,
            dimensions: PhotoDimensions(width: 100, height: 100)
        )
        let p2 = PlantPhoto(
            id: UUID(),
            plantId: p1.plantId,
            filename: "a.jpg",
            filePath: "/a.jpg",
            photoType: .general,
            dateTaken: p1.dateTaken,
            notes: "",
            fileSize: 1,
            dimensions: PhotoDimensions(width: 100, height: 100)
        )
        #expect(p1.id != p2.id)
    }

    @Test("PlantPhoto array of multiple photos all encode and decode correctly")
    func plantPhotoArrayCodable() throws {
        let plantId = UUID()
        let photos = PhotoType.allCases.map { type in
            PlantPhoto(
                id: UUID(),
                plantId: plantId,
                filename: "\(type.rawValue).jpg",
                filePath: "/\(type.rawValue).jpg",
                photoType: type,
                dateTaken: Date(),
                notes: "",
                fileSize: 1024,
                dimensions: PhotoDimensions(width: 640, height: 480)
            )
        }

        let data = try JSONEncoder().encode(photos)
        let decoded = try JSONDecoder().decode([PlantPhoto].self, from: data)

        #expect(decoded.count == PhotoType.allCases.count)
        for (original, dec) in zip(photos, decoded) {
            #expect(dec.photoType == original.photoType)
            #expect(dec.filename == original.filename)
        }
    }
}

// MARK: - PhotoDimensions tests

struct PhotoDimensionsTests {
    @Test("PhotoDimensions stores width and height")
    func photoDimensionsInit() {
        let dims = PhotoDimensions(width: 3024, height: 4032)
        #expect(dims.width == 3024)
        #expect(dims.height == 4032)
    }

    @Test("PhotoDimensions zero dimensions are stored exactly")
    func photoDimensionsZero() {
        let dims = PhotoDimensions(width: 0, height: 0)
        #expect(dims.width == 0)
        #expect(dims.height == 0)
    }

    @Test("PhotoDimensions Codable round-trip")
    func photoDimensionsCodable() throws {
        let original = PhotoDimensions(width: 1280, height: 720)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PhotoDimensions.self, from: data)
        #expect(decoded.width == original.width)
        #expect(decoded.height == original.height)
    }
}

// MARK: - PhotoType tests

struct PhotoTypeTests {
    @Test("PhotoType allCases has seven elements")
    func photoTypeAllCasesCount() {
        #expect(PhotoType.allCases.count == 7)
    }

    @Test("PhotoType raw values are lowercase strings")
    func photoTypeRawValues() {
        #expect(PhotoType.general.rawValue == "general")
        #expect(PhotoType.progress.rawValue == "progress")
        #expect(PhotoType.problem.rawValue == "problem")
        #expect(PhotoType.harvest.rawValue == "harvest")
        #expect(PhotoType.flower.rawValue == "flower")
        #expect(PhotoType.seedling.rawValue == "seedling")
        #expect(PhotoType.mature.rawValue == "mature")
    }

    @Test("PhotoType displayName returns non-empty string for every case")
    func photoTypeDisplayNamesNonEmpty() {
        for type in PhotoType.allCases {
            #expect(
                !type.displayName.isEmpty,
                "displayName for \(type.rawValue) must be non-empty"
            )
        }
    }

    @Test("PhotoType displayName values match expected human-readable strings")
    func photoTypeDisplayNameValues() {
        #expect(PhotoType.general.displayName == "General")
        #expect(PhotoType.progress.displayName == "Progress")
        #expect(PhotoType.problem.displayName == "Problem")
        #expect(PhotoType.harvest.displayName == "Harvest")
        #expect(PhotoType.flower.displayName == "Flowering")
        #expect(PhotoType.seedling.displayName == "Seedling")
        #expect(PhotoType.mature.displayName == "Mature Plant")
    }

    @Test("PhotoType icon returns non-empty SF Symbol name for every case")
    func photoTypeIconsNonEmpty() {
        for type in PhotoType.allCases {
            #expect(
                !type.icon.isEmpty,
                "icon for \(type.rawValue) must be non-empty"
            )
        }
    }

    @Test("PhotoType icon values match expected SF Symbol names")
    func photoTypeIconValues() {
        #expect(PhotoType.general.icon == "photo")
        #expect(PhotoType.progress.icon == "chart.line.uptrend.xyaxis")
        #expect(PhotoType.problem.icon == "exclamationmark.triangle")
        #expect(PhotoType.harvest.icon == "basket")
        #expect(PhotoType.flower.icon == "leaf")
        #expect(PhotoType.seedling.icon == "sprout")
        #expect(PhotoType.mature.icon == "tree")
    }

    @Test("PhotoType raw values round-trip through Codable")
    func photoTypeCodableRoundTrip() throws {
        for type in PhotoType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(PhotoType.self, from: data)
            #expect(decoded == type)
        }
    }
}

// MARK: - PhotoError tests

struct PhotoErrorTests {
    @Test("compressionFailed localizedDescription is non-empty")
    func testCompressionFailed() {
        #expect(!PhotoError.compressionFailed.localizedDescription.isEmpty)
    }

    @Test("saveLocationUnavailable localizedDescription is non-empty")
    func testSaveLocationUnavailable() {
        #expect(!PhotoError.saveLocationUnavailable.localizedDescription.isEmpty)
    }

    @Test("fileNotFound localizedDescription is non-empty")
    func testFileNotFound() {
        #expect(!PhotoError.fileNotFound.localizedDescription.isEmpty)
    }

    @Test("permissionDenied localizedDescription is non-empty")
    func testPermissionDenied() {
        #expect(!PhotoError.permissionDenied.localizedDescription.isEmpty)
    }

    @Test("invalidPlantID localizedDescription is non-empty")
    func testInvalidPlantID() {
        #expect(!PhotoError.invalidPlantID.localizedDescription.isEmpty)
    }

    @Test("All PhotoError cases have distinct localizedDescriptions")
    func photoErrorDistinctDescriptions() {
        let allCases: [PhotoError] = [
            .compressionFailed,
            .saveLocationUnavailable,
            .fileNotFound,
            .permissionDenied,
            .invalidPlantID,
        ]
        let descriptions = allCases.map(\.localizedDescription)
        let uniqueDescriptions = Set(descriptions)
        #expect(
            uniqueDescriptions.count == allCases.count,
            "All PhotoError cases should have distinct descriptions"
        )
    }

    @Test("compressionFailed description mentions 'compress'")
    func compressionFailedMentionsCompress() {
        let desc = PhotoError.compressionFailed.localizedDescription.lowercased()
        #expect(desc.contains("compress"))
    }

    @Test("permissionDenied description mentions 'permission' or 'denied'")
    func permissionDeniedMentionsPermission() {
        let desc = PhotoError.permissionDenied.localizedDescription.lowercased()
        #expect(desc.contains("permission") || desc.contains("denied"))
    }

    @Test("fileNotFound description mentions 'file' or 'found'")
    func fileNotFoundMentionsFile() {
        let desc = PhotoError.fileNotFound.localizedDescription.lowercased()
        #expect(desc.contains("file") || desc.contains("found"))
    }

    @Test("invalidPlantID description mentions 'plant' or 'id'")
    func invalidPlantIDMentionsPlant() {
        let desc = PhotoError.invalidPlantID.localizedDescription.lowercased()
        #expect(desc.contains("plant") || desc.contains("id"))
    }
}

// MARK: - PhotoStorageStats tests

struct PhotoStorageStatsTests {
    @Test("totalSizeMB converts bytes to megabytes correctly")
    func testTotalSizeMB() {
        let stats = PhotoStorageStats(
            totalSizeBytes: 10 * 1024 * 1024,
            totalPhotos: 5,
            averageSizeBytes: 2 * 1024 * 1024
        )
        #expect(abs(stats.totalSizeMB - 10.0) < 0.001)
    }

    @Test("averageSizeMB converts bytes to megabytes correctly")
    func testAverageSizeMB() {
        let stats = PhotoStorageStats(
            totalSizeBytes: 10 * 1024 * 1024,
            totalPhotos: 5,
            averageSizeBytes: 2 * 1024 * 1024
        )
        #expect(abs(stats.averageSizeMB - 2.0) < 0.001)
    }

    @Test("Zero bytes produces totalSizeMB of 0.0")
    func zeroTotalSizeMB() {
        let stats = PhotoStorageStats(totalSizeBytes: 0, totalPhotos: 0, averageSizeBytes: 0)
        #expect(stats.totalSizeMB == 0.0)
    }

    @Test("Zero average bytes produces averageSizeMB of 0.0")
    func zeroAverageSizeMB() {
        let stats = PhotoStorageStats(totalSizeBytes: 1024, totalPhotos: 1, averageSizeBytes: 0)
        #expect(stats.averageSizeMB == 0.0)
    }

    @Test("PhotoStorageStats init stores raw byte values exactly")
    func photoStorageStatsInit() {
        let stats = PhotoStorageStats(totalSizeBytes: 102_400, totalPhotos: 3, averageSizeBytes: 34133)
        #expect(stats.totalSizeBytes == 102_400)
        #expect(stats.totalPhotos == 3)
        #expect(stats.averageSizeBytes == 34133)
    }

    @Test("1 MB is exactly 1048576 bytes")
    func oneMBConversion() {
        let oneMB = 1 * 1024 * 1024
        let stats = PhotoStorageStats(totalSizeBytes: oneMB, totalPhotos: 1, averageSizeBytes: oneMB)
        #expect(abs(stats.totalSizeMB - 1.0) < 0.0001)
        #expect(abs(stats.averageSizeMB - 1.0) < 0.0001)
    }

    @Test("Large storage values (500 MB) convert correctly")
    func largeStorageMB() {
        let fivehundredMB = 500 * 1024 * 1024
        let stats = PhotoStorageStats(
            totalSizeBytes: fivehundredMB,
            totalPhotos: 250,
            averageSizeBytes: 2 * 1024 * 1024
        )
        #expect(abs(stats.totalSizeMB - 500.0) < 0.01)
        #expect(abs(stats.averageSizeMB - 2.0) < 0.001)
    }
}

// MARK: - PhotoService (non-UIKit / macOS fallback)

#if !canImport(UIKit)
@Suite(.serialized)
@MainActor
struct PhotoServiceMacOSStubTests {
    @Test("requestPhotoLibraryPermission returns false on macOS stub")
    func photoLibraryPermissionStub() async throws {
        let dataService = try DataService.makeForTesting()
        let service = PhotoService(dataService: dataService)
        let result = await service.requestPhotoLibraryPermission()
        #expect(result == false)
    }

    @Test("requestCameraPermission returns false on macOS stub")
    func cameraPermissionStub() async throws {
        let dataService = try DataService.makeForTesting()
        let service = PhotoService(dataService: dataService)
        let result = await service.requestCameraPermission()
        #expect(result == false)
    }
}
#endif

// MARK: - PhotoService (UIKit / iOS only)

#if canImport(UIKit)
@Suite(.serialized)
@MainActor
struct PhotoServicePlantIDTests {
    private func makeService() throws -> PhotoService {
        let dataService = try DataService.makeForTesting()
        return PhotoService(dataService: dataService)
    }

    // A Plant with no id (id == nil) should cause savePhoto to throw .invalidPlantID.
    // We cannot set id to nil on a @Model plant directly (it has a default UUID),
    // but we CAN test deleteAllPhotos and exportPhotos on a plant whose id is nil
    // by constructing a bare PlantReminder stand-in. Instead, test the paths
    // using the public API in ways that expose the guard let plantId = plant.id check.

    @Test("savePhoto throws invalidPlantID for a plant with nil id")
    func savePhotoThrowsForNilPlantID() async throws {
        let service = try makeService()

        // Build a plant and clear its id to trigger the guard
        let plant = Plant(name: "Test", plantType: .herb)
        plant.id = nil

        let image = UIImage() // empty image; compression may produce empty data
        do {
            _ = try await service.savePhoto(image, for: plant)
            Issue.record("Expected PhotoError.invalidPlantID to be thrown")
        } catch let error as PhotoError {
            switch error {
            case .invalidPlantID:
                #expect(true)
            default:
                Issue.record("Expected .invalidPlantID, got \(error)")
            }
        }
    }

    @Test("savePhotoFromCamera delegates to savePhoto and throws for nil plant id")
    func savePhotoFromCameraThrowsForNilID() async throws {
        let service = try makeService()
        let plant = Plant(name: "Cam", plantType: .herb)
        plant.id = nil

        do {
            _ = try await service.savePhotoFromCamera(UIImage(), for: plant)
            Issue.record("Expected PhotoError.invalidPlantID")
        } catch let error as PhotoError {
            #expect(error == .invalidPlantID)
        }
    }

    @Test("savePhotoFromLibrary delegates to savePhoto and throws for nil plant id")
    func savePhotoFromLibraryThrowsForNilID() async throws {
        let service = try makeService()
        let plant = Plant(name: "Lib", plantType: .herb)
        plant.id = nil

        do {
            _ = try await service.savePhotoFromLibrary(UIImage(), for: plant)
            Issue.record("Expected PhotoError.invalidPlantID")
        } catch let error as PhotoError {
            #expect(error == .invalidPlantID)
        }
    }

    @Test("deleteAllPhotos throws invalidPlantID for a plant with nil id")
    func deleteAllPhotosThrowsForNilID() async throws {
        let service = try makeService()
        let plant = Plant(name: "Del", plantType: .herb)
        plant.id = nil

        do {
            try await service.deleteAllPhotos(for: plant)
            Issue.record("Expected PhotoError.invalidPlantID")
        } catch let error as PhotoError {
            #expect(error == .invalidPlantID)
        }
    }

    @Test("exportPhotos throws invalidPlantID for a plant with nil id")
    func exportPhotosThrowsForNilID() async throws {
        let service = try makeService()
        let plant = Plant(name: "Exp", plantType: .herb)
        plant.id = nil

        do {
            _ = try await service.exportPhotos(for: plant)
            Issue.record("Expected PhotoError.invalidPlantID")
        } catch let error as PhotoError {
            #expect(error == .invalidPlantID)
        }
    }

    @Test("getPhotos returns empty array for a plant with nil id")
    func getPhotosNilID() async throws {
        let service = try makeService()
        let plant = Plant(name: "NoID", plantType: .herb)
        plant.id = nil

        let photos = await service.getPhotos(for: plant)
        #expect(photos.isEmpty)
    }

    @Test("getRecentPhotos returns empty array for a plant with no saved photos")
    func getRecentPhotosEmpty() async throws {
        let service = try makeService()
        let plant = Plant(name: "Empty", plantType: .vegetable)
        // plant.id is set by default init

        let photos = await service.getRecentPhotos(for: plant, limit: 5)
        #expect(photos.isEmpty)
    }

    @Test("getPhotosByType returns empty dictionary for a plant with no photos")
    func getPhotosByTypeEmpty() async throws {
        let service = try makeService()
        let plant = Plant(name: "Empty", plantType: .flower)

        let grouped = await service.getPhotosByType(for: plant)
        #expect(grouped.isEmpty)
    }

    @Test("getPhotosByDate returns empty dictionary for a plant with no photos")
    func getPhotosByDateEmpty() async throws {
        let service = try makeService()
        let plant = Plant(name: "Empty", plantType: .herb)

        let grouped = await service.getPhotosByDate(for: plant)
        #expect(grouped.isEmpty)
    }

    @Test("getStorageStatistics on empty photos directory returns zero stats")
    func storageStatisticsEmpty() async throws {
        let service = try makeService()
        let stats = await service.getStorageStatistics()
        #expect(stats.totalPhotos == 0)
        #expect(stats.totalSizeBytes == 0)
        #expect(stats.averageSizeBytes == 0)
    }

    @Test("cleanupOrphanedPhotos on empty directory completes without error")
    func cleanupOrphanedPhotosEmpty() async throws {
        let service = try makeService()
        // Should not throw on an empty or non-existent photos directory
        try await service.cleanupOrphanedPhotos()
    }

    @Test("deletePhoto for a non-existent file path completes without error")
    func deleteNonExistentPhotoFile() async throws {
        let service = try makeService()
        let photo = PlantPhoto(
            id: UUID(),
            plantId: UUID(),
            filename: "ghost.jpg",
            filePath: "/nonexistent/path/ghost.jpg",
            photoType: .general,
            dateTaken: Date(),
            notes: "",
            fileSize: 0,
            dimensions: PhotoDimensions(width: 1, height: 1)
        )

        // deletePhoto only calls removeItem if the file exists; non-existent should not throw
        try await service.deletePhoto(photo)
    }

    @Test("loadPhoto returns nil for a non-existent file path")
    func loadPhotoNonExistentReturnsNil() async throws {
        let service = try makeService()
        let photo = PlantPhoto(
            id: UUID(),
            plantId: UUID(),
            filename: "missing.jpg",
            filePath: "/nonexistent/path/missing.jpg",
            photoType: .general,
            dateTaken: Date(),
            notes: "",
            fileSize: 0,
            dimensions: PhotoDimensions(width: 1, height: 1)
        )

        let result = await service.loadPhoto(from: photo)
        #expect(result == nil)
    }

    @Test("loadThumbnail returns nil for a non-existent file path")
    func loadThumbnailNonExistentReturnsNil() async throws {
        let service = try makeService()
        let photo = PlantPhoto(
            id: UUID(),
            plantId: UUID(),
            filename: "missing_thumb.jpg",
            filePath: "/nonexistent/path/missing_thumb.jpg",
            photoType: .general,
            dateTaken: Date(),
            notes: "",
            fileSize: 0,
            dimensions: PhotoDimensions(width: 1, height: 1)
        )

        let result = await service.loadThumbnail(from: photo)
        #expect(result == nil)
    }
}

// MARK: - PhotoService — full save/load/delete round-trip

@Suite(.serialized)
@MainActor
struct PhotoServiceRoundTripTests {
    private func makeService() throws -> PhotoService {
        let dataService = try DataService.makeForTesting()
        return PhotoService(dataService: dataService)
    }

    @Test("Saving a small UIImage for a valid plant returns a PlantPhoto with correct metadata")
    func saveSmallImage() async throws {
        let service = try makeService()
        let plant = Plant(name: "Basil", plantType: .herb)

        // Create a small 10x10 solid red image
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }

        let photo = try await service.savePhoto(image, for: plant, type: .seedling, notes: "Test note")

        #expect(photo.plantId == plant.id)
        #expect(photo.photoType == .seedling)
        #expect(photo.notes == "Test note")
        #expect(photo.fileSize > 0)
        #expect(photo.filename.hasSuffix(".jpg"))
        #expect(photo.filename.hasPrefix("seedling_"))
        #expect(FileManager.default.fileExists(atPath: photo.filePath))

        // Cleanup
        try? FileManager.default.removeItem(atPath: photo.filePath)
    }

    @Test("savePhoto with default type .general produces a general_ prefixed filename")
    func savePhotoDefaultTypeIsGeneral() async throws {
        let service = try makeService()
        let plant = Plant(name: "Mint", plantType: .herb)

        let image = UIGraphicsImageRenderer(size: CGSize(width: 5, height: 5)).image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 5, height: 5))
        }

        let photo = try await service.savePhoto(image, for: plant)

        #expect(photo.filename.hasPrefix("general_"))

        // Cleanup
        try? FileManager.default.removeItem(atPath: photo.filePath)
    }

    @Test("loadPhoto returns an image for a just-saved photo")
    func loadPhotoAfterSave() async throws {
        let service = try makeService()
        let plant = Plant(name: "Tomato", plantType: .vegetable)

        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }

        let photo = try await service.savePhoto(image, for: plant, type: .problem)
        let loaded = await service.loadPhoto(from: photo)

        #expect(loaded != nil)

        // Cleanup
        try? FileManager.default.removeItem(atPath: photo.filePath)
    }

    @Test("loadPhoto returns cached image on second call (cache hit)")
    func loadPhotoReturnsCachedImage() async throws {
        let service = try makeService()
        let plant = Plant(name: "Pepper", plantType: .vegetable)

        let image = UIGraphicsImageRenderer(size: CGSize(width: 6, height: 6)).image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 6, height: 6))
        }

        let photo = try await service.savePhoto(image, for: plant, type: .mature)
        let first = await service.loadPhoto(from: photo)
        let second = await service.loadPhoto(from: photo)

        #expect(first != nil)
        #expect(second != nil)

        // Cleanup
        try? FileManager.default.removeItem(atPath: photo.filePath)
    }

    @Test("loadThumbnail generates a thumbnail from a saved image")
    func loadThumbnailAfterSave() async throws {
        let service = try makeService()
        let plant = Plant(name: "Cactus", plantType: .succulent)

        let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200)).image { ctx in
            UIColor.purple.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        }

        let photo = try await service.savePhoto(image, for: plant, type: .flower)
        let thumbSize = CGSize(width: 50, height: 50)
        let thumbnail = await service.loadThumbnail(from: photo, size: thumbSize)

        #expect(thumbnail != nil)
        if let thumb = thumbnail {
            #expect(abs(thumb.size.width - 50.0) < 1.0)
            #expect(abs(thumb.size.height - 50.0) < 1.0)
        }

        // Cleanup
        try? FileManager.default.removeItem(atPath: photo.filePath)
    }

    @Test("deletePhoto removes the file from disk")
    func deletePhotoRemovesFile() async throws {
        let service = try makeService()
        let plant = Plant(name: "Fern", plantType: .houseplant)

        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.cyan.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        let photo = try await service.savePhoto(image, for: plant, type: .progress)
        #expect(FileManager.default.fileExists(atPath: photo.filePath))

        try await service.deletePhoto(photo)
        #expect(!FileManager.default.fileExists(atPath: photo.filePath))
    }

    @Test("deleteAllPhotos removes the plant's entire directory")
    func deleteAllPhotosRemovesDirectory() async throws {
        let service = try makeService()
        let plant = Plant(name: "Oak", plantType: .tree)
        guard let plantId = plant.id else {
            Issue.record("plant.id unexpectedly nil")
            return
        }

        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.brown.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        let photo = try await service.savePhoto(image, for: plant, type: .general)
        let plantDir = (photo.filePath as NSString).deletingLastPathComponent
        #expect(FileManager.default.fileExists(atPath: plantDir))

        try await service.deleteAllPhotos(for: plant)

        // The plant directory (plant_<uuid>) should be gone
        let docs = try #require(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let expected = docs
            .appendingPathComponent("PlantPhotos")
            .appendingPathComponent("plant_\(plantId.uuidString)")
        #expect(!FileManager.default.fileExists(atPath: expected.path))
    }

    @Test("getPhotos with type filter returns only matching photos")
    func getPhotosWithTypeFilter() async throws {
        let service = try makeService()
        let plant = Plant(name: "Rose", plantType: .flower)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        let flowerPhoto = try await service.savePhoto(img, for: plant, type: .flower)
        let generalPhoto = try await service.savePhoto(img, for: plant, type: .general)

        let flowerPhotos = await service.getPhotos(for: plant, type: .flower)
        let generalPhotos = await service.getPhotos(for: plant, type: .general)
        let allPhotos = await service.getPhotos(for: plant)

        #expect(flowerPhotos.allSatisfy { $0.photoType == .flower })
        #expect(generalPhotos.allSatisfy { $0.photoType == .general })
        #expect(allPhotos.count >= 2)

        // Cleanup
        try? FileManager.default.removeItem(atPath: flowerPhoto.filePath)
        try? FileManager.default.removeItem(atPath: generalPhoto.filePath)
    }

    @Test("getRecentPhotos respects the limit parameter")
    func getRecentPhotosLimit() async throws {
        let service = try makeService()
        let plant = Plant(name: "Sunflower", plantType: .flower)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.yellow.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        // Save 3 photos
        var saved: [PlantPhoto] = []
        for _ in 0 ..< 3 {
            let photo = try await service.savePhoto(img, for: plant, type: .general)
            saved.append(photo)
        }

        let recent = await service.getRecentPhotos(for: plant, limit: 2)
        #expect(recent.count <= 2)

        // Cleanup
        for photo in saved {
            try? FileManager.default.removeItem(atPath: photo.filePath)
        }
    }

    @Test("getPhotosByType groups photos by their type correctly")
    func getPhotosByTypeGrouping() async throws {
        let service = try makeService()
        let plant = Plant(name: "Iris", plantType: .flower)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        let p1 = try await service.savePhoto(img, for: plant, type: .harvest)
        let p2 = try await service.savePhoto(img, for: plant, type: .harvest)
        let p3 = try await service.savePhoto(img, for: plant, type: .problem)

        let grouped = await service.getPhotosByType(for: plant)

        let harvestGroup = grouped[.harvest] ?? []
        let problemGroup = grouped[.problem] ?? []

        #expect(harvestGroup.count >= 2)
        #expect(problemGroup.count >= 1)
        #expect(harvestGroup.allSatisfy { $0.photoType == .harvest })
        #expect(problemGroup.allSatisfy { $0.photoType == .problem })

        // Cleanup
        for photo in [p1, p2, p3] {
            try? FileManager.default.removeItem(atPath: photo.filePath)
        }
    }

    @Test("getPhotosByDate groups photos by the date they were taken")
    func getPhotosByDateGrouping() async throws {
        let service = try makeService()
        let plant = Plant(name: "Lavender", plantType: .flower)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.purple.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        let p1 = try await service.savePhoto(img, for: plant, type: .general)
        let p2 = try await service.savePhoto(img, for: plant, type: .general)

        let grouped = await service.getPhotosByDate(for: plant)

        // Both photos were taken today — they should share the same date key
        #expect(!grouped.isEmpty)
        let totalFromGrouped = grouped.values.reduce(0) { $0 + $1.count }
        #expect(totalFromGrouped >= 2)

        // Cleanup
        for photo in [p1, p2] {
            try? FileManager.default.removeItem(atPath: photo.filePath)
        }
    }
}

// MARK: - PhotoService — loadImage from URL string

@Suite(.serialized)
@MainActor
struct PhotoServiceLoadImageTests {
    private func makeService() throws -> PhotoService {
        let dataService = try DataService.makeForTesting()
        return PhotoService(dataService: dataService)
    }

    @Test("loadImage returns nil for an invalid URL string")
    func loadImageInvalidURL() async throws {
        let service = try makeService()
        let result = await service.loadImage(from: "")
        #expect(result == nil)
    }

    @Test("loadImage returns nil for a non-existent file path")
    func loadImageNonExistentPath() async throws {
        let service = try makeService()
        let result = await service.loadImage(from: "/nonexistent/path/image.jpg")
        #expect(result == nil)
    }

    @Test("loadImage returns nil for a file:// URL pointing to a missing file")
    func loadImageMissingFileURL() async throws {
        let service = try makeService()
        let result = await service.loadImage(from: "file:///tmp/does_not_exist_\(UUID().uuidString).jpg")
        #expect(result == nil)
    }

    @Test("loadImage loads an image from a valid file path on disk")
    func loadImageFromDiskPath() async throws {
        let service = try makeService()

        // Write a small JPEG to a temp file
        let img = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("loadimage_test_\(UUID().uuidString).jpg")
        let data = try #require(img.jpegData(compressionQuality: 0.8))
        try data.write(to: tempFile)

        let loaded = await service.loadImage(from: tempFile.path)
        #expect(loaded != nil)

        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }

    @Test("loadImage loads an image from a file:// URL string")
    func loadImageFromFileURL() async throws {
        let service = try makeService()

        let img = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("loadimage_fileurl_\(UUID().uuidString).jpg")
        let data = try #require(img.jpegData(compressionQuality: 0.8))
        try data.write(to: tempFile)

        let loaded = await service.loadImage(from: tempFile.absoluteString)
        #expect(loaded != nil)

        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }

    @Test("loadImage caches the image on second call")
    func loadImageCachesResult() async throws {
        let service = try makeService()

        let img = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("loadimage_cache_\(UUID().uuidString).jpg")
        let data = try #require(img.jpegData(compressionQuality: 0.8))
        try data.write(to: tempFile)

        let first = await service.loadImage(from: tempFile.path)
        #expect(first != nil)

        // Delete the file — second load should still succeed from cache
        try FileManager.default.removeItem(at: tempFile)

        let second = await service.loadImage(from: tempFile.path)
        #expect(second != nil)
    }
}

// MARK: - PhotoService — storage statistics after saving

@Suite(.serialized)
@MainActor
struct PhotoServiceStorageStatsWithDataTests {
    private func makeService() throws -> PhotoService {
        let dataService = try DataService.makeForTesting()
        return PhotoService(dataService: dataService)
    }

    @Test("getStorageStatistics returns non-zero after saving a photo")
    func storageStatsNonZeroAfterSave() async throws {
        let service = try makeService()
        let plant = Plant(name: "StatsPlant", plantType: .herb)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }

        let photo = try await service.savePhoto(img, for: plant, type: .general)

        let stats = await service.getStorageStatistics()
        #expect(stats.totalPhotos >= 1)
        #expect(stats.totalSizeBytes > 0)
        #expect(stats.averageSizeBytes > 0)

        // Cleanup
        try await service.deletePhoto(photo)
    }
}

// MARK: - PhotoService — export photos success path

@Suite(.serialized)
@MainActor
struct PhotoServiceExportTests {
    private func makeService() throws -> PhotoService {
        let dataService = try DataService.makeForTesting()
        return PhotoService(dataService: dataService)
    }

    @Test("exportPhotos returns a valid URL for a plant with saved photos")
    func exportPhotosSuccess() async throws {
        let service = try makeService()
        let plant = Plant(name: "ExportPlant", plantType: .flower)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.yellow.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        let photo = try await service.savePhoto(img, for: plant, type: .harvest)

        let exportURL = try await service.exportPhotos(for: plant)
        #expect(FileManager.default.fileExists(atPath: exportURL.path))

        // Cleanup
        try? FileManager.default.removeItem(at: exportURL)
        try? FileManager.default.removeItem(atPath: photo.filePath)
        try await service.deleteAllPhotos(for: plant)
    }
}

// MARK: - PhotoService — cleanup orphaned photos

@Suite(.serialized)
@MainActor
struct PhotoServiceCleanupTests {
    private func makeService() throws -> PhotoService {
        let dataService = try DataService.makeForTesting()
        return PhotoService(dataService: dataService)
    }

    @Test("cleanupOrphanedPhotos removes files without metadata")
    func cleanupRemovesOrphanedFiles() async throws {
        let service = try makeService()
        let plant = Plant(name: "OrphanPlant", plantType: .herb)
        guard let plantId = plant.id else {
            Issue.record("plant.id unexpectedly nil")
            return
        }

        // Save a real photo to create the directory
        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let photo = try await service.savePhoto(img, for: plant, type: .general)

        // Drop an orphaned file into the plant's photo directory (no metadata entry)
        let plantDir = (photo.filePath as NSString).deletingLastPathComponent
        let orphanedFile = URL(fileURLWithPath: plantDir).appendingPathComponent("orphan_\(UUID().uuidString).jpg")
        let fakeImageData = try #require("fake image data".data(using: .utf8))
        try fakeImageData.write(to: orphanedFile)
        #expect(FileManager.default.fileExists(atPath: orphanedFile.path))

        // Run cleanup
        try await service.cleanupOrphanedPhotos()

        // The orphaned file should be removed, but the legitimate photo should remain
        #expect(!FileManager.default.fileExists(atPath: orphanedFile.path))
        #expect(FileManager.default.fileExists(atPath: photo.filePath))

        // Cleanup
        try await service.deleteAllPhotos(for: plant)
    }
}

// MARK: - PhotoService — cross-plant isolation

@Suite(.serialized)
@MainActor
struct PhotoServiceIsolationTests {
    private func makeService() throws -> PhotoService {
        let dataService = try DataService.makeForTesting()
        return PhotoService(dataService: dataService)
    }

    @Test("Photos saved for plant A do not appear in getPhotos for plant B")
    func crossPlantIsolation() async throws {
        let service = try makeService()
        let plantA = Plant(name: "PlantA", plantType: .herb)
        let plantB = Plant(name: "PlantB", plantType: .vegetable)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        let photoA = try await service.savePhoto(img, for: plantA, type: .seedling, notes: "A only")

        let photosA = await service.getPhotos(for: plantA)
        let photosB = await service.getPhotos(for: plantB)

        #expect(photosA.contains { $0.id == photoA.id })
        #expect(photosB.isEmpty)

        // Cleanup
        try await service.deleteAllPhotos(for: plantA)
    }

    @Test("deleteAllPhotos for plant A does not affect plant B photos")
    func deleteAllPhotosIsolation() async throws {
        let service = try makeService()
        let plantA = Plant(name: "IsoA", plantType: .herb)
        let plantB = Plant(name: "IsoB", plantType: .flower)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        _ = try await service.savePhoto(img, for: plantA, type: .general)
        let photoB = try await service.savePhoto(img, for: plantB, type: .general)

        try await service.deleteAllPhotos(for: plantA)

        let photosA = await service.getPhotos(for: plantA)
        let photosB = await service.getPhotos(for: plantB)

        #expect(photosA.isEmpty)
        #expect(photosB.contains { $0.id == photoB.id })

        // Cleanup
        try await service.deleteAllPhotos(for: plantB)
    }
}

// MARK: - PhotoService — getPhotos limit parameter

@Suite(.serialized)
@MainActor
struct PhotoServiceGetPhotosLimitTests {
    private func makeService() throws -> PhotoService {
        let dataService = try DataService.makeForTesting()
        return PhotoService(dataService: dataService)
    }

    @Test("getPhotos respects the limit parameter")
    func getPhotosLimit() async throws {
        let service = try makeService()
        let plant = Plant(name: "LimitPlant", plantType: .herb)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        // Save 4 photos
        for _ in 0 ..< 4 {
            _ = try await service.savePhoto(img, for: plant, type: .general)
        }

        let limited = await service.getPhotos(for: plant, limit: 2)
        #expect(limited.count == 2)

        let all = await service.getPhotos(for: plant, limit: 50)
        #expect(all.count >= 4)

        // Cleanup
        try await service.deleteAllPhotos(for: plant)
    }

    @Test("getPhotos returns results sorted by date descending (most recent first)")
    func getPhotosSortOrder() async throws {
        let service = try makeService()
        let plant = Plant(name: "SortPlant", plantType: .vegetable)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.cyan.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        // Save 3 photos — they should be ordered newest first
        _ = try await service.savePhoto(img, for: plant, type: .general, notes: "first")
        _ = try await service.savePhoto(img, for: plant, type: .general, notes: "second")
        _ = try await service.savePhoto(img, for: plant, type: .general, notes: "third")

        let photos = await service.getPhotos(for: plant)

        // Verify descending date order
        for i in 0 ..< photos.count - 1 {
            #expect(
                photos[i].dateTaken >= photos[i + 1].dateTaken,
                "Photos should be sorted newest first"
            )
        }

        // Cleanup
        try await service.deleteAllPhotos(for: plant)
    }
}

// MARK: - PhotoService — notes persistence

@Suite(.serialized)
@MainActor
struct PhotoServiceNotesPersistenceTests {
    private func makeService() throws -> PhotoService {
        let dataService = try DataService.makeForTesting()
        return PhotoService(dataService: dataService)
    }

    @Test("Saved photo notes are retrievable via getPhotos")
    func notesPersistedAndRetrievable() async throws {
        let service = try makeService()
        let plant = Plant(name: "NotesPlant", plantType: .herb)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.magenta.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        let savedPhoto = try await service.savePhoto(img, for: plant, type: .progress, notes: "Grew 2 inches today")
        #expect(savedPhoto.notes == "Grew 2 inches today")

        let retrieved = await service.getPhotos(for: plant)
        let matchingPhoto = retrieved.first { $0.id == savedPhoto.id }
        #expect(matchingPhoto != nil)
        #expect(matchingPhoto?.notes == "Grew 2 inches today")

        // Cleanup
        try await service.deleteAllPhotos(for: plant)
    }

    @Test("Saved photo with empty notes returns empty string")
    func emptyNotesPersisted() async throws {
        let service = try makeService()
        let plant = Plant(name: "EmptyNotesPlant", plantType: .flower)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        let savedPhoto = try await service.savePhoto(img, for: plant)
        #expect(savedPhoto.notes == "")

        // Cleanup
        try await service.deleteAllPhotos(for: plant)
    }
}

// MARK: - PhotoService — deletePhoto metadata removal

@Suite(.serialized)
@MainActor
struct PhotoServiceDeleteMetadataTests {
    private func makeService() throws -> PhotoService {
        let dataService = try DataService.makeForTesting()
        return PhotoService(dataService: dataService)
    }

    @Test("deletePhoto removes the photo from getPhotos results")
    func deletePhotoRemovesFromMetadata() async throws {
        let service = try makeService()
        let plant = Plant(name: "DeleteMeta", plantType: .herb)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        let photo1 = try await service.savePhoto(img, for: plant, type: .general, notes: "keep")
        let photo2 = try await service.savePhoto(img, for: plant, type: .problem, notes: "delete")

        try await service.deletePhoto(photo2)

        let remaining = await service.getPhotos(for: plant)
        #expect(remaining.contains { $0.id == photo1.id })
        #expect(!remaining.contains { $0.id == photo2.id })

        // Cleanup
        try await service.deleteAllPhotos(for: plant)
    }
}

// MARK: - PhotoService — savePhotoFromCamera and savePhotoFromLibrary

@Suite(.serialized)
@MainActor
struct PhotoServiceConvenienceMethodTests {
    private func makeService() throws -> PhotoService {
        let dataService = try DataService.makeForTesting()
        return PhotoService(dataService: dataService)
    }

    // INTEGRATION GAP: Testing actual camera/photo library access requires hardware.
    // These tests verify that the convenience methods delegate correctly to savePhoto
    // by confirming the returned PlantPhoto has correct metadata.

    @Test("savePhotoFromCamera returns a PlantPhoto with correct type and notes")
    func savePhotoFromCameraMetadata() async throws {
        let service = try makeService()
        let plant = Plant(name: "CameraPlant", plantType: .herb)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }

        let photo = try await service.savePhotoFromCamera(img, for: plant, type: .progress, notes: "From camera")
        #expect(photo.photoType == .progress)
        #expect(photo.notes == "From camera")
        #expect(photo.plantId == plant.id)
        #expect(photo.fileSize > 0)

        // Cleanup
        try await service.deleteAllPhotos(for: plant)
    }

    @Test("savePhotoFromLibrary returns a PlantPhoto with correct type and notes")
    func savePhotoFromLibraryMetadata() async throws {
        let service = try makeService()
        let plant = Plant(name: "LibraryPlant", plantType: .vegetable)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }

        let photo = try await service.savePhotoFromLibrary(img, for: plant, type: .harvest, notes: "From library")
        #expect(photo.photoType == .harvest)
        #expect(photo.notes == "From library")
        #expect(photo.plantId == plant.id)
        #expect(photo.fileSize > 0)

        // Cleanup
        try await service.deleteAllPhotos(for: plant)
    }
}
#endif
