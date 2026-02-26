import Testing
import Foundation
#if canImport(UIKit)
import UIKit
#endif
@testable import GrowWiseServices
@testable import GrowWiseModels

// MARK: - PlantPhoto value-type tests

@Suite("PlantPhoto — init and properties")
struct PlantPhotoInitTests {

    @Test("PlantPhoto init stores all provided fields correctly")
    func testPlantPhotoInit() {
        let id        = UUID()
        let plantId   = UUID()
        let taken     = Date()
        let dims      = PhotoDimensions(width: 1920, height: 1080)
        let photo     = PlantPhoto(
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

        #expect(photo.id         == id)
        #expect(photo.plantId    == plantId)
        #expect(photo.filename   == "progress_20260226_120000.jpg")
        #expect(photo.photoType  == .progress)
        #expect(photo.dateTaken  == taken)
        #expect(photo.notes      == "Looking healthy")
        #expect(photo.fileSize   == 204_800)
        #expect(photo.dimensions.width  == 1920)
        #expect(photo.dimensions.height == 1080)
    }

    @Test("PlantPhoto Identifiable uses the id property")
    func testPlantPhotoIdentifiable() {
        let id    = UUID()
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
    func testPlantPhotoCodableRoundTrip() throws {
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

        let data     = try JSONEncoder().encode(original)
        let decoded  = try JSONDecoder().decode(PlantPhoto.self, from: data)

        #expect(decoded.id          == original.id)
        #expect(decoded.plantId     == original.plantId)
        #expect(decoded.filename    == original.filename)
        #expect(decoded.filePath    == original.filePath)
        #expect(decoded.photoType   == original.photoType)
        #expect(decoded.notes       == original.notes)
        #expect(decoded.fileSize    == original.fileSize)
        #expect(decoded.dimensions.width  == original.dimensions.width)
        #expect(decoded.dimensions.height == original.dimensions.height)
        // Date encoding may have sub-second loss; compare to within 1s
        #expect(abs(decoded.dateTaken.timeIntervalSince(original.dateTaken)) < 1.0)
    }

    @Test("Two PlantPhoto values with different IDs are not equal via Identifiable")
    func testPlantPhotoDistinctIDs() {
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
    func testPlantPhotoArrayCodable() throws {
        let plantId = UUID()
        let photos  = PhotoType.allCases.map { type in
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

        let data    = try JSONEncoder().encode(photos)
        let decoded = try JSONDecoder().decode([PlantPhoto].self, from: data)

        #expect(decoded.count == PhotoType.allCases.count)
        for (original, dec) in zip(photos, decoded) {
            #expect(dec.photoType == original.photoType)
            #expect(dec.filename  == original.filename)
        }
    }
}

// MARK: - PhotoDimensions tests

@Suite("PhotoDimensions — init and Codable")
struct PhotoDimensionsTests {

    @Test("PhotoDimensions stores width and height")
    func testPhotoDimensionsInit() {
        let dims = PhotoDimensions(width: 3024, height: 4032)
        #expect(dims.width  == 3024)
        #expect(dims.height == 4032)
    }

    @Test("PhotoDimensions zero dimensions are stored exactly")
    func testPhotoDimensionsZero() {
        let dims = PhotoDimensions(width: 0, height: 0)
        #expect(dims.width  == 0)
        #expect(dims.height == 0)
    }

    @Test("PhotoDimensions Codable round-trip")
    func testPhotoDimensionsCodable() throws {
        let original = PhotoDimensions(width: 1280, height: 720)
        let data     = try JSONEncoder().encode(original)
        let decoded  = try JSONDecoder().decode(PhotoDimensions.self, from: data)
        #expect(decoded.width  == original.width)
        #expect(decoded.height == original.height)
    }
}

// MARK: - PhotoType tests

@Suite("PhotoType — enum values")
struct PhotoTypeTests {

    @Test("PhotoType allCases has seven elements")
    func testPhotoTypeAllCasesCount() {
        #expect(PhotoType.allCases.count == 7)
    }

    @Test("PhotoType raw values are lowercase strings")
    func testPhotoTypeRawValues() {
        #expect(PhotoType.general.rawValue   == "general")
        #expect(PhotoType.progress.rawValue  == "progress")
        #expect(PhotoType.problem.rawValue   == "problem")
        #expect(PhotoType.harvest.rawValue   == "harvest")
        #expect(PhotoType.flower.rawValue    == "flower")
        #expect(PhotoType.seedling.rawValue  == "seedling")
        #expect(PhotoType.mature.rawValue    == "mature")
    }

    @Test("PhotoType displayName returns non-empty string for every case")
    func testPhotoTypeDisplayNamesNonEmpty() {
        for type in PhotoType.allCases {
            #expect(!type.displayName.isEmpty,
                    "displayName for \(type.rawValue) must be non-empty")
        }
    }

    @Test("PhotoType displayName values match expected human-readable strings")
    func testPhotoTypeDisplayNameValues() {
        #expect(PhotoType.general.displayName  == "General")
        #expect(PhotoType.progress.displayName == "Progress")
        #expect(PhotoType.problem.displayName  == "Problem")
        #expect(PhotoType.harvest.displayName  == "Harvest")
        #expect(PhotoType.flower.displayName   == "Flowering")
        #expect(PhotoType.seedling.displayName == "Seedling")
        #expect(PhotoType.mature.displayName   == "Mature Plant")
    }

    @Test("PhotoType icon returns non-empty SF Symbol name for every case")
    func testPhotoTypeIconsNonEmpty() {
        for type in PhotoType.allCases {
            #expect(!type.icon.isEmpty,
                    "icon for \(type.rawValue) must be non-empty")
        }
    }

    @Test("PhotoType icon values match expected SF Symbol names")
    func testPhotoTypeIconValues() {
        #expect(PhotoType.general.icon   == "photo")
        #expect(PhotoType.progress.icon  == "chart.line.uptrend.xyaxis")
        #expect(PhotoType.problem.icon   == "exclamationmark.triangle")
        #expect(PhotoType.harvest.icon   == "basket")
        #expect(PhotoType.flower.icon    == "leaf")
        #expect(PhotoType.seedling.icon  == "sprout")
        #expect(PhotoType.mature.icon    == "tree")
    }

    @Test("PhotoType raw values round-trip through Codable")
    func testPhotoTypeCodableRoundTrip() throws {
        for type in PhotoType.allCases {
            let data    = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(PhotoType.self, from: data)
            #expect(decoded == type)
        }
    }
}

// MARK: - PhotoError tests

@Suite("PhotoError — localizedDescription")
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
    func testPhotoErrorDistinctDescriptions() {
        let allCases: [PhotoError] = [
            .compressionFailed,
            .saveLocationUnavailable,
            .fileNotFound,
            .permissionDenied,
            .invalidPlantID
        ]
        let descriptions = allCases.map { $0.localizedDescription }
        let uniqueDescriptions = Set(descriptions)
        #expect(uniqueDescriptions.count == allCases.count,
                "All PhotoError cases should have distinct descriptions")
    }

