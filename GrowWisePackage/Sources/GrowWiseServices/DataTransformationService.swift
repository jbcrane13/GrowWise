import CryptoKit
import Foundation

// SwiftLint suppressions for #284 — pre-existing structural & style violations; refactor out of scope.
// swiftlint:disable pattern_matching_keywords

/// Service responsible for data transformation (Codable operations, serialization)
public final class DataTransformationService {
    // MARK: - Error Types

    public enum TransformationError: LocalizedError {
        case encodingFailed(Error)
        case decodingFailed(Error)
        case invalidData
        case serializationFailed
        case checksumMismatch(expected: String, actual: String)
        case migrationVerificationFailed(String)

        public var errorDescription: String? {
            switch self {
            case .encodingFailed(let error):
                "Failed to encode data: \(error.localizedDescription)"

            case .decodingFailed(let error):
                "Failed to decode data: \(error.localizedDescription)"

            case .invalidData:
                "Invalid data format"

            case .serializationFailed:
                "JSON serialization failed"

            case .checksumMismatch(let expected, let actual):
                "Data integrity check failed - expected: \(expected), actual: \(actual)"

            case .migrationVerificationFailed(let reason):
                "Migration verification failed: \(reason)"
            }
        }
    }

    // MARK: - Properties

    private let keychain: KeychainService

    // MARK: - Initialization

    public init(keychain: KeychainService = .shared) {
        self.keychain = keychain
    }

    // MARK: - String Operations

    /// Store string data
    public func storeString(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw TransformationError.invalidData
        }
        try keychain.store(data, for: key)
    }

    /// Retrieve string data
    public func retrieveString(for key: String) throws -> String {
        guard let data = try keychain.load(key: key) else {
            throw TransformationError.invalidData
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw TransformationError.invalidData
        }
        return string
    }

    // MARK: - Boolean Operations

    /// Store boolean data
    public func storeBool(_ value: Bool, for key: String) throws {
        let data = Data([value ? 1 : 0])
        try keychain.store(data, for: key)
    }

    /// Retrieve boolean data
    public func retrieveBool(for key: String) throws -> Bool {
        guard let data = try keychain.load(key: key) else {
            throw TransformationError.invalidData
        }
        guard let byte = data.first else {
            throw TransformationError.invalidData
        }
        return byte != 0
    }

    // MARK: - Codable Operations

    /// Store Codable object
    public func storeCodable(_ object: some Codable, for key: String) throws {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(object)
            try keychain.store(data, for: key)
        } catch {
            throw TransformationError.encodingFailed(error)
        }
    }

    /// Retrieve Codable object
    public func retrieveCodable<T: Codable>(_ type: T.Type, for key: String) throws -> T {
        do {
            guard let storedData = try keychain.load(key: key) else {
                throw TransformationError.invalidData
            }
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: storedData)
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
            try keychain.store(jsonData, for: key)
        } catch {
            throw TransformationError.serializationFailed
        }
    }

    /// Retrieve JSON serializable data
    public func retrieveJSONSerializable(for key: String) throws -> Any {
        guard let data = try keychain.load(key: key) else {
            throw TransformationError.invalidData
        }

        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            throw TransformationError.decodingFailed(error)
        }
    }

    // MARK: - Checksum Utilities

    /// Calculate SHA-256 checksum for data
    private func calculateChecksum(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// swiftlint:enable pattern_matching_keywords
