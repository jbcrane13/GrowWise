# GrowWise - Gap Analysis & Implementation Plan

## 1. Executive Summary
A comprehensive analysis of the GrowWise `gardening-app-prd.md` against the current codebase reveals that the app has a solid foundational architecture (Swift 6 strict concurrency, SwiftData, basic UI views) but lacks the core integrations needed to move beyond a "demo" state into a full MVP and beyond.

## 2. Gap Analysis (PRD vs Current Codebase)

### 🟢 Completed / Foundation In Place
- **Onboarding:** Excellent UI flow with Skill Assessment, Goals, and Location.
- **Data Persistence:** SwiftData models are well-architected and prepped for CloudKit (`CloudKitSchema.swift` exists, fields are optional).
- **Security:** Extensive Keychain, AES-256-GCM, and Secure Enclave work is completed.
- **Basic UI Shell:** NavigationStack, TabBars (Home, My Garden, Plant Guide, Journal, Learn).
- **Reminders Architecture:** Data models and basic UI exist for plant reminders.

### 🟡 Partially Implemented (Needs Connection)
- **WeatherKit Integration:** `LocationService.swift` has WeatherKit imports and methods (`fetchWeatherData`), but `HomeView` currently hardcodes `WeatherInfo.sample`.
- **Plant Database:** `PlantDatabaseService` exists with static fallback data, but no real comprehensive botanical dataset or backend exists.
- **Photo Service:** Disk writing exists, but lacks advanced compression, syncing, or AR/ML hooks.
- **CloudKit Sync:** Models are prepped, but the actual remote sync logic is dormant/unconnected.

### 🔴 Missing Entirely (Major PRD Requirements)
- **AI Diagnostics (Core ML):** "Plant Health Scanner", pest recognition, disease identification. No `import CoreML` or `Vision` anywhere in the app.
- **AR Visualization (ARKit):** Garden layout designer mentioned in PRD is completely missing.
- **Community Features:** Garden showcase, seed exchange, forums, Q&A.
- **Marketplace / Shopping:** Nursery integration, shopping lists.
- **Companion Planting Matrix:** No logic exists for evaluating plant compatibility.
- **Soil & Nutrient Management:** Missing trackers for pH and composting.

---

## 3. Phased Implementation Plan

Based on the PRD's own Development Phases, here is the technical roadmap to bring the codebase up to full spec.

### Phase 1: Connect the MVP (Months 1-2)
*Goal: Turn the static shell into a dynamic, personalized app.*
1. **WeatherKit Wire-up:** Replace `WeatherInfo.sample` in `HomeView` with real data from `LocationService`.
2. **CloudKit Activation:** Implement real `CKSyncEngine` logic to bind SwiftData to the user's private iCloud database.
3. **Push Notifications:** Connect the `ReminderService` to `UNUserNotificationCenter` to fire real local notifications for watering/pruning.
4. **Plant Database Expansion:** Seed a real SQLite or JSON dataset of at least 50 beginner plants into the app bundle.

### Phase 2: Intelligence & Diagnostics (Months 3-4)
*Goal: Fulfill the "Diagnostic Tools" PRD section.*
1. **Core ML Integration:** Create a `PlantDiagnosticService` using Apple's Vision framework and a pre-trained MLModel to classify common plant diseases from photos.
2. **Health Scanner UI:** Add a new "Scan" tab or button in My Garden that opens the camera and processes frames through the diagnostic service.
3. **Smart Reminders:** Alter reminder generation to read the 10-day WeatherKit forecast (e.g., delay watering if rain is >0.5 inches).

### Phase 3: Advanced Gardening Tools (Months 4-5)
*Goal: Build out the "Advanced Features" PRD section.*
1. **Companion Planting Engine:** Create a graph or dictionary mapping compatible/incompatible plants, and show warnings in the `AddPlantSheet`.
2. **Soil Management View:** Add a dedicated UI in `MyGardenPlantDetailView` to log pH, N-P-K levels, and fertilizer history.
3. **Hardiness Zone Mapping:** Fully implement the coordinate-to-zone calculation in `LocationService` (currently mocked).

### Phase 4: Community & Premium Features (Months 6+)
*Goal: Implement monetization and social features.*
1. **Public CloudKit Database:** Use CloudKit Public Database for the "Garden Showcase" and forum features.
2. **StoreKit Integration:** Add freemium paywalls for advanced features (unlimited scans, expert consultations).

## 4. Beads Tracking Setup

I will create a master Epic and subtasks in Beads to track Phase 1 (Connecting the MVP) and Phase 2 (Intelligence).
