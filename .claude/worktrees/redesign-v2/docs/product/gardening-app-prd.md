# Cultivation — Product Requirements Document

> **Last updated:** 2026-04-02 · **Version:** 2.0 · **Status:** Active development, TestFlight beta

## 1. Executive Summary

Cultivation is an iOS gardening companion app that guides novice gardeners through their journey while providing tools for experienced horticulturists. It features plant tracking, garden management, smart care reminders, a plant journal, diagnostic tools, and community features — all wrapped in a premium "Botanical Field Journal" design language.

**Current state:** TestFlight beta (iOS build 5, v1.0). 647 tests passing. Core features shipped. Preparing for App Store submission.

## 2. Product Vision

**Mission:** Empower gardeners of all skill levels to grow thriving gardens through personalized guidance, timely reminders, and community support.

**Vision:** The indispensable digital companion for every gardener, from first-time plant parents to seasoned horticulturists.

**Brand identity:** "Botanical Field Journal" — serif typography, warm earth tones (stone, sage, coral accents), clean glass-morphism cards, dark-first adaptive UI.

## 3. Target Audience

| Segment | Share | Profile |
|---------|-------|---------|
| **Beginner Gardeners** | 60% | Age 25-45, urban/suburban, seeking step-by-step guidance |
| **Intermediate Gardeners** | 30% | Age 35-55, expanding knowledge, trying new plants/techniques |
| **Advanced Gardeners** | 10% | Age 40+, seeking optimization tools, sharing knowledge |

## 4. Platform & Technology

| Attribute | Value |
|-----------|-------|
| **Primary platform** | iOS 18+ (iPhone primary, iPad optimized) |
| **Secondary** | macOS 14+ (Catalyst/native) |
| **Language** | Swift 6 (strict concurrency) |
| **UI framework** | SwiftUI with `@Observable` (no MVVM) |
| **Data layer** | SwiftData + CloudKit sync |
| **Architecture** | SPM package (`GrowWisePackage/`) + thin app shell |
| **Design system** | `CultivationTheme` — centralized tokens |
| **Analytics** | Amplitude |
| **Error tracking** | Sentry |
| **CI/Testing** | Swift Testing + XCUITest, SSH to mac-mini build node |

## 5. Navigation — 5 Tabs (Current)

```
MainAppView (TabView, coral accent tint)
├── Home        — Care task dashboard (urgency-grouped, weather card, tutorials, seasonal planner)
├── Garden      — Hero header → grouped plant list by bed/area → PlantQuickCard → PlantDetailView
├── Journal     — Timeline of photo journal entries
├── Reminders   — Dedicated reminder list with NavigationStack
└── Profile     — Settings, tutorials (via .sheet), subscriptions
```

