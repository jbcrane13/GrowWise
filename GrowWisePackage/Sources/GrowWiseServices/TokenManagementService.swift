import Foundation
import CryptoKit
import GrowWiseModels

/// Service responsible for JWT token management and validation
public final class TokenManagementService {
    
    // MARK: - Error Types
    
    public enum TokenError: LocalizedError {
        case tokenExpired
        case invalidTokenFormat
        case invalidSignature
        case invalidIssuer
        case invalidAudience
        case notYetValid
        case unsupportedAlgorithm
        case encryptionFailed
        case decryptionFailed
        case storageError(Error)
        
        public var errorDescription: String? {
            switch self {
            case .tokenExpired:
                return "Authentication token has expired"
            case .invalidTokenFormat:
                return "Token format is invalid"
            case .invalidSignature:
                return "Token signature is invalid"
            case .invalidIssuer:
                return "Token issuer is invalid"
            case .invalidAudience:
                return "Token audience is invalid"
            case .notYetValid:
                return "Token is not yet valid"
            case .unsupportedAlgorithm:
                return "Token algorithm is not supported"
            case .encryptionFailed:
                return "Failed to encrypt token"
            case .decryptionFailed:
                return "Failed to decrypt token"
            case .storageError(let error):
                return "Storage error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Properties
    
    private let encryptionService: EncryptionService
    private let storage: KeychainStorageService
    private let jwtValidator: JWTValidator
    
    // MARK: - Configuration
    
    public struct Configuration {
        public let expectedIssuer: String
        public let expectedAudience: String
        public let publicKey: String? // For RS256 verification
        public let sharedSecret: String? // For HS256 verification
        
        public init(
            expectedIssuer: String,
            expectedAudience: String,
            publicKey: String? = nil,
            sharedSecret: String? = nil
        ) {
            self.expectedIssuer = expectedIssuer
            self.expectedAudience = expectedAudience
            self.publicKey = publicKey
            self.sharedSecret = sharedSecret
        }
    }
    
    private let configuration: Configuration
    
    // MARK: - Initialization
    
    public init(
        encryptionService: EncryptionService,
        storage: KeychainStorageService,
        configuration: Configuration
    ) {
        self.encryptionService = encryptionService
        self.storage = storage
        self.configuration = configuration
        self.jwtValidator = JWTValidator(configuration: configuration)
    }
    
    /// Convenience initializer with default configuration
    public convenience init(
        encryptionService: EncryptionService,
        storage: KeychainStorageService
    ) {
        let defaultConfig = Configuration(
            expectedIssuer: "com.growwiser.app",
            expectedAudience: "growwiser-api"
        )
        self.init(
            encryptionService: encryptionService,
            storage: storage,
            configuration: defaultConfig
        )
    }
    
    // MARK: - Public Methods
    
    /// Store secure JWT credentials with cryptographic validation
    public func storeSecureCredentials(_ credentials: SecureCredentials) throws {
        // Perform full JWT validation including signature and claims
        try jwtValidator.validate(credentials.accessToken)
        
        if !credentials.refreshToken.isEmpty {
            try jwtValidator.validate(credentials.refreshToken)
        }
        
        do {
            // Create secure storage with encryption and authentication
            let encryptedData = try createSecureStorage(
                credentials: credentials,
                authenticatedData: Data("com.growwiser.app".utf8)
            )
            
            try storage.store(encryptedData, for: "secure_jwt_credentials_v2")
            
            // Store metadata separately (non-sensitive)
            try storeTokenMetadata(credentials)
        } catch {
            throw TokenError.storageError(error)
        }
    }
    
    /// Retrieve secure JWT credentials
    public func retrieveSecureCredentials() throws -> SecureCredentials {
        do {
            let encryptedData = try storage.retrieve(for: "secure_jwt_credentials_v2")
            let credentials = try retrieveFromSecureStorage(encryptedData)
            
            // Check if token is expired
            if credentials.isExpired {
                throw TokenError.tokenExpired
            }
            
            return credentials
        } catch let error as KeychainStorageService.StorageError {
            throw TokenError.storageError(error)
        }
    }
    
    /// Store access token only (for quick access) with validation
    public func storeAccessToken(_ token: String) throws {
        // Perform full JWT validation
        try jwtValidator.validate(token)
        
        do {
            guard let tokenData = token.data(using: .utf8) else {
                throw TokenError.invalidTokenFormat
            }
            
            let encryptedData = try encryptionService.encrypt(tokenData)
            try storage.store(encryptedData, for: "encrypted_access_token_v2")
        } catch {
            throw TokenError.storageError(error)
        }
    }
    
    /// Retrieve access token
    public func retrieveAccessToken() throws -> String {
        do {
            let encryptedData = try storage.retrieve(for: "encrypted_access_token_v2")
            let decryptedData = try encryptionService.decrypt(encryptedData)
            
            guard let token = String(data: decryptedData, encoding: .utf8) else {
                throw TokenError.decryptionFailed
            }
            
            return token
        } catch {
            throw TokenError.storageError(error)
        }
    }
    
    /// Update tokens after refresh
    public func updateTokensAfterRefresh(response: TokenRefreshResponse) throws {
        // Retrieve existing credentials to preserve metadata
        if let existingCredentials = try? retrieveSecureCredentials() {
            let updatedCredentials = SecureCredentials(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken ?? existingCredentials.refreshToken,
                expiresIn: response.expiresIn,
                userId: existingCredentials.userId,
                tokenType: response.tokenType
            )
            try storeSecureCredentials(updatedCredentials)
        } else {
            // Create new credentials if none exist
            let newCredentials = SecureCredentials(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken ?? "",
                expiresIn: response.expiresIn,
                tokenType: response.tokenType
            )
            try storeSecureCredentials(newCredentials)
        }
    }
    
    /// Check if credentials need refresh
    public func credentialsNeedRefresh() -> Bool {
        guard let credentials = try? retrieveSecureCredentials() else {
            return true
        }
        return credentials.needsRefresh
    }
    
    /// Clear all token data
    public func clearAllTokens() {
        let tokenKeys = [
            "secure_jwt_credentials_v2",
            "encrypted_access_token_v2",
            "jwt_metadata_v2"
        ]
        
        for key in tokenKeys {
            try? storage.delete(for: key)
        }
    }
    
    // MARK: - Private Methods
    
    /// Legacy format validation - use JWTValidator for full validation
    private func isValidJWTFormat(_ token: String) -> Bool {
        let parts = token.components(separatedBy: ".")
        return parts.count == 3 && !parts.contains(where: { $0.isEmpty })
    }
    
    /// Validate JWT with full cryptographic verification
    public func validateJWT(_ token: String) throws {
        try jwtValidator.validate(token)
    }
    
    /// Create secure encrypted storage for credentials
    private func createSecureStorage(credentials: SecureCredentials, authenticatedData: Data) throws -> Data {
        let encoder = JSONEncoder()
        let credentialsData = try encoder.encode(credentials)
        return try encryptionService.encrypt(credentialsData, authenticatedData: authenticatedData)
    }
    
    /// Retrieve credentials from secure storage
    private func retrieveFromSecureStorage(_ encryptedData: Data) throws -> SecureCredentials {
        let authenticatedData = Data("com.growwiser.app".utf8)
        let decryptedData = try encryptionService.decrypt(encryptedData, authenticatedData: authenticatedData)
        
        let decoder = JSONDecoder()
        return try decoder.decode(SecureCredentials.self, from: decryptedData)
    }
    
    /// Store token metadata separately
    private func storeTokenMetadata(_ credentials: SecureCredentials) throws {
        let metadata: [String: Any] = [
            "issuedAt": credentials.issuedAt.timeIntervalSince1970,
            "expiresAt": credentials.expiresAt.timeIntervalSince1970,
            "tokenType": credentials.tokenType
        ]
        
        if let metadataData = try? JSONSerialization.data(withJSONObject: metadata) {
            try? storage.store(metadataData, for: "jwt_metadata_v2")
        }
    }
}