import XCTest
import CryptoKit
@testable import GrowWiseServices

final class LegacyEncryptionMigrationServiceTests: XCTestCase {
    
    var storage: KeychainStorageService!
    var migrationService: LegacyEncryptionMigrationService!
    private let testService = "com.growwise.migration.test"
    private let legacyKeyIdentifier = "_encryption_key_v2"
    
    override func setUp() {
        super.setUp()
        storage = KeychainStorageService(service: testService)
        migrationService = LegacyEncryptionMigrationService(keychainStorage: storage)
        
        // Clean up any existing test data
        try? storage.deleteAll()
    }
    
    override func tearDown() {
        // Clean up after tests
        try? storage.deleteAll()
        migrationService = nil
        storage = nil
        super.tearDown()
    }
    
    // MARK: - Legacy Key Detection Tests
    
    func testHasLegacyKeyWhenKeyExists() throws {
        // Create a legacy key
        let legacyKey = SymmetricKey(size: .bits256)
        try storage.store(legacyKey.withUnsafeBytes { Data($0) }, for: legacyKeyIdentifier)
        
        XCTAssertTrue(migrationService.hasLegacyKey)
    }
    
    func testHasLegacyKeyWhenNoKeyExists() {
        XCTAssertFalse(migrationService.hasLegacyKey)
    }
    
    func testGetLegacyKey() throws {
        // Store a known legacy key
        let originalKey = SymmetricKey(size: .bits256)
        try storage.store(originalKey.withUnsafeBytes { Data($0) }, for: legacyKeyIdentifier)
        
        // Retrieve the key
        let retrievedKey = try migrationService.getLegacyKey()
        
        // Keys should be identical
        XCTAssertEqual(
            originalKey.withUnsafeBytes { Data($0) },
            retrievedKey.withUnsafeBytes { Data($0) }
        )
    }
    
    func testGetLegacyKeyWhenNotExists() {
        XCTAssertThrowsError(try migrationService.getLegacyKey()) { error in
            XCTAssertTrue(error is LegacyEncryptionMigrationService.MigrationError)
            if let migrationError = error as? LegacyEncryptionMigrationService.MigrationError {
                XCTAssertEqual(migrationError, .legacyKeyNotFound)
            }
        }
    }
    
    // MARK: - Legacy Decryption Tests
    
    func testDecryptLegacyData() throws {
        // Create legacy key and encrypt data
        let legacyKey = SymmetricKey(size: .bits256)
        try storage.store(legacyKey.withUnsafeBytes { Data($0) }, for: legacyKeyIdentifier)
        
        let originalData = "Legacy encrypted test data".data(using: .utf8)!
        let encryptedData = try AES.GCM.seal(originalData, using: legacyKey).combined!
        
        // Decrypt using migration service
        let decryptedData = try migrationService.decryptLegacyData(encryptedData)
        
        XCTAssertEqual(decryptedData, originalData)
        XCTAssertEqual(String(data: decryptedData, encoding: .utf8), "Legacy encrypted test data")
    }
    
    func testDecryptLegacyDataWithAAD() throws {
        // Create legacy key and encrypt data with authenticated data
        let legacyKey = SymmetricKey(size: .bits256)
        try storage.store(legacyKey.withUnsafeBytes { Data($0) }, for: legacyKeyIdentifier)
        
        let originalData = "AAD protected legacy data".data(using: .utf8)!
        let authenticatedData = "com.growwise.aad".data(using: .utf8)!
        let encryptedData = try AES.GCM.seal(originalData, using: legacyKey, authenticating: authenticatedData).combined!
        
        // Decrypt using migration service
        let decryptedData = try migrationService.decryptLegacyData(encryptedData, authenticatedData: authenticatedData)
        
        XCTAssertEqual(decryptedData, originalData)
        XCTAssertEqual(String(data: decryptedData, encoding: .utf8), "AAD protected legacy data")
    }
    
    func testDecryptLegacyDataWithWrongAAD() throws {
        // Create legacy key and encrypt data with authenticated data
        let legacyKey = SymmetricKey(size: .bits256)
        try storage.store(legacyKey.withUnsafeBytes { Data($0) }, for: legacyKeyIdentifier)
        
        let originalData = "AAD protected legacy data".data(using: .utf8)!
        let correctAAD = "com.growwise.aad".data(using: .utf8)!
        let wrongAAD = "wrong.aad.data".data(using: .utf8)!
        let encryptedData = try AES.GCM.seal(originalData, using: legacyKey, authenticating: correctAAD).combined!
        
        // Decryption with wrong AAD should fail
        XCTAssertThrowsError(try migrationService.decryptLegacyData(encryptedData, authenticatedData: wrongAAD)) { error in
            XCTAssertTrue(error is LegacyEncryptionMigrationService.MigrationError)
        }
    }
    