    @Test("compressionFailed description mentions 'compress'")
    func testCompressionFailedMentionsCompress() {
        let desc = PhotoError.compressionFailed.localizedDescription.lowercased()
        #expect(desc.contains("compress"))
    }

    @Test("permissionDenied description mentions 'permission' or 'denied'")
    func testPermissionDeniedMentionsPermission() {
        let desc = PhotoError.permissionDenied.localizedDescription.lowercased()
        #expect(desc.contains("permission") || desc.contains("denied"))
    }

    @Test("fileNotFound description mentions 'file' or 'found'")
    func testFileNotFoundMentionsFile() {
        let desc = PhotoError.fileNotFound.localizedDescription.lowercased()
        #expect(desc.contains("file") || desc.contains("found"))
    }

    @Test("invalidPlantID description mentions 'plant' or 'id'")
    func testInvalidPlantIDMentionsPlant() {
        let desc = PhotoError.invalidPlantID.localizedDescription.lowercased()
        #expect(desc.contains("plant") || desc.contains("id"))
    }
}

// MARK: - PhotoStorageStats tests

@Suite("PhotoStorageStats — computed properties")
struct PhotoStorageStatsTests {

    @Test("totalSizeMB converts bytes to megabytes correctly")
    func testTotalSizeMB() {
        let stats = PhotoStorageStats(totalSizeBytes: 10 * 1024 * 1024,
                                      totalPhotos: 5,
                                      averageSizeBytes: 2 * 1024 * 1024)
        #expect(abs(stats.totalSizeMB - 10.0) < 0.001)
    }

