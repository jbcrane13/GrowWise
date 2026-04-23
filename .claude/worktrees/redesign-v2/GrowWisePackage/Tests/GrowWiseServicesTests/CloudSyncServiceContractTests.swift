import Testing
import Foundation
import CloudKit
@testable import GrowWiseServices

@Suite("CloudSyncService Contract Tests")
struct CloudSyncServiceContractTests {
    @Test("PublicGarden decodes from fixture-backed CKRecord")
    func publicGardenDecodesFromFixtureRecord() throws {
        let fixture = try loadPublicGardenFixture(named: "cloudsync-public-garden-record")
        let record = try makePublicGardenRecord(from: fixture)

        let garden = PublicGarden(from: record)

        #expect(garden != nil)
        #expect(garden?.name == fixture.name)
        #expect(garden?.authorName == fixture.authorName)
        #expect(garden?.gardenType == fixture.gardenType)
        #expect(garden?.description == fixture.description)
        #expect(garden?.likeCount == fixture.likeCount)
        #expect(garden?.viewCount == fixture.viewCount)
    }

    @Test("PublicGarden fails contract decode when required fields are missing")
    func publicGardenDecodeFailsWithoutRequiredFields() {
        let record = CKRecord(recordType: "PublicGarden")
        record["description"] = "Missing required fields"

        let garden = PublicGarden(from: record)

        #expect(garden == nil)
    }

    @Test("CloudKitError descriptions remain user-readable")
    func cloudKitErrorDescriptionsAreReadable() {
        #expect(CloudKitError.accountNotAvailable.errorDescription?.contains("iCloud") == true)
        #expect(CloudKitError.publishFailed("timeout").errorDescription?.contains("timeout") == true)
        #expect(CloudKitError.fetchFailed("auth").errorDescription?.contains("auth") == true)
        #expect(CloudKitError.invalidRecord.errorDescription?.contains("Invalid record") == true)
    }

    private func makePublicGardenRecord(from fixture: PublicGardenFixture) throws -> CKRecord {
        let record = CKRecord(recordType: "PublicGarden")
        let formatter = ISO8601DateFormatter()

        guard let publishedDate = formatter.date(from: fixture.publishedDateISO8601) else {
            throw FixtureError.invalidDate(fixture.publishedDateISO8601)
        }

        record["name"] = fixture.name
        record["authorName"] = fixture.authorName
        record["gardenType"] = fixture.gardenType
        record["description"] = fixture.description
        record["publishedDate"] = publishedDate
        record["likeCount"] = fixture.likeCount
        record["viewCount"] = fixture.viewCount
        return record
    }

    private func loadPublicGardenFixture(named name: String) throws -> PublicGardenFixture {
        let fixtureURL = repositoryRoot()
            .appendingPathComponent("tests")
            .appendingPathComponent("TestFixtures")
            .appendingPathComponent("\(name).json")

        let data = try Data(contentsOf: fixtureURL)
        return try JSONDecoder().decode(PublicGardenFixture.self, from: data)
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct PublicGardenFixture: Decodable, Sendable {
    let name: String
    let authorName: String
    let gardenType: String
    let description: String
    let publishedDateISO8601: String
    let likeCount: Int
    let viewCount: Int

    enum CodingKeys: String, CodingKey {
        case name
        case authorName
        case gardenType
        case description
        case publishedDateISO8601 = "publishedDate"
        case likeCount
        case viewCount
    }
}

private enum FixtureError: Error {
    case invalidDate(String)
}
