import Foundation
import Security

/// Core keychain storage service handling raw keychain operations
public final class KeychainStorageService {
    
    // MARK: - Properties
    
    private let service: String
    private let accessGroup: String?
    private let keyValidationPattern = "^[a-zA-Z0-9_.-]+$"
    private let maxKeyLength = 256
    
    // MARK: - Error Types
    
    public enum StorageError: LocalizedError {
        case duplicateEntry
        case unknown(OSStatus)
        case itemNotFound
        case invalidData
        case unexpectedPasswordData
        case unhandledError(status: OSStatus)
        case invalidKey(String)
        
        public var errorDescription: String? {
            switch self {
            case .duplicateEntry:
                return "Item already exists in keychain"
            case .unknown(let status):
                return "Unknown keychain error: \(status)"
            case .itemNotFound:
                return "Item not found in keychain"
            case .invalidData:
                return "Invalid data format"
            case .unexpectedPasswordData:
                return "Unexpected password data format"
            case .unhandledError(let status):
                return "Unhandled keychain error: \(status)"
            case .invalidKey(let reason):
                return "Invalid key: \(reason)"
            }
        }
    }
    
    // MARK: - Initialization
    
    public init(service: String, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }
    
    // MARK: - Public Methods
    
    /// Store raw data in keychain
    public func store(_ data: Data, for key: String) throws {
        try validateKey(key)
        
        let query = createQuery(for: key)
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            // Update existing item
            let updateQuery: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(query as CFDictionary, updateQuery as CFDictionary)
            
            guard updateStatus == errSecSuccess else {
                throw StorageError.unknown(updateStatus)
            }
        } else if status == errSecItemNotFound {
            // Add new item
            var addQuery = query
            addQuery[kSecValueData as String] = data
            
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            
            guard addStatus == errSecSuccess else {
                if addStatus == errSecDuplicateItem {
                    throw StorageError.duplicateEntry
                }
                throw StorageError.unknown(addStatus)
            }
        } else {
            throw StorageError.unknown(status)
        }
    }
    
    /// Retrieve raw data from keychain
    public func retrieve(for key: String) throws -> Data {
        try validateKey(key)
        
        var query = createQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw StorageError.itemNotFound
            }
            throw StorageError.unknown(status)
        }
        
        guard let data = item as? Data else {
            throw StorageError.unexpectedPasswordData
        }
        
        return data
    }
    
    /// Delete item from keychain
    public func delete(for key: String) throws {
        try validateKey(key)
        
        let query = createQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StorageError.unknown(status)
        }
    }
    
    /// Check if key exists in keychain
    public func exists(for key: String) -> Bool {
        guard (try? validateKey(key)) != nil else { return false }
        
        let query = createQuery(for: key)
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Delete all items for this service
    public func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StorageError.unknown(status)
        }
    }
    
    // MARK: - Private Methods
    
    /// Validate key to prevent injection attacks
    private func validateKey(_ key: String) throws {
        guard key.count > 0 && key.count <= maxKeyLength else {
            throw StorageError.invalidKey("Key length must be between 1 and \(maxKeyLength) characters")
        }
        
        let regex = try NSRegularExpression(pattern: keyValidationPattern, options: [])
        let range = NSRange(location: 0, length: key.count)
        
        guard regex.firstMatch(in: key, options: [], range: range) != nil else {
            throw StorageError.invalidKey("Key contains invalid characters. Only alphanumeric, underscore, hyphen, and period allowed.")
        }
        
        let dangerousPatterns = ["--", "/*", "*/", "<script", "javascript:", "data:", "vbscript:", "onload=", "onerror="]
        for pattern in dangerousPatterns {
            if key.lowercased().contains(pattern) {
                throw StorageError.invalidKey("Key contains potentially dangerous pattern")
            }
        }
    }
    
    private func createQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
}