> **Note:** Navigation expanded from 4 tabs (ADR-009) to 5 tabs with the addition of a dedicated Reminders tab (#125, #128).

## 6. Core Features — Shipped ✅

### 6.1 Onboarding (7-step wizard)
- Skill assessment quiz
- Location-based hardiness zone setup (GPS → WeatherKit)
- Garden profile: indoor/outdoor, space, sun exposure
- Interest selection (vegetables, herbs, flowers, houseplants)
- Guided first plant selection (#134)
- Auto watering schedule suggestion post-creation (#136)

### 6.2 Plant Care Management
- **Garden Dashboard** — Hero header with selector chips, grouped LazyVStack by bed/area
- **Plant Database** — 50+ curated plants with difficulty ratings, surfaced in navigation (#126)
- **Smart Reminders** — Weather-adjusted watering, fertilizing, pruning alerts
- **Plant Journal** — Photo timeline, notes, observations, problem tracking
- **Companion Planting** — Interactive compatibility matrix
- **Soil & Nutrient Management** — pH tracking, composting tracker (#101)
- **Shopping List** — Auto-generated from garden plans, manual items, navigable from Garden tab (#104, #132, #133)

### 6.3 Home Dashboard
- Care tasks grouped by urgency with inline quick-care buttons (#144) — contextual icons (💧 watering, 🌿 fertilizing, ✂️ pruning)
- Weather card with local conditions (#129)
- Tutorial cards for new users (#130)
- Plant guide quick access (#131)
- Garden health score card (#142)
- Seasonal garden planner with zone-based calendar (#141)
- Community navigation card (#143)

### 6.4 Garden Tab
- Hero header with serif typography and coral FAB
- Grouped plant list by `gardenLocation` string (ADR-011)
- PlantQuickCard bottom sheet → "View Full Details" with 350ms delay push (ADR-014)
- Smart plant suggestions / recommended plants (#135)
- Contextual care tips on plant detail (#139)
- Quick diagnostic with common plant issues (#140)
- Floating add-plant button with spring animation (#145) — Browse Database / Scan / Add Manually
- Bed/area management via free-text `gardenLocation` field

### 6.5 Diagnostic Tools
- Plant health scanner (AI-powered via CoreML, #102)
- Plant disease knowledge base
- Quick diagnostic with common issues (#140)
- Treatment recommendations

### 6.6 Community Features
- Community Q&A forum with CloudKit backend (#105)
- Garden showcase (CloudKit public DB)
- Achievement system (21 achievements)

### 6.7 Advanced Features
- AR garden visualization with plant placement (#103)
- Localization: English, Spanish, French, German (#106)
- Subscription tiers via StoreKit 2

### 6.8 Design System — "Botanical Field Journal"
- `CultivationTheme.swift` — single source of truth for all design tokens
- Dark `#0C0C0C` background, glass-morphism cards (`.glassCard()` modifier)
- Brand palette: stone/sage bed colors, coral accents, serif titles
- Shared components: `GlassPill`, `IconBubble`, `StatusDot`, `GradientButtonStyle`, `QuickStatCard`

## 7. Data Model

10 `@Model` classes (all properties optional for CloudKit compatibility):

| Model | Purpose |
|-------|---------|
| `Plant` | Core entity — name, species, gardenLocation, health, care dates |
| `Garden` | Garden container (name, type, location) |
| `GardenBed` | Bed entity (exists in models, UX uses string grouping per ADR-011) |
| `User` | User profile, preferences, hardiness zone |
| `PlantReminder` | Smart scheduled reminders with weather adjustment |
| `JournalEntry` | Photo journal entries with notes |
| `SoilLog` | pH tracking, nutrient logs |
| `GardeningStats` | Aggregated statistics |
| `CompostBatch` | Composting tracker batches |
| `ShoppingItem` | Shopping list items |

**CloudKit container:** `iCloud.com.growwise.gardening`

## 8. Services (28 total)

| Category | Services |
|----------|----------|
| **Core** | DataService, ReminderService, NotificationService, LocationService |
| **Data & Sync** | CloudSyncService, PlantDatabaseService, CompanionPlantingService, ModelContainerFactory |
| **Intelligence** | PlantDiagnosticService, PlantDiseaseKnowledge, PlantCareAdviceService, GardenHealthService, SeasonalPlannerService |
| **Security** | KeychainService, BiometricService |
| **Observability** | ObservabilityService (Sentry), AnalyticsService (Amplitude) |
| **Support** | TutorialService, PhotoService, ValidationService, SubscriptionService, FeatureFlagService, ShoppingListService, AchievementService, LocalizationService, ForumService, DataTransformationService |
| **Infrastructure** | SwiftDataCache, PlatformImage, TypeAliases |

## 9. Testing

- **Framework:** Swift Testing (`@Test`, `@Suite`, `#expect`) + XCTest coexistence
- **Test files:** 50 across 3 test targets
- **Tests passing:** 647
- **In-memory testing:** `DataService.makeForTesting()` factory (avoids CloudKit entitlement crash)
- **UI tests:** XCUITest with launch args (`--uitesting`, `--skip-onboarding`, `--reset-data`)
- **Execution:** All tests run via SSH to mac-mini (ADR-016)

## 10. Monetization

| Tier | Price | Features |
|------|-------|----------|
| **Free** | $0 | Basic reminders, 50-plant database, community access, 3 AI diagnoses/mo |
| **Premium** | $4.99/mo | Unlimited database, advanced diagnostics, expert consultations (2/mo), weather integration |
| **Pro** | $9.99/mo | Everything + unlimited consultations, commercial features, IoT API, priority support |

## 11. Open Issues

| # | Title | Status |
|---|-------|--------|
| 123 | App Store screenshots and copy | In progress |
| 124 | XCUITest UI tests | Open |
| 137 | 🟡 Seed inventory with packet scanner | v1.1 |
| 138 | 🟡 Garden Club — private group gardening | v1.1 |

## 12. Version History

| Version | Build | Date | Highlights |
|---------|-------|------|------------|
| 1.0 | 5 | Apr 2026 | Full feature set: 45 issues shipped (#101–#145), Botanical Field Journal redesign, 647 tests |
| 0.x | — | Feb–Mar 2026 | Foundation, architecture, security layer, initial features |

## 13. Success Metrics

| Metric | Target |
|--------|--------|
| DAU/MAU | 40% / 50% |
| Tutorial completion | >70% |
| Premium conversion | 15% |
| App Store rating | 4.5+ |
| D1/D7/D30 retention | 80% / 50% / 30% |
| NPS | >50 |

## 14. Roadmap

### v1.0 — App Store Launch (Current)
- ✅ Core features shipped (#101–#145)
- ✅ Botanical Field Journal redesign
- 🔄 App Store screenshots (#123)
- 🔄 UI test coverage (#124)
- ⏳ App Store submission

### v1.1 — Social & Discovery
- 🟡 Seed inventory with packet scanner (#137)
- 🟡 Garden Club — private group gardening (#138)
- Expert video consultations
- Local nursery partnerships

### v2.0 — Intelligence
- Advanced ML diagnostics
- Personalized growing recommendations
- IoT device connectivity
- Historical climate trend analysis
