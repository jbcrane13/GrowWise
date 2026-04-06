import Foundation
@testable import GrowWiseServices
import Testing

struct DataTransformationServiceTests {
    // NOTE: Keychain writes fail in SSH test environments (errSecInteractionNotAllowed).
    // Tests focus on transformation logic, error paths, and read-from-missing-key behavior,
    // which do not require keychain write authorization.

    private func makeService() -> DataTransformationService {
        let keychain = KeychainService(service: "com.growwise.tests.\(UUID().uuidString)")
        return DataTransformationService(keychain: keychain)
    }

    // MARK: - String retrieval error paths

    @Test("retrieveString for nonexistent key throws TransformationError")
    func retrieveStringMissingKeyThrows() {
        let service = makeService()
        #expect(throws: DataTransformationService.TransformationError.self) {
            _ = try service.retrieveString(for: "nonexistent_key_\(UUID().uuidString)")
        }
    }

    @Test("retrieveString for different missing keys each throws independently")
    func retrieveStringMultipleMissingKeys() {
        let service = makeService()
        for i in 0 ..< 3 {
            #expect(throws: DataTransformationService.TransformationError.self) {
                _ = try service.retrieveString(for: "missing_\(i)_\(UUID().uuidString)")
            }
        }
    }

    // MARK: - Boolean retrieval error paths

    @Test("retrieveBool for nonexistent key throws TransformationError")
    func retrieveBoolMissingKeyThrows() {
        let service = makeService()
        #expect(throws: DataTransformationService.TransformationError.self) {
            _ = try service.retrieveBool(for: "nonexistent_bool_\(UUID().uuidString)")
        }
    }

    // MARK: - Codable retrieval error paths

    @Test("retrieveCodable for nonexistent key throws TransformationError")
    func codableMissingKeyThrows() {
        let service = makeService()
        struct Dummy: Codable { let x: Int }
        #expect(throws: DataTransformationService.TransformationError.self) {
            _ = try service.retrieveCodable(Dummy.self, for: "missing_\(UUID().uuidString)")
        }
    }

    // MARK: - JSON Serializable validation

    @Test("storeJSONSerializable with non-JSON-object string throws serializationFailed")
    func jsonSerializableInvalidStringThrows() {
        let service = makeService()
        // A bare string is not a valid JSON root object for JSONSerialization
        #expect(throws: DataTransformationService.TransformationError.self) {
            try service.storeJSONSerializable("just a string", for: "invalid_\(UUID().uuidString)")
        }
    }

    @Test("storeJSONSerializable with non-serializable value throws serializationFailed")
    func jsonSerializableNonSerializableThrows() {
        let service = makeService()
        // A Date is not JSON-serializable
        #expect(throws: DataTransformationService.TransformationError.self) {
            try service.storeJSONSerializable(Date(), for: "date_\(UUID().uuidString)")
        }
    }

    @Test("retrieveJSONSerializable for nonexistent key throws TransformationError")
    func jsonRetrieveMissingKeyThrows() {
        let service = makeService()
        #expect(throws: DataTransformationService.TransformationError.self) {
            _ = try service.retrieveJSONSerializable(for: "missing_json_\(UUID().uuidString)")
        }
    }

    // MARK: - Error type descriptions

    @Test("TransformationError.invalidData has a meaningful description")
    func invalidDataErrorDescription() {
        let error = DataTransformationService.TransformationError.invalidData
        #expect(error.errorDescription == "Invalid data format")
    }

    @Test("TransformationError.serializationFailed has a meaningful description")
    func serializationFailedErrorDescription() {
        let error = DataTransformationService.TransformationError.serializationFailed
        #expect(error.errorDescription == "JSON serialization failed")
    }

    @Test("TransformationError.checksumMismatch includes expected and actual values in description")
    func checksumMismatchErrorDescription() {
        let error = DataTransformationService.TransformationError.checksumMismatch(expected: "abc123", actual: "def456")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("abc123"))
        #expect(desc.contains("def456"))
        #expect(desc.contains("integrity"))
    }

    @Test("TransformationError.migrationVerificationFailed includes reason in description")
    func migrationVerificationFailedErrorDescription() {
        let error = DataTransformationService.TransformationError.migrationVerificationFailed("schema mismatch")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("schema mismatch"))
        #expect(desc.contains("Migration"))
    }

    @Test("TransformationError.encodingFailed wraps underlying error in description")
    func encodingFailedErrorDescription() {
        let underlying = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "encode broke"])
        let error = DataTransformationService.TransformationError.encodingFailed(underlying)
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("encode"))
    }

    @Test("TransformationError.decodingFailed wraps underlying error in description")
    func decodingFailedErrorDescription() {
        let underlying = NSError(domain: "test", code: 99, userInfo: [NSLocalizedDescriptionKey: "decode broke"])
        let error = DataTransformationService.TransformationError.decodingFailed(underlying)
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("decode"))
    }

    // MARK: - Service initialization

    @Test("DataTransformationService can be initialized with default keychain")
    func defaultInitialization() {
        let service = DataTransformationService()
        // Service should be constructible without errors; verify by attempting a read
        #expect(throws: DataTransformationService.TransformationError.self) {
            _ = try service.retrieveString(for: "definitely_missing_\(UUID().uuidString)")
        }
    }

    @Test("DataTransformationService instances with different keychains are independent")
    func independentInstances() {
        let service1 = makeService()
        let service2 = makeService()
        // Both should independently throw for missing keys -- they don't share state
        let key = "shared_key_\(UUID().uuidString)"
        #expect(throws: DataTransformationService.TransformationError.self) {
            _ = try service1.retrieveString(for: key)
        }
        #expect(throws: DataTransformationService.TransformationError.self) {
            _ = try service2.retrieveString(for: key)
        }
    }
}
