# 🌱 Cultivation

**Your personal garden companion — track plants, log care, and grow with confidence.**

Cultivation is a native iOS app for gardeners of all skill levels. Whether you're keeping a single succulent alive or managing a full backyard garden, Cultivation keeps your plants organized, your care schedule on track, and your knowledge growing.

---

## Features

### 🌿 My Garden
Track every plant in your collection with photos, care notes, and health status. Add plants from a curated database or create your own. See everything at a glance on your garden dashboard.

### 🔔 Smart Reminders
Never miss a watering, fertilizing, or pruning again. Reminders are tailored to each plant's needs, with weather-aware adjustments that adapt to your local conditions.

### 📓 Plant Journal
Log observations, milestones, and photos over time. Track soil conditions, spot problems early, and build a detailed history for every plant.

### 🌍 Location-Aware
Set up your garden profile with your location and Cultivation automatically factors in your hardiness zone, climate, and seasonal patterns for smarter care recommendations.

### 📚 Learning Center
Step-by-step tutorials for beginners, companion planting guides, and a searchable plant database — everything you need to level up your gardening knowledge.

### 🌱 Onboarding
A short skill assessment gets you personalized recommendations from day one. Beginner or expert, the experience adapts to you.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 6 |
| UI | SwiftUI |
| Data | SwiftData |
| Architecture | Workspace + SPM package |
| Min iOS | 18.0 |
| Concurrency | Swift 6 strict concurrency |

### Package Structure

```
Cultivation/
├── GrowWise/                          # App shell (entry point, lifecycle)
│   └── CultivationApp.swift
├── GrowWisePackage/                   # Primary development area
│   ├── Sources/
│   │   ├── GrowWiseFeature/           # All UI and feature code
│   │   ├── GrowWiseServices/          # Business logic and services
│   │   └── GrowWiseModels/            # SwiftData models
│   └── Tests/                         # Unit + integration tests (72 passing)
└── GrowWiseUITests/                   # UI automation tests
```

### Key Services

- **DataService** — SwiftData persistence, async-safe
- **ReminderService** — Notification scheduling with weather adjustment
- **LocationService** — Hardiness zone + climate lookup
- **PlantDatabaseService** — Searchable plant catalog
- **CloudSyncService** — CloudKit sync (in progress)
- **NotificationService** — Local notifications

---

## Development

### Requirements
- Xcode 16+
- iOS 18.0+ simulator or device
- Swift 6

### Getting Started

```bash
git clone <repo>
cd GrowWise
open GrowWise.xcworkspace
```

Build and run the `GrowWise` scheme. The app uses in-memory SwiftData during UI tests — no migration needed for simulator runs.

### Running Tests

```bash
# Unit tests
xcodebuild test -workspace GrowWise.xcworkspace -scheme GrowWisePackage \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# UI tests
xcodebuild test -workspace GrowWise.xcworkspace -scheme GrowWise \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Launch Arguments (UI Testing)

| Argument | Effect |
|----------|--------|
| `--uitesting` | Enables in-memory store, disables animations |
| `--skip-onboarding` | Skips onboarding flow |
| `--reset-data` | Clears UserDefaults (run before `--skip-onboarding`) |
| `--reset-onboarding` | Forces onboarding to show |

---

## Status

- ✅ Core garden tracking (My Garden, plant detail, reminders)
- ✅ Plant journal with soil logs
- ✅ Onboarding flow with skill assessment
- ✅ Location setup + hardiness zone
- ✅ Tutorial system
- ✅ 72 unit tests passing
- 🔄 CloudKit sync (in progress)
- 🔄 App Store submission

---

## License

MIT
