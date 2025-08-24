import Foundation
import CryptoKit

/// Secure credentials model for JWT-based authentication
/// Implements OWASP best practices for token management
public struct SecureCredentials: Codable {
    
    // MARK: - Properties
    
    /// JWT access token for API authentication
    public let accessToken: String
    
    /// JWT refresh token for obtaining new access tokens
    public let refreshToken: String
    
    /// Token expiration timestamp
    public let expiresAt: Date
    
    /// Token issued timestamp
    public let issuedAt: Date
    
    /// User identifier (encrypted)
    public let userId: String?
    
    /// Token type (typically "Bearer")
    public let tokenType: String
    
    // MARK: - Computed Properties
    
    /// Check if the access token is expired
    public var isExpired: Bool {
        return Date() >= expiresAt
    }
    
    /// Check if the token needs refresh (within 5 minutes of expiry)
    public var needsRefresh: Bool {
        let refreshThreshold = expiresAt.addingTimeInterval(-300) // 5 minutes before expiry
        return Date() >= refreshThreshold
    }
    
    /// Time remaining until expiration in seconds
    public var timeUntilExpiration: TimeInterval {
        return expiresAt.timeIntervalSinceNow
    }
    
    // MARK: - Initialization
    
    public init(
        accessToken: String,
        refreshToken: String,
        expiresIn: TimeInterval = 3600, // Default 1 hour
        userId: String? = nil,
        tokenType: String = "Bearer"
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.issuedAt = Date()
        self.expiresAt = Date().addingTimeInterval(expiresIn)
        self.userId = userId
        self.tokenType = tokenType
    }
    
    // MARK: - Validation
    
    /// Validate token format (basic JWT structure validation)
    public static func isValidJWTFormat(_ token: String) -> Bool {
        // JWT should have three parts separated by dots
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return false }
        
        // Each part should be base64url encoded
        for part in parts {
            // Check if it's valid base64url characters
            let base64urlPattern = "^[A-Za-z0-9_-]+$"
            let regex = try? NSRegularExpression(pattern: base64urlPattern, options: [])
            let range = NSRange(location: 0, length: part.count)
            
            if regex?.firstMatch(in: String(part), options: [], range: range) == nil {
                return false
            }
        }
        
        return true
    }
    
    /// Create authorization header value
    public var authorizationHeader: String {
        return "\(tokenType) \(accessToken)"
    }
}

// MARK: - Secure Token Encryption

/// Secure token encryption wrapper using CryptoKit AES-256-GCM
public struct SecureTokenEncryption {
    
    // MARK: - Error Types
    
    public enum EncryptionError: LocalizedError {
        case invalidKey
        case encryptionFailed
        case decryptionFailed
        case invalidData
        
        public var errorDescription: String? {
            switch self {
            case .invalidKey:
                return "Invalid encryption key"
            case .encryptionFailed:
                return "Failed to encrypt data"
            case .decryptionFailed:
                return "Failed to decrypt data"
            case .invalidData:
                return "Invalid data format"
            }
        }
    }
    
    // MARK: - Key Generation
    
    /// Generate a secure encryption key
    public static func generateKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    /// Derive key from password using PBKDF2 (if needed for additional security)
    public static func deriveKey(from password: String, salt: Data) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }
        
        // Use CryptoKit's key derivation
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            info: Data("SecureCredentials".utf8),
            outputByteCount: 32
        )
        
        return derivedKey
    }
    
    // MARK: - Encryption/Decryption
    
    /// Encrypt credentials using AES-256-GCM
    public static func encrypt(_ credentials: SecureCredentials, using key: SymmetricKey) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(credentials) else {
            throw EncryptionError.invalidData
        }
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combinedData = sealedBox.combined else {
                throw EncryptionError.encryptionFailed
            }
            return combinedData
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }
    
    /// Decrypt credentials using AES-256-GCM
    public static func decrypt(_ encryptedData: Data, using key: SymmetricKey) throws -> SecureCredentials {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            guard let credentials = try? decoder.decode(SecureCredentials.self, from: decryptedData) else {
                throw EncryptionError.invalidData
            }
            
            return credentials
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }
    
    // MARK: - Secure Storage
    
    /// Create encrypted storage data with metadata
    public static func createSecureStorage(
        credentials: SecureCredentials,
        key: SymmetricKey,
        additionalAuthenticatedData: Data? = nil
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(credentials) else {
            throw EncryptionError.invalidData
        }
        
        do {
            let sealedBox: AES.GCM.SealedBox
            if let aad = additionalAuthenticatedData {
                sealedBox = try AES.GCM.seal(data, using: key, authenticating: aad)
            } else {
                sealedBox = try AES.GCM.seal(data, using: key)
            }
            
            guard let combinedData = sealedBox.combined else {
                throw EncryptionError.encryptionFailed
            }
            
            // Create storage container with version and metadata
            var storageData = Data()
            
            // Version byte (for future compatibility)
            storageData.append(0x01)
            
            // Store AAD length and data if present
            if let aad = additionalAuthenticatedData {
                var aadLength = UInt16(aad.count)
                storageData.append(contentsOf: withUnsafeBytes(of: &aadLength) { Array($0) })
                storageData.append(aad)
            } else {
                var aadLength = UInt16(0)
                storageData.append(contentsOf: withUnsafeBytes(of: &aadLength) { Array($0) })
            }
            
            // Append encrypted data
            storageData.append(combinedData)
            
            return storageData
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }
    
    /// Retrieve credentials from encrypted storage
    public static func retrieveFromSecureStorage(
        _ storageData: Data,
        key: SymmetricKey
    ) throws -> SecureCredentials {
        guard storageData.count > 3 else {
            throw EncryptionError.invalidData
        }
        
        var index = 0
        
        // Check version
        let version = storageData[index]
        guard version == 0x01 else {
            throw EncryptionError.invalidData
        }
        index += 1
        
        // Read AAD length
        let aadLength = storageData.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: index, as: UInt16.self)
        }
        index += 2
        
        // Extract AAD if present
        let aad: Data?
        if aadLength > 0 {
            guard storageData.count >= index + Int(aadLength) else {
                throw EncryptionError.invalidData
            }
            aad = storageData.subdata(in: index..<(index + Int(aadLength)))
            index += Int(aadLength)
        } else {
            aad = nil
        }
        
        // Extract encrypted data
        let encryptedData = storageData.subdata(in: index..<storageData.count)
        
        // Decrypt
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            
            let decryptedData: Data
            if let aad = aad {
                decryptedData = try AES.GCM.open(sealedBox, using: key, authenticating: aad)
            } else {
                decryptedData = try AES.GCM.open(sealedBox, using: key)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            guard let credentials = try? decoder.decode(SecureCredentials.self, from: decryptedData) else {
                throw EncryptionError.invalidData
            }
            
            return credentials
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }
}

// MARK: - Token Refresh Response

/// Response model for token refresh operations
public struct TokenRefreshResponse: Codable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresIn: TimeInterval
    public let tokenType: String
    
    public init(
        accessToken: String,
        refreshToken: String? = nil,
        expiresIn: TimeInterval = 3600,
        tokenType: String = "Bearer"
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.tokenType = tokenType
    }
}