    @Test("averageSizeMB converts bytes to megabytes correctly")
    func testAverageSizeMB() {
        let stats = PhotoStorageStats(totalSizeBytes: 10 * 1024 * 1024,
                                      totalPhotos: 5,
                                      averageSizeBytes: 2 * 1024 * 1024)
        #expect(abs(stats.averageSizeMB - 2.0) < 0.001)
    }

    @Test("Zero bytes produces totalSizeMB of 0.0")
    func testZeroTotalSizeMB() {
        let stats = PhotoStorageStats(totalSizeBytes: 0, totalPhotos: 0, averageSizeBytes: 0)
        #expect(stats.totalSizeMB == 0.0)
    }

    @Test("Zero average bytes produces averageSizeMB of 0.0")
    func testZeroAverageSizeMB() {
        let stats = PhotoStorageStats(totalSizeBytes: 1024, totalPhotos: 1, averageSizeBytes: 0)
        #expect(stats.averageSizeMB == 0.0)
    }

    @Test("PhotoStorageStats init stores raw byte values exactly")
    func testPhotoStorageStatsInit() {
        let stats = PhotoStorageStats(totalSizeBytes: 102400, totalPhotos: 3, averageSizeBytes: 34133)
        #expect(stats.totalSizeBytes   == 102400)
        #expect(stats.totalPhotos      == 3)
        #expect(stats.averageSizeBytes == 34133)
    }

    @Test("1 MB is exactly 1048576 bytes")
    func testOneMBConversion() {
        let oneMB = 1 * 1024 * 1024
        let stats = PhotoStorageStats(totalSizeBytes: oneMB, totalPhotos: 1, averageSizeBytes: oneMB)
        #expect(abs(stats.totalSizeMB   - 1.0) < 0.0001)
        #expect(abs(stats.averageSizeMB - 1.0) < 0.0001)
    }

    @Test("Large storage values (500 MB) convert correctly")
    func testLargeStorageMB() {
        let fivehundredMB = 500 * 1024 * 1024
        let stats = PhotoStorageStats(totalSizeBytes: fivehundredMB,
                                      totalPhotos: 250,
                                      averageSizeBytes: 2 * 1024 * 1024)
        #expect(abs(stats.totalSizeMB - 500.0) < 0.01)
        #expect(abs(stats.averageSizeMB - 2.0) < 0.001)
    }
}

// MARK: - PhotoService (UIKit / iOS only)

