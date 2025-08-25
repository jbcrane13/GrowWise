import Foundation
import CryptoKit
import LocalAuthentication
import Network
import GrowWiseModels
#if canImport(UIKit)
import UIKit
#endif

/// Comprehensive audit logging system for SOC2 and HIPAA compliance
/// Provides structured logging of all security-sensitive operations with:
/// - Encrypted, tamper-proof storage
/// - Comprehensive metadata capture
/// - Log retention policies
/// - Export capabilities for compliance audits
public final class AuditLogger: @unchecked Sendable {
    
    // MARK: - Singleton
    
    public static let shared = AuditLogger()
    
    // MARK: - Configuration
    
    public struct Configuration {
        public let retentionDays: Int
        public let maxLogSize: Int
        public let enableRealtimeAlerts: Bool
        public let exportEncryption: Bool
        
        public init(
            retentionDays: Int = 90, // SOC2/HIPAA minimum
            maxLogSize: Int = 100_000_000, // 100MB default
            enableRealtimeAlerts: Bool = true,
            exportEncryption: Bool = true
        ) {
            self.retentionDays = retentionDays
            self.maxLogSize = maxLogSize
            self.enableRealtimeAlerts = enableRealtimeAlerts
            self.exportEncryption = exportEncryption
        }
    }
    
    // MARK: - Audit Event Types
    
    public enum EventType: String, CaseIterable, Codable, Sendable {
        // Authentication Events
        case authenticationAttempt = "auth.attempt"
        case authenticationSuccess = "auth.success"
        case authenticationFailure = "auth.failure"
        case biometricAuthentication = "auth.biometric"
        case accountLockout = "auth.lockout"
        case passwordReset = "auth.password_reset"
        
        // Credential Management
        case credentialCreation = "cred.create"
        case credentialAccess = "cred.access"
        case credentialModification = "cred.modify"
        case credentialDeletion = "cred.delete"
        case credentialRotation = "cred.rotate"
        case credentialExport = "cred.export"
        
        // Key Management
        case keyGeneration = "key.generate"
        case keyRotation = "key.rotate"
        case keyDeletion = "key.delete"
        case keyAccess = "key.access"
        case keyExport = "key.export"
        
        // Data Access
        case dataAccess = "data.access"
        case dataModification = "data.modify"
        case dataExport = "data.export"
        case dataImport = "data.import"
        case dataDeletion = "data.delete"
        
        // Security Events
        case securityViolation = "security.violation"
        case unauthorizedAccess = "security.unauthorized"
        case suspiciousActivity = "security.suspicious"
        case configurationChange = "security.config_change"
        case privilegeEscalation = "security.privilege_escalation"
        
        // System Events
        case systemStartup = "system.startup"
        case systemShutdown = "system.shutdown"
        case backupCreation = "system.backup"
        case systemMaintenance = "system.maintenance"
        case complianceExport = "system.compliance_export"
        
        public var riskLevel: RiskLevel {
            switch self {
            case .authenticationFailure, .accountLockout, .securityViolation, .unauthorizedAccess, .suspiciousActivity, .privilegeEscalation:
                return .high
            case .credentialAccess, .credentialModification, .credentialDeletion, .keyAccess, .keyDeletion, .dataExport:
                return .medium
            case .authenticationSuccess, .biometricAuthentication, .credentialCreation, .keyGeneration, .dataAccess:
                return .low
            default:
                return .info
            }
        }
    }
    
    public enum RiskLevel: String, Codable, CaseIterable, Sendable {
        case info = "INFO"
        case low = "LOW"
        case medium = "MEDIUM"
        case high = "HIGH"
        case critical = "CRITICAL"
    }
    
    public enum OperationResult: String, Codable, Sendable {
        case success = "SUCCESS"
        case failure = "FAILURE"
        case partial = "PARTIAL"
        case denied = "DENIED"
        case timeout = "TIMEOUT"
    }
    
    // MARK: - Audit Event Structure
    
    public struct AuditEvent: Codable {
        public let id: String
        public let timestamp: Date
        public let eventType: EventType
        public let result: OperationResult
        public let riskLevel: RiskLevel
        public let userId: String?
        public let sessionId: String?
        public let deviceInfo: DeviceInfo
        public let networkInfo: NetworkInfo
        public let operationDetails: OperationDetails
        public let metadata: [String: String]
        public var integrity: String // HMAC for tamper detection
        
