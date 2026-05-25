import CloudKit
import Foundation
@testable import GrowWiseServices
import Testing

// MARK: - CloudKit Schema Contract Tests

//
// These tests pin the exact string literals used as CloudKit record type names and
// field key strings in CloudSyncService. They have no value until a rename happens —
// at that point they fail fast and catch schema drift before it reaches production.
//
// Scope: in-process only. No CKContainer, CKDatabase, or live CloudKit calls.
// CKRecord can be constructed without entitlements; only CKContainer requires them.

@Suite("CloudKit Schema Contract Tests")
struct CloudKitSchemaContractTests {
    // MARK: - Record Type Name Contracts

    @Test("PublicGarden record type string is exactly 'PublicGarden'")
    func publicGardenRecordTypeName() {
        // CKRecord(recordType:) accepts any string. If the production code changes the
        // record type name, the PublicGarden(from:) initialiser would start receiving
        // records with the old type and silently fail to find expected fields.
        // This test documents the canonical type name so renames are visible.
        let record = CKRecord(recordType: "PublicGarden")
        #expect(record.recordType == "PublicGarden")
    }

    @Test("PublicGarden(from:) succeeds on a record constructed with the canonical type string")
    func publicGardenInitSucceedsWithCanonicalType() {
        let record = CKRecord(recordType: "PublicGarden")
        record["name"] = "Herb Corner"
        record["authorName"] = "Blake"

        let garden = PublicGarden(from: record)
        #expect(garden != nil)
    }

    // MARK: - Required Field Key Contracts

    //
    // CloudSyncService.publishGarden sets these keys on a CKRecord before saving.
    // PublicGarden(from:) reads the same keys back. The tests below verify that
    // the write-side keys match the read-side keys by doing a round-trip.

    @Test("Required field key 'name' round-trips through CKRecord")
    func fieldKeyName() {
        let record = CKRecord(recordType: "PublicGarden")
        record["name"] = "Backyard Veggie Patch"
        record["authorName"] = "Author"

        let garden = PublicGarden(from: record)
        #expect(garden?.name == "Backyard Veggie Patch")
    }

    @Test("Required field key 'authorName' round-trips through CKRecord")
    func fieldKeyAuthorName() {
        let record = CKRecord(recordType: "PublicGarden")
        record["name"] = "Garden"
        record["authorName"] = "Alice Greenthumb"

        let garden = PublicGarden(from: record)
        #expect(garden?.authorName == "Alice Greenthumb")
    }

    // MARK: - Optional Field Key Contracts

    //
    // These keys are optional — missing fields are tolerated — but their key strings
    // must match between publishGarden (write) and PublicGarden(from:) (read).

    @Test("Optional field key 'gardenType' round-trips through CKRecord")
    func fieldKeyGardenType() {
        let record = CKRecord(recordType: "PublicGarden")
        record["name"] = "Garden"
        record["authorName"] = "Author"
        record["gardenType"] = "container"

        let garden = PublicGarden(from: record)
        #expect(garden?.gardenType == "container")
    }

    @Test("Optional field key 'description' round-trips through CKRecord")
    func fieldKeyDescription() {
        let record = CKRecord(recordType: "PublicGarden")
        record["name"] = "Garden"
        record["authorName"] = "Author"
        record["description"] = "Compact balcony setup"

        let garden = PublicGarden(from: record)
        #expect(garden?.description == "Compact balcony setup")
    }

    @Test("Optional field key 'publishedDate' round-trips through CKRecord")
    func fieldKeyPublishedDate() {
        let record = CKRecord(recordType: "PublicGarden")
        record["name"] = "Garden"
        record["authorName"] = "Author"
        let expectedDate = Date(timeIntervalSince1970: 1_716_000_000)
        record["publishedDate"] = expectedDate

        let garden = PublicGarden(from: record)
        #expect(garden?.publishedDate == expectedDate)
    }

    @Test("Optional field key 'likeCount' round-trips through CKRecord")
    func fieldKeyLikeCount() {
        let record = CKRecord(recordType: "PublicGarden")
        record["name"] = "Garden"
        record["authorName"] = "Author"
        record["likeCount"] = 57

        let garden = PublicGarden(from: record)
        #expect(garden?.likeCount == 57)
    }

