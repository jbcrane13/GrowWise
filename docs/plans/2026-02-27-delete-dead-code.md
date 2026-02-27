# Delete Dead Code Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Delete approximately 2,400 lines of orphaned and dead code identified by the Sisyphus-Junior background scan, cleaning up unused Views, Services, and Types.

**Architecture:** We are actively removing code that is not referenced, reducing the maintenance surface area.

**Tech Stack:** Swift

---

### Task 1: Delete Dead Views and Models

**Files:**
- Delete: `GrowWisePackage/Sources/GrowWiseFeature/TestAppView.swift`
- Delete: `GrowWisePackage/Sources/GrowWiseFeature/ContentView.swift`
- Delete: `GrowWisePackage/Sources/GrowWiseFeature/Views/SoilManagementView.swift`
- Delete: `GrowWisePackage/Sources/GrowWiseFeature/Views/NotificationSettingsView.swift`
- Delete: `GrowWisePackage/Sources/GrowWiseFeature/Views/TutorialData.swift`
- Delete: `GrowWisePackage/Sources/GrowWiseFeature/Views/Tutorials/TutorialDetailView.swift`

**Step 1: Delete the files**

Run: 
```bash
rm GrowWisePackage/Sources/GrowWiseFeature/TestAppView.swift
rm GrowWisePackage/Sources/GrowWiseFeature/ContentView.swift
rm GrowWisePackage/Sources/GrowWiseFeature/Views/SoilManagementView.swift
rm GrowWisePackage/Sources/GrowWiseFeature/Views/NotificationSettingsView.swift
rm GrowWisePackage/Sources/GrowWiseFeature/Views/TutorialData.swift
rm GrowWisePackage/Sources/GrowWiseFeature/Views/Tutorials/TutorialDetailView.swift
```

**Step 2: Run Tests to Verify**

Run: `cd GrowWisePackage && swift test`

**Step 3: Commit**

```bash
git add GrowWisePackage/
git commit -m "chore: remove dead UI views and unused models"
```

### Task 2: Remove SystemColorToken and PlatformCompatibility

**Files:**
- Delete: `GrowWisePackage/Sources/GrowWiseFeature/PlatformCompatibility.swift`

**Step 1: Delete the file**

Run: `rm GrowWisePackage/Sources/GrowWiseFeature/PlatformCompatibility.swift`

**Step 2: Run Tests to Verify**

Run: `cd GrowWisePackage && swift test`

**Step 3: Commit**

```bash
git add GrowWisePackage/
git commit -m "chore: remove unused PlatformCompatibility layer"
```

### Task 3: Remove BackgroundTaskManager

**Files:**
- Delete: `GrowWisePackage/Sources/GrowWiseServices/BackgroundTaskManager.swift`
- Delete tests: `GrowWisePackage/Tests/GrowWiseServicesTests/BackgroundTaskManagerTests.swift` (if exists)

**Step 1: Find and delete files**

Run: 
```bash
rm GrowWisePackage/Sources/GrowWiseServices/BackgroundTaskManager.swift
find GrowWisePackage/Tests -name "*BackgroundTaskManager*" -delete
```

**Step 2: Run Tests to Verify**

Run: `cd GrowWisePackage && swift test`

**Step 3: Commit**

```bash
git add GrowWisePackage/
git commit -m "chore: remove unused BackgroundTaskManager service"
```

### Task 4: Remove CacheManager

**Files:**
- Delete: `GrowWisePackage/Sources/GrowWiseServices/CacheManager.swift`
- Delete tests: `GrowWisePackage/Tests/GrowWiseServicesTests/CacheManagerTests.swift` (if exists)

**Step 1: Delete the file**

Wait, `PlatformImage.swift` is used by `PlantDiagnosticService`, so we CANNOT delete it (as my `rg` command just discovered). We will only delete `CacheManager`.

Run: 
```bash
rm GrowWisePackage/Sources/GrowWiseServices/CacheManager.swift
find GrowWisePackage/Tests -name "*CacheManager*" -delete
```

**Step 2: Run Tests to Verify**

Run: `cd GrowWisePackage && swift test`

**Step 3: Commit**

```bash
git add GrowWisePackage/
git commit -m "chore: remove unused CacheManager"
```

