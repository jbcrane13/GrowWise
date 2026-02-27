# GrowWise Release-Quality Plan

**Goal**: Ship MVP (Section 8 PRD) + essential production hardening in minimum time.

---

## Phase 0: Foundation Fixes (Week 1)

### 0.1 Critical Bug - My Garden Refresh
- **Issue**: `growwise-dbq` - My Garden doesn't refresh after creating garden/plant
- **Fix**: Complete the `.onChange` handlers or add proper data reload

### 0.2 Profile Tab Missing
- **Issue**: PRD expects 7 tabs, currently 6 (missing Profile)
- **Issue ID**: `growwise-ga0`
- **MVP Scope**: Add Profile tab with placeholder UI (subscription stub)

### 0.3 WeatherKit Real Data
- **Current**: Hardcoded `WeatherInfo.sample` in `HomeView`
- **Fix**: Wire up `LocationService.fetchWeatherData()` to actual WeatherKit

---

## Phase 1: MVP Core (Week 2-3)

### 1.1 Push Notifications Wiring
- **Status**: `NotificationService` exists, not connected to `ReminderService`
- **Task**: Connect reminder scheduling → local notifications fire

### 1.2 Plant Database Seed (25 plants)
- **Status**: `PlantDatabaseService` exists with minimal data
- **Task**: Seed comprehensive JSON with 25 beginner-friendly plants
- **Fields**: name, difficulty, sunNeeds, waterFrequency, careNotes, imageURL

### 1.3 CloudKit Sync Activation
- **Status**: Models ready, `CloudSyncService` exists
- **Task**: Implement actual sync logic (private database)

### 1.4 Tutorial Content Expansion
- **Status**: 5 basic tutorials exist
- **Task**: Verify all 5 PRD topics covered + progress tracking

---

## Phase 2: Production Hardening (Week 4)

### 2.1 Test Coverage Sprint

| Priority | Area | Target |
|----------|------|--------|
| 🔴 Critical | LocationService | 80% |
| 🔴 Critical | PhotoService | 80% |
| 🔴 Critical | ReminderService | 80% |
| 🟡 High | DataService integration | 70% |

### 2.2 Accessibility Audit
- VoiceOver labels on all interactive elements
- Dynamic Type support
- High contrast mode

### 2.3 Performance Validation
- App launch < 2 seconds
- Memory < 50MB baseline
- SwiftData queries < 100ms

---

## Phase 3: Polish (Week 5)

### 3.1 Companion Planting Fix
- **Issue ID**: `growwise-zh3`
- **Task**: Add companion warnings to `AddPlantToGardenSheet`

### 3.2 Profile Tab - Subscription UI
- **Issue ID**: `growwise-ga0`
- **Task**: Implement paywall UI (StoreKit stub, restore purchases)

### 3.3 Error Handling Polish
- Network failure states
- Offline mode graceful degradation
- User-friendly error messages

---

## Phase 4: Pre-Release (Week 6)

### 4.1 Beta Testing Setup
- TestFlight configuration
- Crash reporting (existing PerformanceMonitor)

### 4.2 App Store Assets
- Screenshots
- App description
- Keywords

### 4.3 Final Regression
- Full UI test pass
- All 3 open bugs fixed
- All MVP features verified

---

## Backlog (Post-MVP)

| Feature | PRD Section | Priority |
|---------|-------------|----------|
| AI Plant Diagnostics | 4.5 | Phase 2 |
| AR Garden Visualization | 4.2 | Phase 3 |
| Community Features | 4.6 | Phase 4+ |
| Marketplace | 4.7 | Phase 4+ |
| Weather-Based Smart Reminders | 4.3 | Phase 2 |
| Hardiness Zone Mapping | 4.4 | Phase 2 |

---

## Beads Issues to Create

```
Phase 0:
- bug: My Garden refresh fix
- feat: Add Profile tab with stub UI
- feat: Wire WeatherKit real data

Phase 1:
- feat: Connect push notifications
- feat: Seed 25 plant database
- feat: Activate CloudKit sync
- feat: Expand tutorial content

Phase 2:
- test: LocationService coverage sprint
- test: PhotoService coverage sprint
- test: ReminderService coverage sprint
- perf: Validate launch < 2s

Phase 3:
- feat: Companion planting My Garden fix
- feat: Subscription paywall UI

Phase 4:
- ops: TestFlight setup
- ops: App Store assets
- test: Full regression pass
```

---

## Dependencies

```
Phase 0 ──────► Phase 1 ──────► Phase 2 ──────► Phase 3 ──────► Phase 4
   │               │               │               │               │
   ▼               ▼               ▼               ▼               ▼
Foundation    MVP Core       Testing        Polish         Release
```

---

## Success Criteria

- [ ] App launches < 2s
- [ ] All 6 tabs functional + Profile stub
- [ ] 25+ plant database populated
- [ ] Reminders fire as local notifications
- [ ] Onboarding complete flow works
- [ ] Journal with photos functional
- [ ] 5 tutorials accessible
- [ ] Test coverage > 60%
- [ ] No critical bugs (crashes, data loss)
- [ ] Accessibility: VoiceOver + Dynamic Type