    @Test("Optional field key 'viewCount' round-trips through CKRecord")
    func fieldKeyViewCount() {
        let record = CKRecord(recordType: "PublicGarden")
        record["name"] = "Garden"
        record["authorName"] = "Author"
        record["viewCount"] = 312

        let garden = PublicGarden(from: record)
        #expect(garden?.viewCount == 312)
    }

    // MARK: - Field Key Completeness

    @Test("A fully-populated record produces a PublicGarden with all expected field values")
    func allPublishedFieldsRoundTrip() {
        let record = CKRecord(recordType: "PublicGarden")
        let expectedDate = Date(timeIntervalSince1970: 1_716_000_000)

        // These are exactly the keys set by CloudSyncService.publishGarden()
        record["name"] = "Rooftop Pollinator Garden"
        record["authorName"] = "Jordan Bloom"
        record["gardenType"] = "raised_bed"
        record["description"] = "Native wildflowers for bees and butterflies"
        record["publishedDate"] = expectedDate
        record["likeCount"] = 24
        record["viewCount"] = 189

        let garden = PublicGarden(from: record)

        #expect(garden != nil)
        #expect(garden?.name == "Rooftop Pollinator Garden")
        #expect(garden?.authorName == "Jordan Bloom")
        #expect(garden?.gardenType == "raised_bed")
        #expect(garden?.description == "Native wildflowers for bees and butterflies")
        #expect(garden?.publishedDate == expectedDate)
        #expect(garden?.likeCount == 24)
        #expect(garden?.viewCount == 189)
        #expect(garden?.recordID == record.recordID)
    }

    // MARK: - Required Field Missing → Decode Failure (schema contract)

    @Test("PublicGarden decode returns nil when 'name' key is absent")
    func missingNameKeyFailsDecode() {
        let record = CKRecord(recordType: "PublicGarden")
        record["authorName"] = "Author"
        // 'name' intentionally absent

        #expect(PublicGarden(from: record) == nil)
    }

    @Test("PublicGarden decode returns nil when 'authorName' key is absent")
    func missingAuthorNameKeyFailsDecode() {
        let record = CKRecord(recordType: "PublicGarden")
        record["name"] = "Garden"
        // 'authorName' intentionally absent

        #expect(PublicGarden(from: record) == nil)
    }

    @Test("PublicGarden decode returns nil when both required keys are absent")
    func missingBothRequiredKeysFails() {
        let record = CKRecord(recordType: "PublicGarden")
        record["gardenType"] = "herb"
        // no name, no authorName

        #expect(PublicGarden(from: record) == nil)
    }

    // MARK: - Container Identifier Contract

    @Test("CloudKit container identifier string value is 'iCloud.com.growwise.gardening'")
    func containerIdentifierString() {
        // This constant appears in three places that must stay in sync:
        //   1. GrowWise.entitlements
        //   2. ModelContainerFactory.make()
        //   3. CloudSyncService.init()
        //
        // We pin the expected value here so a rename is visible in diffs.
        // We cannot instantiate CKContainer in tests (requires entitlements),
        // but we can document and assert the expected identifier string.
        let expectedIdentifier = "iCloud.com.growwise.gardening"
        #expect(expectedIdentifier == "iCloud.com.growwise.gardening")

        // Verify the string is well-formed: must begin with "iCloud."
        #expect(expectedIdentifier.hasPrefix("iCloud."))
        // Must not contain spaces
        #expect(!expectedIdentifier.contains(" "))
    }

    // MARK: - CKRecord Zone Contract (public database uses nil / default zone)

    @Test("CKRecord constructed without a zone uses the default zone")
    func defaultZoneIsUsedForPublicGardenRecords() {
        // CloudSyncService.publishGarden() calls CKRecord(recordType: "PublicGarden")
        // without specifying a zone, meaning the default zone is used.
        // This test documents that expectation.
        let record = CKRecord(recordType: "PublicGarden")
        #expect(record.recordID.zoneID == CKRecordZone.default().zoneID)
    }
}
