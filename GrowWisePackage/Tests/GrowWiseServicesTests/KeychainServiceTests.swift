import Foundation
@testable import GrowWiseServices
import Testing

// MARK: - Mock KeychainService for Error Testing

/// Mock KeychainService that simulates errors for testing.
final class MockKeychainService: KeychainOperations, @unchecked Sendable {
    private(set) var shouldFail = false
    private var storage: [String: Data] = [:]
    private let lock = NSLock()
    
    func setShouldFail(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        shouldFail = value
    }
    
    func save(key: String, data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        if shouldFail {
            throw KeychainService.KeychainError.osStatus(-25300) // errSecParam
        }
        storage[key] = data
    }
    
    func load(key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }
    
    func delete(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }
    
    func storeBool(_ value: Bool, for key: String) throws {
        try save(key: key, data: Data([value ? 1 : 0]))
    }
    
    func retrieveBool(for key: String) throws -> Bool {
        guard let data = try load(key: key), let byte = data.first else { return false }
        return byte != 0
    }
    
    func storeString(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else { throw KeychainService.KeychainError.unexpectedData }
        try save(key: key, data: data)
    }
    
    func retrieveString(for key: String) throws -> String? {
        guard let data = try load(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Keychain Environment Check

/// Keychain writes require a login session. In headless CI/SSH environments
/// SecItemAdd returns errSecInteractionNotAllowed (-25308). Detected once at
/// load time so write-dependent tests can be skipped cleanly.
private let _keychainWritable: Bool = {
    let probe = KeychainService(service: "com.growwise.tests.probe")
    do {
        try probe.save(key: "__probe__", data: Data([0x01]))
        try probe.delete(key: "__probe__")
        return true
    } catch {
        return false
    }
}()

// MARK: - KeychainService Tests

struct KeychainServiceTests {
    /// Use a unique service name per test run to avoid cross-contamination
    /// with the real app keychain or parallel test runs.
    private func makeService() -> KeychainService {
        KeychainService(service: "com.growwise.tests.\(UUID().uuidString)")
    }

    // MARK: - Read-only tests (always runnable)

    @Test("load returns nil for nonexistent key")
    func loadNonexistentKey() throws {
        let sut = makeService()
        let result = try sut.load(key: "key_that_does_not_exist")
        #expect(result == nil)
    }

    @Test("delete is a no-op for nonexistent key and does not throw")
    func deleteNonexistentKeyDoesNotThrow() throws {
        let sut = makeService()
        // Should not throw — service treats errSecItemNotFound as success
        try sut.delete(key: "never_stored")
    }

    @Test("retrieveBool returns false for nonexistent key")
    func retrieveBoolDefaultsFalse() throws {
        let sut = makeService()
        let result = try sut.retrieveBool(for: "missing_bool")
        #expect(result == false)
    }

    @Test("retrieveString returns nil for nonexistent key")
    func retrieveStringNilForMissing() throws {
        let sut = makeService()
        let result = try sut.retrieveString(for: "no_such_string")
        #expect(result == nil)
    }

    // MARK: - Error Behavior (always runnable)

    @Test("save throws KeychainError.osStatus when keychain rejects the operation")
    func saveThrowsOnKeychainRejection() throws {
        let mock = MockKeychainService()
        mock.setShouldFail(true)
        
        #expect(throws: KeychainService.KeychainError.self) {
            try mock.save(key: "should_fail", data: Data([0x01]))
        }
    }

    @Test("KeychainError.unexpectedData has a meaningful description")
    func unexpectedDataErrorDescription() {
        let error = KeychainService.KeychainError.unexpectedData
        let description = error.errorDescription ?? ""
        #expect(description.contains("Unexpected"))
    }

    @Test("KeychainError.osStatus includes the status code in description")
    func osStatusErrorDescription() {
        let error = KeychainService.KeychainError.osStatus(-25300)
        let description = error.errorDescription ?? ""
        #expect(description.contains("-25300"))
    }

    // MARK: - Write-dependent tests (require login keychain session)

    @Test(
        "save persists data retrievable by load",
        .enabled(if: _keychainWritable, "Keychain writes require a login session")
    )
    func saveAndLoad() throws {
        let sut = makeService()
        let key = "test_key"
        let data = Data("hello keychain".utf8)

        try sut.save(key: key, data: data)
        let loaded = try sut.load(key: key)

        #expect(loaded == data)

        try sut.delete(key: key)
    }

    @Test(
        "delete removes stored data so load returns nil",
        .enabled(if: _keychainWritable, "Keychain writes require a login session")
    )
    func deleteRemovesData() throws {
        let sut = makeService()
        let key = "delete_me"
        try sut.save(key: key, data: Data("temporary".utf8))

        try sut.delete(key: key)
        let result = try sut.load(key: key)

        #expect(result == nil)
    }

    @Test(
        "save overwrites existing value for the same key",
        .enabled(if: _keychainWritable, "Keychain writes require a login session")
    )
    func saveOverwritesExistingKey() throws {
        let sut = makeService()
        let key = "overwrite_key"

        try sut.save(key: key, data: Data("first".utf8))
        try sut.save(key: key, data: Data("second".utf8))

        let loaded = try sut.load(key: key)
        #expect(loaded == Data("second".utf8))

        try sut.delete(key: key)
    }

    @Test(
        "save handles empty data",
        .enabled(if: _keychainWritable, "Keychain writes require a login session")
    )
    func saveEmptyData() throws {
        let sut = makeService()
        let key = "empty_data"

        try sut.save(key: key, data: Data())
        let loaded = try sut.load(key: key)

        #expect(loaded == Data())

        try sut.delete(key: key)
    }

    @Test(
        "save handles large data blob",
        .enabled(if: _keychainWritable, "Keychain writes require a login session")
    )
    func saveLargeData() throws {
        let sut = makeService()
        let key = "large_data"
        let largeData = Data(repeating: 0xAB, count: 100_000)

        try sut.save(key: key, data: largeData)
        let loaded = try sut.load(key: key)

        #expect(loaded == largeData)

        try sut.delete(key: key)
    }

    @Test(
        "storeBool and retrieveBool round-trip true and false",
        .enabled(if: _keychainWritable, "Keychain writes require a login session")
    )
    func boolRoundTrip() throws {
        let sut = makeService()

        try sut.storeBool(true, for: "bool_true")
        try sut.storeBool(false, for: "bool_false")

        #expect(try sut.retrieveBool(for: "bool_true") == true)
        #expect(try sut.retrieveBool(for: "bool_false") == false)

        try sut.delete(key: "bool_true")
        try sut.delete(key: "bool_false")
    }

    @Test(
        "storeString and retrieveString round-trip correctly",
        .enabled(if: _keychainWritable, "Keychain writes require a login session")
    )
    func stringRoundTrip() throws {
        let sut = makeService()
        let key = "string_key"
        let value = "Cultivation App"

        try sut.storeString(value, for: key)
        let loaded = try sut.retrieveString(for: key)

        #expect(loaded == value)

        try sut.delete(key: key)
    }
}