#if canImport(UIKit)
@Suite("PhotoService — plant ID validation", .serialized)
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
    func testSavePhotoThrowsForNilPlantID() async throws {
        let service = try makeService()

        // Build a plant and clear its id to trigger the guard
        let plant = Plant(name: "Test", plantType: .herb)
        plant.id = nil

        let image = UIImage()  // empty image; compression may produce empty data
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
    func testSavePhotoFromCameraThrowsForNilID() async throws {
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
    func testSavePhotoFromLibraryThrowsForNilID() async throws {
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
    func testDeleteAllPhotosThrowsForNilID() async throws {
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
    func testExportPhotosThrowsForNilID() async throws {
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
    func testGetPhotosNilID() async throws {
        let service = try makeService()
        let plant = Plant(name: "NoID", plantType: .herb)
        plant.id = nil

        let photos = await service.getPhotos(for: plant)
        #expect(photos.isEmpty)
    }

    @Test("getRecentPhotos returns empty array for a plant with no saved photos")
    func testGetRecentPhotosEmpty() async throws {
        let service = try makeService()
        let plant = Plant(name: "Empty", plantType: .vegetable)
        // plant.id is set by default init

        let photos = await service.getRecentPhotos(for: plant, limit: 5)
        #expect(photos.isEmpty)
    }

    @Test("getPhotosByType returns empty dictionary for a plant with no photos")
    func testGetPhotosByTypeEmpty() async throws {
        let service = try makeService()
        let plant = Plant(name: "Empty", plantType: .flower)

        let grouped = await service.getPhotosByType(for: plant)
        #expect(grouped.isEmpty)
    }

    @Test("getPhotosByDate returns empty dictionary for a plant with no photos")
    func testGetPhotosByDateEmpty() async throws {
        let service = try makeService()
        let plant = Plant(name: "Empty", plantType: .herb)

        let grouped = await service.getPhotosByDate(for: plant)
        #expect(grouped.isEmpty)
    }

    @Test("getStorageStatistics on empty photos directory returns zero stats")
    func testStorageStatisticsEmpty() async throws {
        let service = try makeService()
        let stats = await service.getStorageStatistics()
        #expect(stats.totalPhotos == 0)
        #expect(stats.totalSizeBytes == 0)
        #expect(stats.averageSizeBytes == 0)
    }

    @Test("cleanupOrphanedPhotos on empty directory completes without error")
    func testCleanupOrphanedPhotosEmpty() async throws {
        let service = try makeService()
        // Should not throw on an empty or non-existent photos directory
        try await service.cleanupOrphanedPhotos()
    }

    @Test("deletePhoto for a non-existent file path completes without error")
    func testDeleteNonExistentPhotoFile() async throws {
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
    func testLoadPhotoNonExistentReturnsNil() async throws {
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
    func testLoadThumbnailNonExistentReturnsNil() async throws {
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

@Suite("PhotoService — save/load/delete round-trip", .serialized)
@MainActor
struct PhotoServiceRoundTripTests {

    private func makeService() throws -> PhotoService {
        let dataService = try DataService.makeForTesting()
        return PhotoService(dataService: dataService)
    }

    @Test("Saving a small UIImage for a valid plant returns a PlantPhoto with correct metadata")
    func testSaveSmallImage() async throws {
        let service = try makeService()
        let plant   = Plant(name: "Basil", plantType: .herb)

        // Create a small 10x10 solid red image
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }

        let photo = try await service.savePhoto(image, for: plant, type: .seedling, notes: "Test note")

        #expect(photo.plantId     == plant.id)
        #expect(photo.photoType   == .seedling)
        #expect(photo.notes       == "Test note")
        #expect(photo.fileSize    > 0)
        #expect(photo.filename.hasSuffix(".jpg"))
        #expect(photo.filename.hasPrefix("seedling_"))
        #expect(FileManager.default.fileExists(atPath: photo.filePath))

        // Cleanup
        try? FileManager.default.removeItem(atPath: photo.filePath)
    }

    @Test("savePhoto with default type .general produces a general_ prefixed filename")
    func testSavePhotoDefaultTypeIsGeneral() async throws {
        let service = try makeService()
        let plant   = Plant(name: "Mint", plantType: .herb)

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
    func testLoadPhotoAfterSave() async throws {
        let service = try makeService()
        let plant   = Plant(name: "Tomato", plantType: .vegetable)

        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }

        let photo  = try await service.savePhoto(image, for: plant, type: .problem)
        let loaded = await service.loadPhoto(from: photo)

        #expect(loaded != nil)

        // Cleanup
        try? FileManager.default.removeItem(atPath: photo.filePath)
    }

    @Test("loadPhoto returns cached image on second call (cache hit)")
    func testLoadPhotoReturnsCachedImage() async throws {
        let service = try makeService()
        let plant   = Plant(name: "Pepper", plantType: .vegetable)

        let image = UIGraphicsImageRenderer(size: CGSize(width: 6, height: 6)).image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 6, height: 6))
        }

        let photo   = try await service.savePhoto(image, for: plant, type: .mature)
        let first   = await service.loadPhoto(from: photo)
        let second  = await service.loadPhoto(from: photo)

        #expect(first  != nil)
        #expect(second != nil)

        // Cleanup
        try? FileManager.default.removeItem(atPath: photo.filePath)
    }

    @Test("loadThumbnail generates a thumbnail from a saved image")
    func testLoadThumbnailAfterSave() async throws {
        let service = try makeService()
        let plant   = Plant(name: "Cactus", plantType: .succulent)

        let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200)).image { ctx in
            UIColor.purple.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        }

        let photo     = try await service.savePhoto(image, for: plant, type: .flower)
        let thumbSize = CGSize(width: 50, height: 50)
        let thumbnail = await service.loadThumbnail(from: photo, size: thumbSize)

        #expect(thumbnail != nil)
        if let thumb = thumbnail {
            #expect(abs(thumb.size.width  - 50.0) < 1.0)
            #expect(abs(thumb.size.height - 50.0) < 1.0)
        }

        // Cleanup
        try? FileManager.default.removeItem(atPath: photo.filePath)
    }

    @Test("deletePhoto removes the file from disk")
    func testDeletePhotoRemovesFile() async throws {
        let service = try makeService()
        let plant   = Plant(name: "Fern", plantType: .houseplant)

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
    func testDeleteAllPhotosRemovesDirectory() async throws {
        let service = try makeService()
        let plant   = Plant(name: "Oak", plantType: .tree)
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
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let expected = docs
            .appendingPathComponent("PlantPhotos")
            .appendingPathComponent("plant_\(plantId.uuidString)")
        #expect(!FileManager.default.fileExists(atPath: expected.path))
    }

    @Test("getPhotos with type filter returns only matching photos")
    func testGetPhotosWithTypeFilter() async throws {
        let service = try makeService()
        let plant   = Plant(name: "Rose", plantType: .flower)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        let flowerPhoto   = try await service.savePhoto(img, for: plant, type: .flower)
        let generalPhoto  = try await service.savePhoto(img, for: plant, type: .general)

        let flowerPhotos  = await service.getPhotos(for: plant, type: .flower)
        let generalPhotos = await service.getPhotos(for: plant, type: .general)
        let allPhotos     = await service.getPhotos(for: plant)

        #expect(flowerPhotos.allSatisfy  { $0.photoType == .flower  })
        #expect(generalPhotos.allSatisfy { $0.photoType == .general })
        #expect(allPhotos.count >= 2)

        // Cleanup
        try? FileManager.default.removeItem(atPath: flowerPhoto.filePath)
        try? FileManager.default.removeItem(atPath: generalPhoto.filePath)
    }

    @Test("getRecentPhotos respects the limit parameter")
    func testGetRecentPhotosLimit() async throws {
        let service = try makeService()
        let plant   = Plant(name: "Sunflower", plantType: .flower)

        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.yellow.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        // Save 3 photos
        var saved: [PlantPhoto] = []
        for _ in 0..<3 {
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
    func testGetPhotosByTypeGrouping() async throws {
        let service = try makeService()
        let plant   = Plant(name: "Iris", plantType: .flower)

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
    func testGetPhotosByDateGrouping() async throws {
        let service = try makeService()
        let plant   = Plant(name: "Lavender", plantType: .flower)

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
#endif
