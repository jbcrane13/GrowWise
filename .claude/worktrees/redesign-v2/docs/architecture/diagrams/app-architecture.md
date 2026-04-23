# GrowWise Application Architecture

## Package Structure

```mermaid
graph TD
    subgraph AppShell["GrowWise (App Shell)"]
        Entry[GrowWiseApp / MainAppView]
        Assets[Assets & Info.plist]
        CloudKit[CloudKit Schema]
    end

    subgraph Package["GrowWisePackage (Swift Package)"]
        subgraph Feature["GrowWiseFeature (SwiftUI Views)"]
            Views[Views/]
            Components[Components/]
        end

        subgraph Services["GrowWiseServices (Business Logic)"]
            DataSvc[DataService]
            AuthSvc[BiometricAuthenticationManager]
            SecuritySvc[KeychainManager / EncryptionService]
            CloudSvc[CloudSyncService]
            NotifSvc[NotificationService]
            PlantSvc[PlantDatabaseService]
            CompSvc[CompanionPlantingService]
        end

        subgraph Models["GrowWiseModels (Data Layer)"]
            SwiftData[@Model Classes]
            Enums[Enums & Value Types]
        end
    end

    Entry --> Feature
    Entry --> Services
    Feature -->|"@Environment(Service.self)"| Services
    Services --> Models
    AppShell --> Package
```

## Data Flow (MV Architecture)

```mermaid
sequenceDiagram
    participant User
    participant View as SwiftUI View
    participant Service as @Observable Service
    participant SwiftData as SwiftData Store
    participant CloudKit as CloudKit

    User->>View: Interaction
    View->>Service: Call async method
    Service->>SwiftData: Read / Write @Model
    SwiftData-->>Service: Result
    Service-->>View: Updated @Observable state
    View-->>User: Re-render

    SwiftData--)CloudKit: Background sync (CKSyncEngine)
    CloudKit--)SwiftData: Remote changes
```

## Security Architecture

```mermaid
graph LR
    subgraph Auth["Authentication Layer"]
        Bio[BiometricAuthManager\nFace ID / Touch ID]
        JWT[JWTValidator]
        Rate[RateLimiter]
    end

    subgraph Storage["Secure Storage"]
        Keychain[KeychainManager\nOS Keychain]
        SE[SecureEnclaveKeyManager\nSecure Enclave]
        KRS[KeychainStorageService]
    end

    subgraph Crypto["Cryptography"]
        Enc[EncryptionService\nAES-256-GCM]
        KeyRot[KeyRotationManager]
        Migrate[LegacyEncryptionMigrationService]
    end

    subgraph Audit["Audit & Monitoring"]
        AuditLog[AuditLogger]
        PerfMon[PerformanceMonitor]
        TokenMgr[TokenManagementService]
    end

    Bio --> JWT
    JWT --> Rate
    Rate --> KRS
    KRS --> Keychain
    KRS --> SE
    SE --> Enc
    Enc --> KeyRot
    KeyRot --> Migrate
    Auth --> AuditLog
    Storage --> AuditLog
    Crypto --> AuditLog
```

## CloudKit Sync Flow

```mermaid
sequenceDiagram
    participant App as GrowWise App
    participant CSS as CloudSyncService
    participant SD as SwiftData
    participant CK as CloudKit (iCloud)

    App->>CSS: Initialize sync
    CSS->>SD: Configure ModelContainer\n(CloudKit enabled)
    SD->>CK: CKSyncEngine handshake

    loop Continuous Sync
        SD->>CK: Push local changes
        CK->>SD: Pull remote changes
        CSS->>CSS: Conflict resolution\n(simple increment strategy)
    end

    Note over SD,CK: All @Model properties must be\nOptional for CloudKit compatibility
```

## Service Dependencies

```mermaid
graph TD
    DataSvc[DataService] --> SwiftData[(SwiftData Store)]
    DataSvc --> KeySvc[KeychainStorageService]
    DataSvc --> EncSvc[EncryptionService]
    DataSvc --> AuditLog[AuditLogger]

    CloudSvc[CloudSyncService] --> DataSvc
    CloudSvc --> ModelContainer[(ModelContainer)]

    AuthSvc[BiometricAuthenticationManager] --> TokenMgr[TokenManagementService]
    AuthSvc --> KeySvc
    AuthSvc --> Rate[RateLimiter]
    AuthSvc --> AuditLog

    EncSvc --> SE[SecureEnclaveKeyManager]
    EncSvc --> KeyRot[KeyRotationManager]

    PlantSvc[PlantDatabaseService] --> DataSvc
    CompSvc[CompanionPlantingService] --> CompData[(CompanionPlantingData.json)]
    RemSvc[ReminderService] --> DataSvc
    RemSvc --> NotifSvc[NotificationService]
```