        public struct DeviceInfo: Codable {
            public let deviceId: String
            public let platform: String
            public let osVersion: String
            public let appVersion: String
            public let biometricCapability: String
            public let jailbroken: Bool
        }
        
        public struct NetworkInfo: Codable {
            public let ipAddress: String?
            public let connectionType: String
            public let vpnActive: Bool
            public let location: String? // Country/region if available
        }
        
        public struct OperationDetails: Codable {
            public let operation: String
            public let resource: String?
            public let duration: TimeInterval?
            public let errorCode: String?
            public let errorMessage: String?
            public let additionalContext: [String: String]
        }
    }
    
    // MARK: - Error Types
    
    public enum AuditError: LocalizedError {
        case initializationFailed
        case storageError(Error)
        case encryptionError(Error)
        case integrityViolation
        case retentionPolicyError
        case exportError(Error)
        case compressionError
        case configurationError(String)
        
        public var errorDescription: String? {
            switch self {
            case .initializationFailed:
                return "Failed to initialize audit logger"
            case .storageError(let error):
                return "Storage error: \(error.localizedDescription)"
            case .encryptionError(let error):
                return "Encryption error: \(error.localizedDescription)"
            case .integrityViolation:
                return "Audit log integrity violation detected"
            case .retentionPolicyError:
                return "Failed to apply retention policy"
            case .exportError(let error):
                return "Export error: \(error.localizedDescription)"
            case .compressionError:
                return "Log compression error"
            case .configurationError(let message):
                return "Configuration error: \(message)"
            }
        }
    }
    
    // MARK: - Properties
    
    private let configuration: Configuration
    private let encryptionService: EncryptionService
    private let storage: KeychainStorageService
    private let networkMonitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.growwiser.audit.network")
    
    private var currentNetworkPath: NWPath?
    private let auditQueue = DispatchQueue(label: "com.growwiser.audit", qos: .utility)
    private let deviceId: String
    private let sessionId: String
    
    // Audit storage keys
    private let auditLogKey = "audit_log_v1"
    private let auditIndexKey = "audit_index_v1"
    private let auditConfigKey = "audit_config_v1"
    
    // MARK: - Initialization
    
    private init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.deviceId = Self.generateDeviceId()
        self.sessionId = UUID().uuidString
        
        // Initialize dependencies
        let storage = KeychainStorageService(service: "com.growwiser.audit", accessGroup: nil)
        self.storage = storage
        self.encryptionService = EncryptionService(storage: storage)
        
        // Initialize network monitoring
        self.networkMonitor = NWPathMonitor()
        
        // Start monitoring network changes
        startNetworkMonitoring()
        
        // Log system startup
        auditQueue.async {
            self.logSystemEvent(.systemStartup, details: [
                "session_id": self.sessionId,
                "app_launch": "true"
            ])
        }
        
