import Foundation
import Security

/// Thin wrapper around the system Keychain APIs.
/// Replaces the former KeychainManager + KeychainStorageService with a minimal,
/// non-singleton struct exposing only the operations the app actually uses.
public struct KeychainService: Sendable {

    // MARK: - Shared instance

    public static let shared = KeychainService()

    // MARK: - Properties

    private let service: String
    private let accessGroup: String?

    // MARK: - Error

    public enum KeychainError: LocalizedError {
        case unexpectedData
        case osStatus(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .unexpectedData:
                return "Unexpected keychain data format"
            case .osStatus(let status):
                return "Keychain error: \(status)"
            }
        }
    }

    // MARK: - Init

    public init(service: String = "com.growwiser.app", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    // MARK: - Core

    /// Save or update raw data in the keychain.
    public func save(key: String, data: Data) throws {
        let query = baseQuery(key: key)

        // Try updating first
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let update: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.osStatus(updateStatus)
            }
        } else {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.osStatus(addStatus)
            }
        }
    }

    /// Load raw data from the keychain. Returns nil when the item does not exist.
    public func load(key: String) throws -> Data? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.osStatus(status) }
        guard let data = item as? Data else { throw KeychainError.unexpectedData }
        return data
    }

    /// Delete an item from the keychain. No-op if the item does not exist.
    public func delete(key: String) throws {
        let query = baseQuery(key: key)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.osStatus(status)
        }
    }

    // MARK: - Convenience: Bool

    public func storeBool(_ value: Bool, for key: String) throws {
        try save(key: key, data: Data([value ? 1 : 0]))
    }

    public func retrieveBool(for key: String) throws -> Bool {
        guard let data = try load(key: key), let byte = data.first else { return false }
        return byte != 0
    }

    // MARK: - Convenience: String

    public func storeString(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else { throw KeychainError.unexpectedData }
        try save(key: key, data: data)
    }

    public func retrieveString(for key: String) throws -> String? {
        guard let data = try load(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Convenience: Raw Data (matches old KeychainManager API names)

    public func store(_ data: Data, for key: String) throws {
        try save(key: key, data: data)
    }

    public func retrieve(for key: String) throws -> Data? {
        try load(key: key)
    }

    public func delete(for key: String) throws {
        try delete(key: key)
    }

    // MARK: - Private

    private func baseQuery(key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}
