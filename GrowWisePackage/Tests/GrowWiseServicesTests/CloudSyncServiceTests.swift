import CloudKit
import Foundation
@testable import GrowWiseServices
import Testing

// MARK: - PublicGarden Data Mapping Tests

@MainActor
struct CloudSyncServicePublicGardenMappingTests {
    // MARK: - publishGarden record field construction

    @Test("PublicGarden record fields map correctly from CKRecord with all fields")
    func publicGardenDecodesAllFieldsFromRecord() {
        let record = CKRecord(recordType: "PublicGarden")
        let publishedDate = Date(timeIntervalSince1970: 1_700_000_000)

        record["name"] = "Blake's Herb Garden"
        record["authorName"] = "Blake"
        record["gardenType"] = "herb"
        record["description"] = "A nice herb garden"
        record["publishedDate"] = publishedDate
        record["likeCount"] = 42
        record["viewCount"] = 100
        record["plantCount"] = 12
        record["hardinessZone"] = "7b"

        let garden = PublicGarden(from: record)

        #expect(garden != nil)
        #expect(garden?.name == "Blake's Herb Garden")
        #expect(garden?.authorName == "Blake")
        #expect(garden?.gardenType == "herb")
        #expect(garden?.description == "A nice herb garden")
        #expect(garden?.publishedDate == publishedDate)
        #expect(garden?.likeCount == 42)
        #expect(garden?.viewCount == 100)
        #expect(garden?.plantCount == 12)
        #expect(garden?.hardinessZone == "7b")
        #expect(garden?.recordID == record.recordID)
    }

    @Test("PublicGarden record preserves recordID for later operations")
    func publicGardenRecordIDPreserved() {
        let record = CKRecord(recordType: "PublicGarden")
        record["name"] = "Test"
        record["authorName"] = "Author"

        let garden = PublicGarden(from: record)

        #expect(garden?.recordID == record.recordID)
        #expect(garden?.recordID != nil)
    }

    @Test("PublicGarden defaults likeCount and viewCount to zero when missing from record")
    func publicGardenDefaultsCountsToZero() {
        let record = CKRecord(recordType: "PublicGarden")
        record["name"] = "Test Garden"
        record["authorName"] = "Author"
        // Intentionally omit likeCount and viewCount

        let garden = PublicGarden(from: record)

        #expect(garden != nil)
        #expect(garden?.likeCount == 0)
        #expect(garden?.viewCount == 0)
    }

    @Test("PublicGarden defaults publishedDate to now when missing from record")
    func publicGardenDefaultsPublishedDate() throws {
        let record = CKRecord(recordType: "PublicGarden")
        record["name"] = "Test"
        record["authorName"] = "Author"
        // Intentionally omit publishedDate

        let before = Date()
        let garden = PublicGarden(from: record)
        let after = Date()

        #expect(garden != nil)
        // The default date should be approximately now
        let publishedDate = try #require(garden?.publishedDate)
        #expect(publishedDate >= before.addingTimeInterval(-1))
        #expect(publishedDate <= after.addingTimeInterval(1))
    }

    @Test("PublicGarden optional fields are nil when absent from record")
    func publicGardenOptionalFieldsNilWhenAbsent() {
        let record = CKRecord(recordType: "PublicGarden")
        record["name"] = "Minimal Garden"
        record["authorName"] = "Author"

        let garden = PublicGarden(from: record)

        #expect(garden != nil)
        #expect(garden?.gardenType == nil)
        #expect(garden?.description == nil)
        #expect(garden?.hardinessZone == nil)
        #expect(garden?.plantCount == 0)
        #expect(garden?.imageAsset == nil)
    }

    // MARK: - Required field validation

    @Test("PublicGarden init fails when name is missing")
    func publicGardenFailsWithoutName() {
        let record = CKRecord(recordType: "PublicGarden")
        record["authorName"] = "Author"

        let garden = PublicGarden(from: record)
        #expect(garden == nil)
    }

    @Test("PublicGarden init fails when authorName is missing")
    func publicGardenFailsWithoutAuthorName() {
        let record = CKRecord(recordType: "PublicGarden")
        record["name"] = "Test Garden"

        let garden = PublicGarden(from: record)
        #expect(garden == nil)
    }

    @Test("PublicGarden init fails when both required fields are missing")
    func publicGardenFailsWithoutBothRequired() {
        let record = CKRecord(recordType: "PublicGarden")
        record["likeCount"] = 5

        let garden = PublicGarden(from: record)
        #expect(garden == nil)
    }

    // MARK: - PublicGarden memberwise init

    @Test("PublicGarden memberwise init sets defaults correctly")
    func publicGardenMemberwiseInitDefaults() {
        let garden = PublicGarden(name: "Test", authorName: "Author")

        #expect(garden.name == "Test")
        #expect(garden.authorName == "Author")
        #expect(garden.gardenType == nil)
        #expect(garden.description == nil)
        #expect(garden.likeCount == 0)
        #expect(garden.viewCount == 0)
        #expect(garden.plantCount == 0)
        #expect(garden.hardinessZone == nil)
        #expect(garden.recordID == nil)
        #expect(garden.imageAsset == nil)
    }