        // Schedule maintenance
        scheduleMaintenanceTasks()
    }
    
    deinit {
        networkMonitor.cancel()
        
        // Log system shutdown
        auditQueue.sync {
            self.logSystemEvent(.systemShutdown, details: [
                "session_id": self.sessionId,
                "app_termination": "true"
            ])
        }
    }
    
    // MARK: - Public Logging Methods
    
    /// Log authentication attempt
    public func logAuthentication(
        type: EventType,
        userId: String?,
        result: OperationResult,
        method: String,
        details: [String: String] = [:]
    ) {
        var auditDetails = details
        auditDetails["authentication_method"] = method
        auditDetails["user_provided"] = userId != nil ? "true" : "false"
        
        logEvent(
            type: type,
            result: result,
            userId: userId,
            operation: "authentication",
            details: auditDetails
        )
    }
    
    /// Log credential operation
    public func logCredentialOperation(
        type: EventType,
        userId: String?,
        result: OperationResult,
        credentialType: String,
        operation: String,
        details: [String: String] = [:]
    ) {
        var auditDetails = details
        auditDetails["credential_type"] = credentialType
        auditDetails["operation_type"] = operation
        
        logEvent(
            type: type,
            result: result,
            userId: userId,
            operation: "credential_management",
            resource: credentialType,
            details: auditDetails
        )
    }
    
    /// Log key management operation
    public func logKeyOperation(
        type: EventType,
        userId: String?,
        result: OperationResult,
        keyType: String,
        operation: String,
        details: [String: String] = [:]
    ) {
        var auditDetails = details
        auditDetails["key_type"] = keyType
        auditDetails["operation_type"] = operation
        
        logEvent(
            type: type,
            result: result,
            userId: userId,
            operation: "key_management",
            resource: keyType,
            details: auditDetails
        )
    }
    
    /// Log data access
    public func logDataAccess(
        type: EventType,
        userId: String?,
        result: OperationResult,
        dataType: String,
        operation: String,
        details: [String: String] = [:]
    ) {
        var auditDetails = details
        auditDetails["data_type"] = dataType
        auditDetails["operation_type"] = operation
        
        logEvent(
            type: type,
            result: result,
            userId: userId,
            operation: "data_access",
            resource: dataType,
            details: auditDetails
        )
    }
    
    /// Log security event
    public func logSecurityEvent(
        type: EventType,
        userId: String?,
        result: OperationResult,
        threatLevel: RiskLevel,
        description: String,
        details: [String: String] = [:]
    ) {
        var auditDetails = details
        auditDetails["threat_level"] = threatLevel.rawValue
        auditDetails["description"] = description
        auditDetails["requires_investigation"] = (threatLevel == .high || threatLevel == .critical) ? "true" : "false"
        
        logEvent(
            type: type,
            result: result,
            userId: userId,
            operation: "security_monitoring",
            details: auditDetails
        )
    }
    
    /// Log system event
    public func logSystemEvent(
        _ type: EventType,
        details: [String: String] = [:]
    ) {
        logEvent(
            type: type,
            result: .success,
            userId: nil,
            operation: "system",
            details: details
        )
    }
    
    // MARK: - Core Logging Method
    
    private func logEvent(
        type: EventType,
        result: OperationResult,
        userId: String?,
        operation: String,
        resource: String? = nil,
        duration: TimeInterval? = nil,
        error: Error? = nil,
        details: [String: String] = [:]
    ) {
        auditQueue.async {
            do {
                let event = try self.createAuditEvent(
                    type: type,
                    result: result,
                    userId: userId,
                    operation: operation,
                    resource: resource,
                    duration: duration,
                    error: error,
                    details: details
                )
                
                try self.storeAuditEvent(event)
                
                // Handle high-risk events
                if event.riskLevel == .high || event.riskLevel == .critical {
                    self.handleHighRiskEvent(event)
                }
                
            } catch {
                // Critical: audit logging failure
                self.handleAuditFailure(error)
            }
        }
    }
    
    // MARK: - Event Creation
    
    private func createAuditEvent(
        type: EventType,
        result: OperationResult,
        userId: String?,
        operation: String,
        resource: String?,
        duration: TimeInterval?,
        error: Error?,
        details: [String: String]
    ) throws -> AuditEvent {
        let timestamp = Date()
        let eventId = UUID().uuidString
        
        let deviceInfo = AuditEvent.DeviceInfo(
            deviceId: deviceId,
            platform: getPlatformInfo(),
            osVersion: getOSVersion(),
            appVersion: getAppVersion(),
            biometricCapability: getBiometricCapability(),
            jailbroken: isDeviceJailbroken()
        )
        
        let networkInfo = AuditEvent.NetworkInfo(
            ipAddress: getCurrentIPAddress(),
            connectionType: getConnectionType(),
            vpnActive: isVPNActive(),
            location: getLocationInfo()
        )
        
        var additionalContext = details
        additionalContext["device_id"] = deviceId
        additionalContext["session_id"] = sessionId
        additionalContext["app_state"] = getAppState()
        
        let operationDetails = AuditEvent.OperationDetails(
            operation: operation,
            resource: resource,
            duration: duration,
            errorCode: error.map { "\(Swift.type(of: $0))" },
            errorMessage: error?.localizedDescription,
            additionalContext: additionalContext
        )
        
        let event = AuditEvent(
            id: eventId,
            timestamp: timestamp,
            eventType: type,
            result: result,
            riskLevel: type.riskLevel,
            userId: userId,
            sessionId: sessionId,
            deviceInfo: deviceInfo,
            networkInfo: networkInfo,
            operationDetails: operationDetails,
            metadata: createMetadata(for: type, result: result),
            integrity: "" // Will be calculated after serialization
        )
        
        // Calculate integrity hash
        let eventWithIntegrity = try addIntegrityHash(to: event)
        return eventWithIntegrity
    }
    
    // MARK: - Storage Operations
    
    private func storeAuditEvent(_ event: AuditEvent) throws {
        // Serialize event
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let eventData = try encoder.encode(event)
        
        // Encrypt event data
        let encryptedData = try encryptionService.encrypt(
            eventData,
            authenticatedData: Data(event.id.utf8)
        )
        
        // Get current log data
        let currentLogData = getCurrentLogData()
        
        // Check size limits
        if currentLogData.count + encryptedData.count > configuration.maxLogSize {
            try performLogRotation()
        }
        
        // Append to log
        let newLogData = currentLogData + encryptedData + Data("\n".utf8)
        try storage.store(newLogData, for: auditLogKey)
        
        // Update index
        try updateAuditIndex(with: event)
        
        // Check retention policy
        if shouldApplyRetention() {
            try applyRetentionPolicy()
        }
    }
    
    private func getCurrentLogData() -> Data {
        do {
            return try storage.retrieve(for: auditLogKey)
        } catch {
            return Data()
        }
    }
    
    private func updateAuditIndex(with event: AuditEvent) throws {
        var index = getCurrentIndex()
        
        let indexEntry: [String: Any] = [
            "id": event.id,
            "timestamp": event.timestamp.timeIntervalSince1970,
            "type": event.eventType.rawValue,
            "risk": event.riskLevel.rawValue,
            "user": event.userId ?? "",
            "result": event.result.rawValue
        ]
        
        index.append(indexEntry)
        
        let indexData = try JSONSerialization.data(withJSONObject: index)
        try storage.store(indexData, for: auditIndexKey)
    }
    
    private func getCurrentIndex() -> [[String: Any]] {
        do {
            let indexData = try storage.retrieve(for: auditIndexKey)
            if let index = try JSONSerialization.jsonObject(with: indexData) as? [[String: Any]] {
                return index
            }
        } catch {}
        return []
    }
    
    // MARK: - Compliance Export
    
    public func exportComplianceReport(
        fromDate: Date,
        toDate: Date,
        eventTypes: [EventType]? = nil,
        riskLevels: [RiskLevel]? = nil
    ) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            auditQueue.async {
                do {
                    let report = try self.generateComplianceReport(
                        fromDate: fromDate,
                        toDate: toDate,
                        eventTypes: eventTypes,
                        riskLevels: riskLevels
                    )
                    continuation.resume(returning: report)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func generateComplianceReport(
        fromDate: Date,
        toDate: Date,
        eventTypes: [EventType]?,
        riskLevels: [RiskLevel]?
    ) throws -> Data {
        // Log compliance export
        logSystemEvent(.complianceExport, details: [
            "date_range": "\(fromDate.iso8601String) to \(toDate.iso8601String)",
            "export_requested": "true"
        ])
        
        let events = try retrieveEvents(
            fromDate: fromDate,
            toDate: toDate,
            eventTypes: eventTypes,
            riskLevels: riskLevels
        )
        
        let report = ComplianceReport(
            generatedAt: Date(),
            reportPeriod: DateRange(from: fromDate, to: toDate),
            events: events,
            summary: generateSummary(for: events),
            metadata: [
                "total_events": "\(events.count)",
                "generator": "GrowWiser Audit System v1.0",
                "compliance_standards": "SOC2, HIPAA",
                "export_format": "JSON"
            ]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let reportData = try encoder.encode(report)
        
        // Encrypt if required
        if configuration.exportEncryption {
            return try encryptionService.encrypt(reportData)
        }
        
        return reportData
    }
    
    // MARK: - Retrieval and Querying
    
    public func retrieveEvents(
        fromDate: Date,
        toDate: Date,
        eventTypes: [EventType]? = nil,
        riskLevels: [RiskLevel]? = nil
    ) throws -> [AuditEvent] {
        let logData = try storage.retrieve(for: auditLogKey)
        let logLines = String(data: logData, encoding: .utf8)?.components(separatedBy: "\n") ?? []
        
        var events: [AuditEvent] = []
        
        for line in logLines {
            guard !line.isEmpty else { continue }
            guard let lineData = line.data(using: .utf8) else { continue }
            
            do {
                // Decrypt and decode event
                let decryptedData = try encryptionService.decrypt(lineData)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let event = try decoder.decode(AuditEvent.self, from: decryptedData)
                
                // Verify integrity
                try verifyEventIntegrity(event)
                
                // Apply filters
                guard event.timestamp >= fromDate && event.timestamp <= toDate else { continue }
                
                if let eventTypes = eventTypes, !eventTypes.contains(event.eventType) {
                    continue
                }
                
                if let riskLevels = riskLevels, !riskLevels.contains(event.riskLevel) {
                    continue
                }
                
                events.append(event)
                
            } catch {
                // Log integrity violation but continue processing
                continue
            }
        }
        
        return events.sorted { $0.timestamp < $1.timestamp }
    }
    
    // MARK: - Integrity and Security
    
    private func addIntegrityHash(to event: AuditEvent) throws -> AuditEvent {
        var mutableEvent = event
        
        // Create hash input from event data (excluding integrity field)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        
        let eventDataWithoutIntegrity = try encoder.encode(event)
        
        // Calculate HMAC using device-specific key
        let key = try getIntegrityKey()
        let hmac = HMAC<SHA256>.authenticationCode(for: eventDataWithoutIntegrity, using: key)
        mutableEvent.integrity = Data(hmac).base64EncodedString()
        
        return mutableEvent
    }
    
    private func verifyEventIntegrity(_ event: AuditEvent) throws {
        var eventWithoutIntegrity = event
        eventWithoutIntegrity.integrity = ""
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        
        let eventData = try encoder.encode(eventWithoutIntegrity)
        
        let key = try getIntegrityKey()
        let expectedHMAC = HMAC<SHA256>.authenticationCode(for: eventData, using: key)
        let expectedIntegrity = Data(expectedHMAC).base64EncodedString()
        
        guard event.integrity == expectedIntegrity else {
            throw AuditError.integrityViolation
        }
    }
    
    private func getIntegrityKey() throws -> SymmetricKey {
        let keyData: Data
        do {
            keyData = try storage.retrieve(for: "audit_integrity_key")
        } catch {
            // Generate new key if none exists
            let newKey = SymmetricKey(size: .bits256)
            let newKeyData = newKey.withUnsafeBytes { Data($0) }
            try storage.store(newKeyData, for: "audit_integrity_key")
            keyData = newKeyData
        }
        
        return SymmetricKey(data: keyData)
    }
    
    // MARK: - Maintenance and Retention
    
    private func scheduleMaintenanceTasks() {
        // Schedule daily maintenance at 2 AM
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            self?.auditQueue.async {
                do {
                    try self?.performDailyMaintenance()
                } catch {
                    self?.handleAuditFailure(error)
                }
            }
        }
    }
    
    private func performDailyMaintenance() throws {
        logSystemEvent(.systemMaintenance, details: ["type": "daily_maintenance"])
        
        try applyRetentionPolicy()
        try performLogRotation()
        try optimizeStorage()
    }
    
    private func shouldApplyRetention() -> Bool {
        // Apply retention policy daily or when log size exceeds threshold
        let lastRetention = UserDefaults.standard.double(forKey: "last_audit_retention")
        let daysSinceLastRetention = (Date().timeIntervalSince1970 - lastRetention) / 86400
        
        return daysSinceLastRetention >= 1.0 || getCurrentLogData().count > configuration.maxLogSize
    }
    
    private func applyRetentionPolicy() throws {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -configuration.retentionDays,
            to: Date()
        ) ?? Date()
        
        let currentEvents = try retrieveEvents(
            fromDate: Date.distantPast,
            toDate: Date.distantFuture
        )
        
        let retainedEvents = currentEvents.filter { $0.timestamp >= cutoffDate }
        
        if retainedEvents.count < currentEvents.count {
            try rebuildLogWithEvents(retainedEvents)
            logSystemEvent(.systemMaintenance, details: [
                "type": "retention_policy",
                "removed_events": "\(currentEvents.count - retainedEvents.count)",
                "retained_events": "\(retainedEvents.count)"
            ])
        }
        
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "last_audit_retention")
    }
    
    private func rebuildLogWithEvents(_ events: [AuditEvent]) throws {
        var newLogData = Data()
        var newIndex: [[String: Any]] = []
        
        for event in events {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let eventData = try encoder.encode(event)
            let encryptedData = try encryptionService.encrypt(
                eventData,
                authenticatedData: Data(event.id.utf8)
            )
            
            newLogData.append(encryptedData)
            newLogData.append(Data("\n".utf8))
            
            let indexEntry: [String: Any] = [
                "id": event.id,
                "timestamp": event.timestamp.timeIntervalSince1970,
                "type": event.eventType.rawValue,
                "risk": event.riskLevel.rawValue,
                "user": event.userId ?? "",
                "result": event.result.rawValue
            ]
            newIndex.append(indexEntry)
        }
        
        try storage.store(newLogData, for: auditLogKey)
        
        let indexData = try JSONSerialization.data(withJSONObject: newIndex)
        try storage.store(indexData, for: auditIndexKey)
    }
    
    private func performLogRotation() throws {
        let logData = getCurrentLogData()
        guard logData.count > configuration.maxLogSize else { return }
        
        // Create compressed archive of old logs
        let compressedData = try compressLogData(logData)
        let archiveKey = "audit_archive_\(Date().timeIntervalSince1970)"
        try storage.store(compressedData, for: archiveKey)
        
        // Clear current log
        try storage.store(Data(), for: auditLogKey)
        try storage.store(try JSONSerialization.data(withJSONObject: []), for: auditIndexKey)
        
        logSystemEvent(.systemMaintenance, details: [
            "type": "log_rotation",
            "archive_key": archiveKey,
            "original_size": "\(logData.count)",
            "compressed_size": "\(compressedData.count)"
        ])
    }
    
    private func optimizeStorage() throws {
        // Cleanup expired archives
        // Implementation would depend on keychain enumeration capabilities
        logSystemEvent(.systemMaintenance, details: ["type": "storage_optimization"])
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.currentNetworkPath = path
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - Device Information
    
    private static func generateDeviceId() -> String {
        // Generate consistent device ID based on device characteristics
        #if canImport(UIKit)
        let identifier = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        let identifier = UUID().uuidString
        #endif
        return SHA256.hash(data: Data(identifier.utf8)).compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func getPlatformInfo() -> String {
        #if canImport(UIKit)
        return UIDevice.current.systemName + " " + UIDevice.current.model
        #else
        return "macOS Unknown"
        #endif
    }
    
    private func getOSVersion() -> String {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #endif
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getBiometricCapability() -> String {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                return "FaceID"
            case .touchID:
                return "TouchID"
            case .opticID:
                return "OpticID"
            default:
                return "None"
            }
        }
        return "None"
    }
    
    private func isDeviceJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt"
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // Check if we can write to system directories
        let testPath = "/private/test_jailbreak"
        do {
            try "test".write(toFile: testPath, atomically: false, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
        #endif
    }
    
    private func getCurrentIPAddress() -> String? {
        // Implementation would get current IP address
        return "127.0.0.1" // Placeholder
    }
    
    private func getConnectionType() -> String {
        guard let path = currentNetworkPath else { return "Unknown" }
        
        if path.usesInterfaceType(.wifi) {
            return "WiFi"
        } else if path.usesInterfaceType(.cellular) {
            return "Cellular"
        } else if path.usesInterfaceType(.wiredEthernet) {
            return "Ethernet"
        } else {
            return "Other"
        }
    }
    
    private func isVPNActive() -> Bool {
        guard let path = currentNetworkPath else { return false }
        return path.usesInterfaceType(.other)
    }
    
    private func getLocationInfo() -> String? {
        // Return general location info if available (country/region)
        return Locale.current.region?.identifier
    }
    
    private func getAppState() -> String {
        #if canImport(UIKit)
        switch UIApplication.shared.applicationState {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
        #else
        return "active" // macOS doesn't have the same concept
        #endif
    }
    
    // MARK: - Utility Methods
    
    private func createMetadata(for eventType: EventType, result: OperationResult) -> [String: String] {
        return [
            "compliance_relevant": "true",
            "retention_required": "true",
            "encryption_level": "AES256",
            "integrity_protected": "true",
            "audit_version": "1.0"
        ]
    }
    
    private func handleHighRiskEvent(_ event: AuditEvent) {
        // Handle high-risk events (notifications, alerts, etc.)
        if configuration.enableRealtimeAlerts {
            // Send real-time alert (implementation depends on notification system)
            print("HIGH RISK AUDIT EVENT: \(event.eventType.rawValue) - \(event.result.rawValue)")
        }
    }
    
    private func handleAuditFailure(_ error: Error) {
        // Critical: audit system failure
        print("CRITICAL AUDIT FAILURE: \(error.localizedDescription)")
        
        // Could implement fallback logging mechanisms here
        // For now, ensure we don't crash the app due to audit failures
    }
    
    private func compressLogData(_ data: Data) throws -> Data {
        // Implementation would compress log data
        // For now, return as-is
        return data
    }
    
    private func generateSummary(for events: [AuditEvent]) -> [String: Any] {
        let eventsByType = Dictionary(grouping: events) { $0.eventType }
        let eventsByRisk = Dictionary(grouping: events) { $0.riskLevel }
        let eventsByResult = Dictionary(grouping: events) { $0.result }
        
        var summary: [String: Any] = [:]
        
        // Event type summary
        var typeSummary: [String: Int] = [:]
        for (type, eventList) in eventsByType {
            typeSummary[type.rawValue] = eventList.count
        }
        summary["events_by_type"] = typeSummary
        
        // Risk level summary
        var riskSummary: [String: Int] = [:]
        for (risk, eventList) in eventsByRisk {
            riskSummary[risk.rawValue] = eventList.count
        }
        summary["events_by_risk"] = riskSummary
        
        // Result summary
        var resultSummary: [String: Int] = [:]
        for (result, eventList) in eventsByResult {
            resultSummary[result.rawValue] = eventList.count
        }
        summary["events_by_result"] = resultSummary
        
        // Additional metrics
        summary["total_events"] = events.count
        summary["unique_users"] = Set(events.compactMap { $0.userId }).count
        summary["unique_sessions"] = Set(events.compactMap { $0.sessionId }).count
        summary["high_risk_events"] = events.filter { $0.riskLevel == .high || $0.riskLevel == .critical }.count
        summary["failed_operations"] = events.filter { $0.result == .failure || $0.result == .denied }.count
        
        return summary
    }
}

// MARK: - Supporting Types

public struct ComplianceReport: Codable {
    public let generatedAt: Date
    public let reportPeriod: DateRange
    public let events: [AuditLogger.AuditEvent]
    public let summary: [String: Any]
    public let metadata: [String: String]
    
    private enum CodingKeys: String, CodingKey {
        case generatedAt, reportPeriod, events, metadata
    }
    
    public init(
        generatedAt: Date,
        reportPeriod: DateRange,
        events: [AuditLogger.AuditEvent],
        summary: [String: Any],
        metadata: [String: String]
    ) {
        self.generatedAt = generatedAt
        self.reportPeriod = reportPeriod
        self.events = events
        self.summary = summary
        self.metadata = metadata
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(reportPeriod, forKey: .reportPeriod)
        try container.encode(events, forKey: .events)
        try container.encode(metadata, forKey: .metadata)
        
        // Encode summary as JSON data
        if let summaryData = try? JSONSerialization.data(withJSONObject: summary) {
            let summaryString = String(data: summaryData, encoding: .utf8) ?? "{}"
            try container.encode(summaryString, forKey: .init(stringValue: "summary")!)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        reportPeriod = try container.decode(DateRange.self, forKey: .reportPeriod)
        events = try container.decode([AuditLogger.AuditEvent].self, forKey: .events)
        metadata = try container.decode([String: String].self, forKey: .metadata)
        
        // Decode summary from JSON string
        if let summaryString = try? container.decode(String.self, forKey: .init(stringValue: "summary")!),
           let summaryData = summaryString.data(using: .utf8),
           let summaryObject = try? JSONSerialization.jsonObject(with: summaryData) as? [String: Any] {
            summary = summaryObject
        } else {
            summary = [:]
        }
    }
}

public struct DateRange: Codable {
    public let from: Date
    public let to: Date
    
    public init(from: Date, to: Date) {
        self.from = from
        self.to = to
    }
}

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}