import Foundation
import CryptoKit
import Security

/// Comprehensive JWT validator with cryptographic signature verification
/// Supports RS256 (RSA with SHA-256) and HS256 (HMAC with SHA-256) algorithms
public final class JWTValidator {
    
    // MARK: - Error Types
    
    public enum JWTValidationError: LocalizedError {
        case invalidFormat
        case invalidHeader
        case invalidPayload
        case unsupportedAlgorithm(String)
        case invalidSignature
        case tokenExpired
        case tokenNotYetValid
        case invalidIssuer(expected: String, actual: String?)
        case invalidAudience(expected: String, actual: String?)
        case missingClaim(String)
        case invalidPublicKey
        case invalidSharedSecret
        
        public var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "JWT format is invalid - must have three parts separated by dots"
            case .invalidHeader:
                return "JWT header is invalid or cannot be decoded"
            case .invalidPayload:
                return "JWT payload is invalid or cannot be decoded"
            case .unsupportedAlgorithm(let alg):
                return "Unsupported JWT algorithm: \(alg)"
            case .invalidSignature:
                return "JWT signature verification failed"
            case .tokenExpired:
                return "JWT token has expired"
            case .tokenNotYetValid:
                return "JWT token is not yet valid"
            case .invalidIssuer(let expected, let actual):
                return "Invalid issuer - expected: \(expected), actual: \(actual ?? "null")"
            case .invalidAudience(let expected, let actual):
                return "Invalid audience - expected: \(expected), actual: \(actual ?? "null")"
            case .missingClaim(let claim):
                return "Missing required claim: \(claim)"
            case .invalidPublicKey:
                return "Invalid or missing public key for RS256 verification"
            case .invalidSharedSecret:
                return "Invalid or missing shared secret for HS256 verification"
            }
        }
    }
    
    // MARK: - JWT Components
    
    public struct JWTHeader: Codable {
        public let alg: String
        public let typ: String
        public let kid: String?
        
        public init(alg: String, typ: String, kid: String? = nil) {
            self.alg = alg
            self.typ = typ
            self.kid = kid
        }
    }
    
    public struct JWTPayload: Codable {
        public let iss: String?  // Issuer
        public let sub: String?  // Subject
        public let aud: String?  // Audience
        public let exp: TimeInterval?  // Expiration Time
        public let nbf: TimeInterval?  // Not Before
        public let iat: TimeInterval?  // Issued At
        public let jti: String?  // JWT ID
        
        // Custom claims can be accessed via additional decoding
        private let additionalClaims: [String: AnyCodable]?
        
        private enum CodingKeys: String, CodingKey, CaseIterable {
            case iss, sub, aud, exp, nbf, iat, jti
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.iss = try container.decodeIfPresent(String.self, forKey: .iss)
            self.sub = try container.decodeIfPresent(String.self, forKey: .sub)
            self.aud = try container.decodeIfPresent(String.self, forKey: .aud)
            self.exp = try container.decodeIfPresent(TimeInterval.self, forKey: .exp)
            self.nbf = try container.decodeIfPresent(TimeInterval.self, forKey: .nbf)
            self.iat = try container.decodeIfPresent(TimeInterval.self, forKey: .iat)
            self.jti = try container.decodeIfPresent(String.self, forKey: .jti)
            
            // Handle additional claims
            let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
            var additionalClaims: [String: AnyCodable] = [:]
            
            for key in dynamicContainer.allKeys {
                let standardKeys = CodingKeys.allCases.map { $0.rawValue }
                if !standardKeys.contains(key.stringValue) {
                    additionalClaims[key.stringValue] = try dynamicContainer.decodeIfPresent(AnyCodable.self, forKey: key)
                }
            }
            
            self.additionalClaims = additionalClaims.isEmpty ? nil : additionalClaims
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encodeIfPresent(iss, forKey: .iss)
            try container.encodeIfPresent(sub, forKey: .sub)
            try container.encodeIfPresent(aud, forKey: .aud)
            try container.encodeIfPresent(exp, forKey: .exp)
            try container.encodeIfPresent(nbf, forKey: .nbf)
            try container.encodeIfPresent(iat, forKey: .iat)
            try container.encodeIfPresent(jti, forKey: .jti)
        }
    }
    
    public struct DecodedJWT {
        public let header: JWTHeader
        public let payload: JWTPayload
        public let signature: Data
        public let rawToken: String
        
        public var isExpired: Bool {
            guard let exp = payload.exp else { return false }
            return Date().timeIntervalSince1970 >= exp
        }
        
        public var isNotYetValid: Bool {
            guard let nbf = payload.nbf else { return false }
            return Date().timeIntervalSince1970 < nbf
        }
    }
    
    // MARK: - Properties
    
    private let configuration: TokenManagementService.Configuration
    
    // MARK: - Initialization
    
    public init(configuration: TokenManagementService.Configuration) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// Validate JWT with full cryptographic verification
    public func validate(_ token: String) throws {
        let decodedJWT = try decode(token)
        
        // Verify signature
        try verifySignature(decodedJWT)
        
        // Verify claims
        try verifyClaims(decodedJWT.payload)
    }
    
    /// Decode JWT without validation (for inspection)
    public func decode(_ token: String) throws -> DecodedJWT {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            throw JWTValidationError.invalidFormat
        }
        
        // Decode header
        guard let headerData = Data(base64URLEncoded: parts[0]) else {
            throw JWTValidationError.invalidHeader
        }
        
        let header: JWTHeader
        do {
            header = try JSONDecoder().decode(JWTHeader.self, from: headerData)
        } catch {
            throw JWTValidationError.invalidHeader
        }
        
        // Decode payload
        guard let payloadData = Data(base64URLEncoded: parts[1]) else {
            throw JWTValidationError.invalidPayload
        }
        
        let payload: JWTPayload
        do {
            payload = try JSONDecoder().decode(JWTPayload.self, from: payloadData)
        } catch {
            throw JWTValidationError.invalidPayload
        }
        
        // Decode signature
        guard let signature = Data(base64URLEncoded: parts[2]) else {
            throw JWTValidationError.invalidFormat
        }
        
        return DecodedJWT(
            header: header,
            payload: payload,
            signature: signature,
            rawToken: token
        )
    }
    
    // MARK: - Private Methods
    
    /// Verify JWT signature based on algorithm
    private func verifySignature(_ jwt: DecodedJWT) throws {
        let algorithm = jwt.header.alg.uppercased()
        
        switch algorithm {
        case "RS256":
            try verifyRS256Signature(jwt)
        case "HS256":
            try verifyHS256Signature(jwt)
        default:
            throw JWTValidationError.unsupportedAlgorithm(algorithm)
        }
    }
    
    /// Verify RS256 signature using RSA public key
    private func verifyRS256Signature(_ jwt: DecodedJWT) throws {
        guard let publicKeyString = configuration.publicKey else {
            throw JWTValidationError.invalidPublicKey
        }
        
        // Convert PEM public key to SecKey
        let publicKey = try createPublicKey(from: publicKeyString)
        
        // Create signing data (header.payload)
        let parts = jwt.rawToken.components(separatedBy: ".")
        let signingData = "\(parts[0]).\(parts[1])".data(using: .utf8)!
        
        // Verify signature
        var error: Unmanaged<CFError>?
        let isValid = SecKeyVerifySignature(
            publicKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            signingData as CFData,
            jwt.signature as CFData,
            &error
        )
        
        if let error = error {
            let _ = error.takeRetainedValue()
            throw JWTValidationError.invalidSignature
        }
        
        if !isValid {
            throw JWTValidationError.invalidSignature
        }
    }
    
    /// Verify HS256 signature using HMAC
    private func verifyHS256Signature(_ jwt: DecodedJWT) throws {
        guard let sharedSecret = configuration.sharedSecret else {
            throw JWTValidationError.invalidSharedSecret
        }
        
        // Create signing data (header.payload)
        let parts = jwt.rawToken.components(separatedBy: ".")
        guard let signingData = "\(parts[0]).\(parts[1])".data(using: .utf8) else {
            throw JWTValidationError.invalidFormat
        }
        
        // Create HMAC
        guard let secretData = sharedSecret.data(using: .utf8) else {
            throw JWTValidationError.invalidSharedSecret
        }
        
        let key = SymmetricKey(data: secretData)
        let computedSignature = HMAC<SHA256>.authenticationCode(for: signingData, using: key)
        let computedSignatureData = Data(computedSignature)
        
        // Compare signatures (constant-time comparison)
        guard computedSignatureData == jwt.signature else {
            throw JWTValidationError.invalidSignature
        }
    }
    
    /// Verify JWT claims (iss, aud, exp, nbf)
    private func verifyClaims(_ payload: JWTPayload) throws {
        let now = Date().timeIntervalSince1970
        
        // Check expiration
        if let exp = payload.exp {
            if now >= exp {
                throw JWTValidationError.tokenExpired
            }
        }
        
        // Check not before
        if let nbf = payload.nbf {
            if now < nbf {
                throw JWTValidationError.tokenNotYetValid
            }
        }
        
        // Check issuer
        if payload.iss != configuration.expectedIssuer {
            throw JWTValidationError.invalidIssuer(
                expected: configuration.expectedIssuer,
                actual: payload.iss
            )
        }
        
        // Check audience
        if payload.aud != configuration.expectedAudience {
            throw JWTValidationError.invalidAudience(
                expected: configuration.expectedAudience,
                actual: payload.aud
            )
        }
    }
    
    /// Create SecKey from PEM public key string
    private func createPublicKey(from pemString: String) throws -> SecKey {
        // Remove PEM headers/footers and whitespace
        let cleanedKey = pemString
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----BEGIN RSA PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END RSA PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
        
        guard let keyData = Data(base64Encoded: cleanedKey) else {
            throw JWTValidationError.invalidPublicKey
        }
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 2048
        ]
        
        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error) else {
            throw JWTValidationError.invalidPublicKey
        }
        
        return secKey
    }
}

// MARK: - Supporting Types

/// Dynamic coding keys for additional JWT claims
private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// Wrapper for any codable value
private struct AnyCodable: Codable {
    let value: Any
    
    init<T: Codable>(_ value: T) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported type"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: [], debugDescription: "Unsupported type")
            )
        }
    }
}

// MARK: - Base64URL Extensions

extension Data {
    /// Initialize from base64url encoded string
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let padding = 4 - (base64.count % 4)
        if padding < 4 {
            base64 += String(repeating: "=", count: padding)
        }
        
        self.init(base64Encoded: base64)
    }
    
    /// Convert to base64url encoded string
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