    // MARK: - Migration Tests
    
    func testMigrateEncryptedData() throws {
        // Create legacy key and encrypt data
        let legacyKey = SymmetricKey(size: .bits256)
        try storage.store(legacyKey.withUnsafeBytes { Data($0) }, for: legacyKeyIdentifier)
        
        let originalData = "Data to migrate".data(using: .utf8)!
        let legacyEncrypted = try AES.GCM.seal(originalData, using: legacyKey).combined!
        
        // Create new key for migration target
        let newKey = SymmetricKey(size: .bits256)
        
        // Migrate the data
        let migratedData = try migrationService.migrateEncryptedData(legacyEncrypted, using: newKey)
        
        // Migrated data should be different from original
        XCTAssertNotEqual(migratedData, legacyEncrypted)
        
        // Migrated data should decrypt to same plaintext with new key
        let sealedBox = try AES.GCM.SealedBox(combined: migratedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: newKey)
        
        XCTAssertEqual(decryptedData, originalData)
    }
    
    func testMigrateEncryptedDataWithAAD() throws {
        // Create legacy key and encrypt data with AAD
        let legacyKey = SymmetricKey(size: .bits256)
        try storage.store(legacyKey.withUnsafeBytes { Data($0) }, for: legacyKeyIdentifier)
        
        let originalData = "AAD data to migrate".data(using: .utf8)!
        let authenticatedData = "migration.context".data(using: .utf8)!
        let legacyEncrypted = try AES.GCM.seal(originalData, using: legacyKey, authenticating: authenticatedData).combined!
        
        // Create new key for migration target
        let newKey = SymmetricKey(size: .bits256)
        
        // Migrate the data with AAD
        let migratedData = try migrationService.migrateEncryptedData(
            legacyEncrypted,
            using: newKey,
            authenticatedData: authenticatedData
        )
        
        // Migrated data should be different from original
        XCTAssertNotEqual(migratedData, legacyEncrypted)
        
        // Migrated data should decrypt to same plaintext with new key and AAD
        let sealedBox = try AES.GCM.SealedBox(combined: migratedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: newKey, authenticating: authenticatedData)
        
        XCTAssertEqual(decryptedData, originalData)
    }
    
    func testBatchMigrateEncryptedData() throws {
        // Create legacy key
        let legacyKey = SymmetricKey(size: .bits256)
        try storage.store(legacyKey.withUnsafeBytes { Data($0) }, for: legacyKeyIdentifier)
        
        // Create multiple encrypted data items
        let dataItems: [(data: Data, plaintext: String, aad: Data?)] = [
            (
                try AES.GCM.seal("First item".data(using: .utf8)!, using: legacyKey).combined!,
                "First item",
                nil
            ),
            (
                try AES.GCM.seal("Second item".data(using: .utf8)!, using: legacyKey, authenticating: "context1".data(using: .utf8)!).combined!,
                "Second item",
                "context1".data(using: .utf8)!
            ),
            (
                try AES.GCM.seal("Third item".data(using: .utf8)!, using: legacyKey, authenticating: "context2".data(using: .utf8)!).combined!,
                "Third item",
                "context2".data(using: .utf8)!
            )
        ]
        
        let batchData = dataItems.map { (data: $0.data, authenticatedData: $0.aad) }
        let newKey = SymmetricKey(size: .bits256)
        
        // Perform batch migration
        let migratedItems = try migrationService.batchMigrateEncryptedData(batchData, using: newKey)
        
        // Should have same number of items
        XCTAssertEqual(migratedItems.count, dataItems.count)
        
        // Verify each migrated item
        for (index, migratedData) in migratedItems.enumerated() {
            let originalItem = dataItems[index]
            
            // Migrated data should be different from original
            XCTAssertNotEqual(migratedData, originalItem.data)
            
            // Decrypt and verify content
            let sealedBox = try AES.GCM.SealedBox(combined: migratedData)
            let decryptedData: Data
            
            if let aad = originalItem.aad {
                decryptedData = try AES.GCM.open(sealedBox, using: newKey, authenticating: aad)
            } else {
                decryptedData = try AES.GCM.open(sealedBox, using: newKey)
            }
            
            let decryptedString = String(data: decryptedData, encoding: .utf8)
            XCTAssertEqual(decryptedString, originalItem.plaintext)
        }
    }
    
    // MARK: - Utility Tests
    
