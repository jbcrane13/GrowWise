import Foundation

/// Service responsible for data transformation (Codable operations, serialization)
public final class DataTransformationService {
    
    // MARK: - Error Types
    
    public enum TransformationError: LocalizedError {
        case encodingFailed(Error)
        case decodingFailed(Error)
        case invalidData
        case serializationFailed
        
        public var errorDescription: String? {
            switch self {
            case .encodingFailed(let error):
                return "Failed to encode data: \(error.localizedDescription)"
            case .decodingFailed(let error):
                return "Failed to decode data: \(error.localizedDescription)"
            case .invalidData:
                return "Invalid data format"
            case .serializationFailed:
                return "JSON serialization failed"
            }
        }
    }
    
    // MARK: - Properties
    
    private let storage: KeychainStorageService
    private let encryptionService: EncryptionService?
    
    // MARK: - Initialization
    
    public init(storage: KeychainStorageService, encryptionService: EncryptionService? = nil) {
        self.storage = storage
        self.encryptionService = encryptionService
    }
    
    // MARK: - String Operations
    
    /// Store string data
    public func storeString(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw TransformationError.invalidData
        }
        try storage.store(data, for: key)
    }
    
    /// Retrieve string data
    public func retrieveString(for key: String) throws -> String {
        let data = try storage.retrieve(for: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw TransformationError.invalidData
        }
        return string
    }
    
    // MARK: - Boolean Operations
    
    /// Store boolean data
    public func storeBool(_ value: Bool, for key: String) throws {
        let data = Data([value ? 1 : 0])
        try storage.store(data, for: key)
    }
    
    /// Retrieve boolean data
    public func retrieveBool(for key: String) throws -> Bool {
        let data = try storage.retrieve(for: key)
        guard let byte = data.first else {
            throw TransformationError.invalidData
        }
        return byte != 0
    }
    
    // MARK: - Codable Operations
    
    /// Store Codable object
    public func storeCodable<T: Codable>(_ object: T, for key: String) throws {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(object)
            
            if let encryptionService = encryptionService {
                let encryptedData = try encryptionService.encrypt(data)
                try storage.store(encryptedData, for: key)
            } else {
                try storage.store(data, for: key)
            }
        } catch {
            throw TransformationError.encodingFailed(error)
        }
    }
    
    /// Retrieve Codable object
    public func retrieveCodable<T: Codable>(_ type: T.Type, for key: String) throws -> T {
        do {
            let storedData = try storage.retrieve(for: key)
            
            let data: Data
            if let encryptionService = encryptionService {
                data = try encryptionService.decrypt(storedData)
            } else {
                data = storedData
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: data)
        } catch let error as EncryptionService.EncryptionError {
            throw TransformationError.decodingFailed(error)
        } catch {
            throw TransformationError.decodingFailed(error)
        }
    }
    
    // MARK: - JSON Operations
    
    /// Store JSON serializable data
    public func storeJSONSerializable(_ object: Any, for key: String) throws {
        guard JSONSerialization.isValidJSONObject(object) else {
            throw TransformationError.serializationFailed
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: object)
            try storage.store(jsonData, for: key)
        } catch {
            throw TransformationError.serializationFailed
        }
    }
    
    /// Retrieve JSON serializable data
    public func retrieveJSONSerializable(for key: String) throws -> Any {
        let data = try storage.retrieve(for: key)
        
        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            throw TransformationError.decodingFailed(error)
        }
    }
    
    // MARK: - Migration Helpers
    
    /// Migrate data from UserDefaults
    public func migrateFromUserDefaults(keys: [String]) {
        for key in keys {
            // Skip if already migrated
            if storage.exists(for: key) {
                continue
            }
            
            // Try different UserDefaults data types
            if let data = UserDefaults.standard.data(forKey: key) {
                try? storage.store(data, for: key)
                UserDefaults.standard.removeObject(forKey: key)
            } else if let string = UserDefaults.standard.string(forKey: key) {
                try? storeString(string, for: key)
                UserDefaults.standard.removeObject(forKey: key)
            } else if UserDefaults.standard.object(forKey: key) != nil {
                let boolValue = UserDefaults.standard.bool(forKey: key)
                try? storeBool(boolValue, for: key)
                UserDefaults.standard.removeObject(forKey: key)
            }
            
            #if DEBUG
            print("Migrated \(key) to Keychain")
            #endif
        }
    }
    
    /// Cleanup legacy data
    public func cleanupLegacyData(keys: [String]) {
        for key in keys {
            if storage.exists(for: key) {
                #if DEBUG
                print("[Security Migration] Removing legacy data for key: \(key)")
                #endif
                try? storage.delete(for: key)
            }
        }
    }
}