import XCTest
import CryptoKit
@testable import GrowWiseServices

final class SecureEnclaveKeyManagerTests: XCTestCase {
    
    var keyManager: SecureEnclaveKeyManager!
    let testKeyIdentifier = "test-secure-enclave-key"
    
    override func setUp() {
        super.setUp()
        keyManager = SecureEnclaveKeyManager(keyIdentifier: testKeyIdentifier)
        
        // Clean up any existing test keys
        try? keyManager.deleteSecureEnclaveKey()
    }
    
    override func tearDown() {
        // Clean up test keys
        try? keyManager.deleteSecureEnclaveKey()
        keyManager = nil
        super.tearDown()
    }
    
    func testSecureEnclaveAvailability() {
        // This test will vary based on the test environment
        // In iOS Simulator, Secure Enclave may not be available
        let isAvailable = SecureEnclaveKeyManager.isSecureEnclaveAvailable
        
        // Just verify that the property can be accessed
        XCTAssertNotNil(isAvailable)
        
        if isAvailable {
            print("Secure Enclave is available in this test environment")
        } else {
            print("Secure Enclave is not available in this test environment")
        }
    }
    
    func testInitialKeyState() {
        // Initially, no Secure Enclave key should exist
        XCTAssertFalse(keyManager.hasSecureEnclaveKey())
    }
    
    func testSymmetricKeyGeneration() throws {
        // Skip test if Secure Enclave is not available
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Get symmetric key should generate a new key if none exists
        let key1 = try keyManager.getSymmetricKey()
        XCTAssertTrue(keyManager.hasSecureEnclaveKey())
        
        // Getting the key again should return the same key (cached)
        let key2 = try keyManager.getSymmetricKey()
        XCTAssertEqual(key1.withUnsafeBytes { Data($0) }, key2.withUnsafeBytes { Data($0) })
    }
    
    func testKeyGeneration() throws {
        // Skip test if Secure Enclave is not available
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Generate a new Secure Enclave key
        let privateKey = try keyManager.generateSecureEnclaveKey()
        
        // Verify key was generated
        XCTAssertTrue(keyManager.hasSecureEnclaveKey())
        
        // Verify we can access the public key
        let publicKeyData = try keyManager.getPublicKeyData()
        XCTAssertEqual(publicKeyData.count, 65) // Uncompressed P256 public key
        XCTAssertEqual(privateKey.publicKey.rawRepresentation, publicKeyData)
    }
    
    func testKeyDeletion() throws {
        // Skip test if Secure Enclave is not available
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Generate a key
        try keyManager.generateSecureEnclaveKey()
        XCTAssertTrue(keyManager.hasSecureEnclaveKey())
        
        // Delete the key
        try keyManager.deleteSecureEnclaveKey()
        XCTAssertFalse(keyManager.hasSecureEnclaveKey())
    }
    
    func testKeyRotation() throws {
        // Skip test if Secure Enclave is not available
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Generate initial key
        let initialKey = try keyManager.getSymmetricKey()
        let initialPublicKey = try keyManager.getPublicKeyData()
        
        // Rotate the key
        try keyManager.rotateKey()
        
        // Verify key was rotated
        let newKey = try keyManager.getSymmetricKey()
        let newPublicKey = try keyManager.getPublicKeyData()
        
        XCTAssertNotEqual(
            initialKey.withUnsafeBytes { Data($0) },
            newKey.withUnsafeBytes { Data($0) }
        )
        XCTAssertNotEqual(initialPublicKey, newPublicKey)
    }
    
    func testKeyDerivationConsistency() throws {
        // Skip test if Secure Enclave is not available
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Generate key
        let key1 = try keyManager.getSymmetricKey()
        
        // Create new key manager instance with same identifier
        let keyManager2 = SecureEnclaveKeyManager(keyIdentifier: testKeyIdentifier)
        let key2 = try keyManager2.getSymmetricKey()
        
        // Keys should be identical (derived from same Secure Enclave key)
        XCTAssertEqual(
            key1.withUnsafeBytes { Data($0) },
            key2.withUnsafeBytes { Data($0) }
        )
        
        // Clean up
        try keyManager2.deleteSecureEnclaveKey()
    }
    
    func testSecureEnclaveNotAvailableError() {
        // Test error handling when Secure Enclave is not available
        // This test will only pass in environments without Secure Enclave
        
        if !SecureEnclaveKeyManager.isSecureEnclaveAvailable {
            XCTAssertThrowsError(try keyManager.generateSecureEnclaveKey()) { error in
                XCTAssertTrue(error is SecureEnclaveKeyManager.SecureEnclaveError)
                if let seError = error as? SecureEnclaveKeyManager.SecureEnclaveError {
                    XCTAssertEqual(seError, .secureEnclaveNotAvailable)
                }
            }
        }
    }
    
    func testKeyNotFoundError() throws {
        // Skip test if Secure Enclave is not available
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Ensure no key exists
        try keyManager.deleteSecureEnclaveKey()
        
        // Try to get public key data when no key exists
        XCTAssertThrowsError(try keyManager.getPublicKeyData()) { error in
            XCTAssertTrue(error is SecureEnclaveKeyManager.SecureEnclaveError)
            if let seError = error as? SecureEnclaveKeyManager.SecureEnclaveError {
                XCTAssertEqual(seError, .keyNotFound)
            }
        }
    }
    
    func testMultipleKeyManagers() throws {
        // Skip test if Secure Enclave is not available
        guard SecureEnclaveKeyManager.isSecureEnclaveAvailable else {
            throw XCTSkip("Secure Enclave not available in test environment")
        }
        
        // Create multiple key managers with different identifiers
        let keyManager1 = SecureEnclaveKeyManager(keyIdentifier: "test-key-1")
        let keyManager2 = SecureEnclaveKeyManager(keyIdentifier: "test-key-2")
        
        defer {
            try? keyManager1.deleteSecureEnclaveKey()
            try? keyManager2.deleteSecureEnclaveKey()
        }
        
        // Generate keys for both
        let key1 = try keyManager1.getSymmetricKey()
        let key2 = try keyManager2.getSymmetricKey()
        
        // Keys should be different
        XCTAssertNotEqual(
            key1.withUnsafeBytes { Data($0) },
            key2.withUnsafeBytes { Data($0) }
        )
        
        // Each should have its own key
        XCTAssertTrue(keyManager1.hasSecureEnclaveKey())
        XCTAssertTrue(keyManager2.hasSecureEnclaveKey())
        
        // Deleting one should not affect the other
        try keyManager1.deleteSecureEnclaveKey()
        XCTAssertFalse(keyManager1.hasSecureEnclaveKey())
        XCTAssertTrue(keyManager2.hasSecureEnclaveKey())
    }
}