    func testIsLegacyEncryptedData() throws {
        // Create legacy key and encrypt data
        let legacyKey = SymmetricKey(size: .bits256)
        let originalData = "Test data for format detection".data(using: .utf8)!
        let encryptedData = try AES.GCM.seal(originalData, using: legacyKey).combined!
        
        // Should recognize as legacy encrypted data
        XCTAssertTrue(migrationService.isLegacyEncryptedData(encryptedData))
        
        // Random data should not be recognized
        let randomData = Data.random(count: 64)
        XCTAssertFalse(migrationService.isLegacyEncryptedData(randomData))
        
        // Plain text should not be recognized
        let plainData = "Plain text data".data(using: .utf8)!
        XCTAssertFalse(migrationService.isLegacyEncryptedData(plainData))
    }
    
    func testValidateMigrationCompatibility() throws {
        // Create legacy key and encrypt data
        let legacyKey = SymmetricKey(size: .bits256)
        try storage.store(legacyKey.withUnsafeBytes { Data($0) }, for: legacyKeyIdentifier)
        
        let originalData = "Compatibility test data".data(using: .utf8)!
        let encryptedData = try AES.GCM.seal(originalData, using: legacyKey).combined!
        
        let newKey = SymmetricKey(size: .bits256)
        
        // Should validate successfully
        let isCompatible = try migrationService.validateMigrationCompatibility(testData: encryptedData, newKey: newKey)
        XCTAssertTrue(isCompatible)
        
        // Invalid data should fail validation
        let invalidData = "Invalid encrypted data".data(using: .utf8)!
        let isInvalidCompatible = try migrationService.validateMigrationCompatibility(testData: invalidData, newKey: newKey)
        XCTAssertFalse(isInvalidCompatible)
    }
    
    // MARK: - Migration Info Tests
    
    func testGetMigrationInfoWithLegacyKey() throws {
        // Create legacy key
        let legacyKey = SymmetricKey(size: .bits256)
        try storage.store(legacyKey.withUnsafeBytes { Data($0) }, for: legacyKeyIdentifier)
        
        let migrationInfo = migrationService.getMigrationInfo()
        
        XCTAssertTrue(migrationInfo.hasLegacyKey)
        XCTAssertEqual(migrationInfo.secureEnclaveAvailable, SecureEnclaveKeyManager.isSecureEnclaveAvailable)
        
        if SecureEnclaveKeyManager.isSecureEnclaveAvailable {
            XCTAssertEqual(migrationInfo.recommendedAction, .migrateToSecureEnclave)
        } else {
            XCTAssertEqual(migrationInfo.recommendedAction, .keepLegacyWithWarning)
        }
        
        XCTAssertFalse(migrationInfo.recommendedAction.description.isEmpty)
    }
    
    func testGetMigrationInfoWithoutLegacyKey() {
        let migrationInfo = migrationService.getMigrationInfo()
        
        XCTAssertFalse(migrationInfo.hasLegacyKey)
        XCTAssertEqual(migrationInfo.recommendedAction, .noActionNeeded)
        XCTAssertFalse(migrationInfo.recommendedAction.description.isEmpty)
    }
    
    // MARK: - Legacy Key Removal Tests
    
    func testRemoveLegacyKey() throws {
        // Create legacy key
        let legacyKey = SymmetricKey(size: .bits256)
        try storage.store(legacyKey.withUnsafeBytes { Data($0) }, for: legacyKeyIdentifier)
        
        XCTAssertTrue(migrationService.hasLegacyKey)
        
        // Remove legacy key
        try migrationService.removeLegacyKey()
        
        XCTAssertFalse(migrationService.hasLegacyKey)
    }
    
    func testRemoveLegacyKeyWhenNoneExists() {
        XCTAssertFalse(migrationService.hasLegacyKey)
        
        // Should not throw error
        XCTAssertNoThrow(try migrationService.removeLegacyKey())
        
        XCTAssertFalse(migrationService.hasLegacyKey)
    }
    
    // MARK: - Error Handling Tests
    
    func testMigrationErrorDescriptions() {
        let errors: [LegacyEncryptionMigrationService.MigrationError] = [
            .legacyKeyNotFound,
            .migrationFailed,
            .decryptionFailed,
            .reencryptionFailed,
            .keyRetrievalFailed
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}

// MARK: - Helper Extensions

extension Data {
    static func random(count: Int) -> Data {
        var data = Data(count: count)
        data.withUnsafeMutableBytes { bytes in
            _ = SecRandomCopyBytes(kSecRandomDefault, count, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        return data
    }
}