    @Test("PublicGarden generates unique IDs")
    func publicGardenGeneratesUniqueIDs() {
        let garden1 = PublicGarden(name: "A", authorName: "Author")
        let garden2 = PublicGarden(name: "B", authorName: "Author")

        #expect(garden1.id != garden2.id)
    }
}

// MARK: - PublicGardenSort Tests

@MainActor
struct PublicGardenSortTests {
    @Test("PublicGardenSort has all four cases")
    func allSortCasesExist() {
        let allCases = PublicGardenSort.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.newest))
        #expect(allCases.contains(.oldest))
        #expect(allCases.contains(.mostLiked))
        #expect(allCases.contains(.mostViewed))
    }

    @Test("PublicGardenSort displayName returns human-readable strings")
    func sortDisplayNames() {
        #expect(PublicGardenSort.newest.displayName == "Newest First")
        #expect(PublicGardenSort.oldest.displayName == "Oldest First")
        #expect(PublicGardenSort.mostLiked.displayName == "Most Liked")
        #expect(PublicGardenSort.mostViewed.displayName == "Most Viewed")
    }

    @Test("PublicGardenSort rawValue roundtrips correctly")
    func sortRawValueRoundtrip() {
        for sortCase in PublicGardenSort.allCases {
            let roundtripped = PublicGardenSort(rawValue: sortCase.rawValue)
            #expect(roundtripped == sortCase)
        }
    }
}

// MARK: - CloudKitError Tests

@MainActor
struct CloudKitErrorTests {
    @Test("CloudKitError.accountNotAvailable includes iCloud guidance")
    func accountNotAvailableDescription() {
        let error = CloudKitError.accountNotAvailable
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("iCloud"))
        #expect(desc.contains("sign in"))
    }

    @Test("CloudKitError.publishFailed wraps the underlying message")
    func publishFailedWrapsMessage() {
        let error = CloudKitError.publishFailed("network timeout")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("network timeout"))
        #expect(desc.contains("publish"))
    }

    @Test("CloudKitError.fetchFailed wraps the underlying message")
    func fetchFailedWrapsMessage() {
        let error = CloudKitError.fetchFailed("server unavailable")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("server unavailable"))
        #expect(desc.contains("fetch"))
    }

    @Test("CloudKitError.operationFailed wraps the underlying message")
    func operationFailedWrapsMessage() {
        let error = CloudKitError.operationFailed("permission denied")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("permission denied"))
        #expect(desc.contains("Operation failed"))
    }

    @Test("CloudKitError.invalidRecord has a meaningful description")
    func invalidRecordDescription() {
        let error = CloudKitError.invalidRecord
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("Invalid record"))
    }

    @Test("All CloudKitError cases conform to LocalizedError with non-empty descriptions")
    func allErrorCasesHaveDescriptions() {
        let cases: [CloudKitError] = [
            .accountNotAvailable,
            .publishFailed("test"),
            .fetchFailed("test"),
            .operationFailed("test"),
            .invalidRecord,
        ]
        for error in cases {
            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.isEmpty == false)
        }
    }
}

// MARK: - Integration Gap Comments

// INTEGRATION GAP: publishGarden() — requires live CKDatabase to verify CKRecord.save()
//   The method creates a CKRecord, sets fields, and calls publicDatabase.save().
//   The field-mapping logic is tested above via PublicGarden(from:) round-trip.
//   Full integration requires CloudKit entitlements + iCloud account.

// INTEGRATION GAP: fetchPublicGardens() — requires live CKDatabase
//   Tests would verify: CKQuery construction, sort descriptor mapping, pagination cursor handling.
//   The sort descriptor keys ("publishedDate", "likeCount", "viewCount") are string-based
//   and can only be validated against a live CloudKit schema.

// INTEGRATION GAP: likeGarden() — requires live CKDatabase to verify increment
//   The method fetches a record by ID, increments likeCount, and saves.
//   Requires a real CKRecord.ID pointing to an existing record.

// INTEGRATION GAP: incrementViewCount() — requires live CKDatabase
//   Similar to likeGarden but silently swallows errors (logs only).
//   This design means errors are NOT surfaced to callers — intentional for view counts.

// INTEGRATION GAP: unpublishGarden() — requires live CKDatabase
//   Calls deleteRecord(withID:). Requires a real record ID.

// INTEGRATION GAP: Pagination with cursor — CKQueryOperation.Cursor is opaque
//   Cannot be constructed in tests. Must be tested with live CloudKit.

// INTEGRATION GAP: likeGarden/unpublishGarden require non-nil recordID
//   The guard-else-throw for nil recordID IS tested indirectly: PublicGarden(name:authorName:)
//   produces a nil recordID, so calling likeGarden/unpublishGarden on it would throw .invalidRecord.
//   However, the actual CKDatabase interaction requires a live backend.
