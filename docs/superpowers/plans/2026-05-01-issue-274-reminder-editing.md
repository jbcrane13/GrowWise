# Issue #274 — Full Reminder Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `EditReminderView` placeholder with a working form that lets users edit a reminder's schedule, content, and enabled state, persisted via a new `ReminderService.updateReminder(...)` entry point.

**Architecture:** New `EditReminderView.swift` mirroring `AddReminderView.swift`'s structure. A nested `EditReminderView.FormState` value type owns the reminder → form-state mapping so it can be unit-tested without rendering SwiftUI. A new `ReminderService.updateReminder(...)` method centralizes mutation, `nextDueDate` recalculation, and notification rescheduling. PlantReminderDetailView's existing `.sheet(item: $selectedReminder)` plumbing is unchanged — only the placeholder struct definition is removed.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing (`@Suite`/`@Test`/`#expect`), `@Observable`, `@MainActor`. NotificationService uses `notificationCenter: nil` in tests (no real notification calls).

**Working branch:** `feat/issue-274-reminder-editing` (already created with the design spec committed at `e03b71e`).

**Spec:** [`docs/superpowers/specs/2026-05-01-issue-274-reminder-editing-design.md`](../specs/2026-05-01-issue-274-reminder-editing-design.md)

---

## File inventory

**Will create:**
- `GrowWisePackage/Sources/GrowWiseFeature/Views/EditReminderView.swift` (~350 lines)
- `GrowWisePackage/Tests/GrowWiseServicesTests/ReminderServiceUpdateTests.swift` (~280 lines)
- `GrowWisePackage/Tests/GrowWiseFeatureTests/EditReminderViewTests.swift` (~80 lines)

**Will modify:**
- `GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift` — add `ReminderError.emptyTitle` + `.invalidCustomFrequency` cases (~6 lines), add `updateReminder(...)` method (~60 lines)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/PlantReminderDetailView.swift` — delete placeholder struct at lines 680–708 (-29 lines)

**Conventions to follow:**
- New tests use Swift Testing (`@Suite`, `@Test`, `#expect`, `#require`) — never `XCTAssert*`. Test method names must NOT start with `test` (a SwiftFormat hook strips that prefix).
- Test setup uses `DataService.makeForTesting()` and `NotificationService(notificationCenter: nil)`. Look at `GrowWisePackage/Tests/GrowWiseServicesTests/ReminderServiceIntegrationTests.swift:33-63` for the established `makeReminderService(...)` helper pattern.
- Every interactive control needs an `.accessibilityIdentifier("editreminder_<kind>_<descriptor>")` — keep the placeholder's existing identifiers `plantreminder_button_edit_cancel` and `plantreminder_button_edit_save` on the corresponding controls so any future UI tests don't break (audit confirmed no UI tests reference them today, but they're stable contracts).
- Run `swift test --package-path GrowWisePackage` locally — do **not** SSH to mac-mini for unit tests. Only UI tests / `xcodebuild test` need mac-mini.
- Pre-commit hooks run SwiftFormat + SwiftLint. They may reformat your changes. Re-stage and re-commit if that happens.

---

## Task 1: Add `ReminderError` cases and stub `updateReminder`

Bootstrap so subsequent tasks have something to compile against. The stub is intentionally a no-op that satisfies the signature; behavior is filled in by Tasks 2–6.

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift`
- Create: `GrowWisePackage/Tests/GrowWiseServicesTests/ReminderServiceUpdateTests.swift`

- [ ] **Step 1: Add the two new error cases**

In `ReminderService.swift`, find the `ReminderError` enum (around line 1017). Add two cases and their localized descriptions:

```swift
public enum ReminderError: Error, LocalizedError {
    case invalidReminderType
    case plantNotFound
    case notificationPermissionDenied
    case invalidFrequency
    case invalidTime
    case emptyTitle
    case invalidCustomFrequency

    public var errorDescription: String? {
        switch self {
        case .invalidReminderType:
            "Invalid reminder type specified"

        case .plantNotFound:
            "Plant not found for reminder"

        case .notificationPermissionDenied:
            "Notification permission denied"

        case .invalidFrequency:
            "Invalid reminder frequency"

        case .invalidTime:
            "Invalid notification time"

        case .emptyTitle:
            "Reminder title cannot be empty"

        case .invalidCustomFrequency:
            "Custom frequency requires at least 1 day"
        }
    }
}
```

- [ ] **Step 2: Add the `updateReminder` stub adjacent to `updateWateringSchedule`**

Find `updateWateringSchedule(...)` in `ReminderService.swift` (around line 136). Immediately after its closing brace, add:

```swift
    public func updateReminder(
        _ reminder: PlantReminder,
        title: String,
        message: String,
        type: ReminderType,
        frequency: ReminderFrequency,
        customFrequencyDays: Int?,
        preferredTime: Date?,
        priority: ReminderPriority,
        enableWeatherAdjustment: Bool,
        isEnabled: Bool
    ) async throws {
        // Implementation in subsequent tasks.
    }
```

- [ ] **Step 3: Create the test file with one smoke test**

Create `GrowWisePackage/Tests/GrowWiseServicesTests/ReminderServiceUpdateTests.swift`:

```swift
import Testing
import Foundation
import SwiftData
import CoreLocation
@testable import GrowWiseServices
@testable import GrowWiseModels

@Suite("ReminderService.updateReminder")
@MainActor
struct ReminderServiceUpdateTests {
    // MARK: - Helpers

    private func makeService() throws -> (ReminderService, DataService, Plant, PlantReminder) {
        let dataService = try DataService.makeForTesting()
        let notificationService = NotificationService(notificationCenter: nil)
        let service = ReminderService(
            dataService: dataService,
            notificationService: notificationService,
            shouldScheduleNotifications: false
        )
        let plant = try dataService.createPlant(name: "Basil-\(UUID())", type: .herb)
        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: ReminderFrequency.weekly.days,
            enableWeatherAdjustment: false,
            priority: .medium,
            preferredTime: Date()
        )
        return (service, dataService, plant, reminder)
    }

    // MARK: - Smoke

    @Test("updateReminder stub completes without throwing")
    func stubCompletes() async throws {
        let (service, _, _, reminder) = try await makeService()
        try await service.updateReminder(
            reminder,
            title: reminder.title,
            message: reminder.message,
            type: reminder.reminderType,
            frequency: reminder.frequency,
            customFrequencyDays: reminder.customFrequencyDays,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: reminder.isEnabled
        )
    }
}
```

> **Note:** `makeService()` is async only because `createSmartReminder` is async; the helper itself doesn't `await` outside that call. The use of `try await` inside an async helper is fine.

- [ ] **Step 4: Run the smoke test, expect pass**

Run: `swift test --package-path GrowWisePackage --filter ReminderServiceUpdateTests 2>&1 | tail -10`

Expected: 1 test, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift \
        GrowWisePackage/Tests/GrowWiseServicesTests/ReminderServiceUpdateTests.swift
git commit -m "$(cat <<'EOF'
feat(#274): add ReminderError cases and updateReminder stub

Adds .emptyTitle and .invalidCustomFrequency error cases plus a stub
ReminderService.updateReminder(...) method. Behavior is filled in by
subsequent commits; this commit just establishes the surface area so
TDD can proceed against it.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Validation — empty title and invalid custom days

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift`
- Modify: `GrowWisePackage/Tests/GrowWiseServicesTests/ReminderServiceUpdateTests.swift`

- [ ] **Step 1: Add the failing tests**

Append to the suite in `ReminderServiceUpdateTests.swift`:

```swift
    // MARK: - Validation

    @Test("updateReminder rejects empty title")
    func rejectsEmptyTitle() async throws {
        let (service, _, _, reminder) = try await makeService()
        await #expect(throws: ReminderError.self) {
            try await service.updateReminder(
                reminder,
                title: "",
                message: reminder.message,
                type: reminder.reminderType,
                frequency: reminder.frequency,
                customFrequencyDays: reminder.customFrequencyDays,
                preferredTime: reminder.preferredNotificationTime,
                priority: reminder.priority,
                enableWeatherAdjustment: reminder.enableWeatherAdjustment,
                isEnabled: reminder.isEnabled
            )
        }
    }

    @Test("updateReminder rejects whitespace-only title")
    func rejectsWhitespaceTitle() async throws {
        let (service, _, _, reminder) = try await makeService()
        await #expect(throws: ReminderError.self) {
            try await service.updateReminder(
                reminder,
                title: "   \n  ",
                message: reminder.message,
                type: reminder.reminderType,
                frequency: reminder.frequency,
                customFrequencyDays: reminder.customFrequencyDays,
                preferredTime: reminder.preferredNotificationTime,
                priority: reminder.priority,
                enableWeatherAdjustment: reminder.enableWeatherAdjustment,
                isEnabled: reminder.isEnabled
            )
        }
    }

    @Test("updateReminder rejects custom frequency without days")
    func rejectsCustomFrequencyWithoutDays() async throws {
        let (service, _, _, reminder) = try await makeService()
        await #expect(throws: ReminderError.self) {
            try await service.updateReminder(
                reminder,
                title: reminder.title,
                message: reminder.message,
                type: reminder.reminderType,
                frequency: .custom,
                customFrequencyDays: nil,
                preferredTime: reminder.preferredNotificationTime,
                priority: reminder.priority,
                enableWeatherAdjustment: reminder.enableWeatherAdjustment,
                isEnabled: reminder.isEnabled
            )
        }
    }

    @Test("updateReminder rejects custom frequency below 1 day")
    func rejectsCustomFrequencyBelowOne() async throws {
        let (service, _, _, reminder) = try await makeService()
        await #expect(throws: ReminderError.self) {
            try await service.updateReminder(
                reminder,
                title: reminder.title,
                message: reminder.message,
                type: reminder.reminderType,
                frequency: .custom,
                customFrequencyDays: 0,
                preferredTime: reminder.preferredNotificationTime,
                priority: reminder.priority,
                enableWeatherAdjustment: reminder.enableWeatherAdjustment,
                isEnabled: reminder.isEnabled
            )
        }
    }
```

- [ ] **Step 2: Run tests, expect 4 failures**

Run: `swift test --package-path GrowWisePackage --filter ReminderServiceUpdateTests 2>&1 | tail -15`

Expected: 4 of 5 tests fail (the validation tests). The smoke test still passes.

- [ ] **Step 3: Implement validation in `updateReminder`**

Replace the stub body in `ReminderService.swift` with:

```swift
    public func updateReminder(
        _ reminder: PlantReminder,
        title: String,
        message: String,
        type: ReminderType,
        frequency: ReminderFrequency,
        customFrequencyDays: Int?,
        preferredTime: Date?,
        priority: ReminderPriority,
        enableWeatherAdjustment: Bool,
        isEnabled: Bool
    ) async throws {
        // 1. Validate.
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw ReminderError.emptyTitle
        }
        if frequency == .custom {
            guard let days = customFrequencyDays, days >= 1 else {
                throw ReminderError.invalidCustomFrequency
            }
            _ = days // referenced for clarity; mutation happens later
        }
    }
```

- [ ] **Step 4: Run tests, expect all 5 pass**

Run: `swift test --package-path GrowWisePackage --filter ReminderServiceUpdateTests 2>&1 | tail -10`

Expected: 5 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift \
        GrowWisePackage/Tests/GrowWiseServicesTests/ReminderServiceUpdateTests.swift
git commit -m "$(cat <<'EOF'
feat(#274): updateReminder validates title and custom frequency days

Empty/whitespace title throws ReminderError.emptyTitle. Custom
frequency with nil or <1 days throws ReminderError.invalidCustomFrequency.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Field mutation + `lastModified`

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift`
- Modify: `GrowWisePackage/Tests/GrowWiseServicesTests/ReminderServiceUpdateTests.swift`

- [ ] **Step 1: Add the failing tests**

Append:

```swift
    // MARK: - Mutation

    @Test("updateReminder mutates editable fields")
    func mutatesEditableFields() async throws {
        let (service, _, _, reminder) = try await makeService()
        let newTime = Date(timeIntervalSinceNow: 3600)

        try await service.updateReminder(
            reminder,
            title: "Updated title",
            message: "Updated message",
            type: .fertilizing,
            frequency: .biweekly,
            customFrequencyDays: nil,
            preferredTime: newTime,
            priority: .high,
            enableWeatherAdjustment: true,
            isEnabled: true
        )

        #expect(reminder.title == "Updated title")
        #expect(reminder.message == "Updated message")
        #expect(reminder.reminderType == .fertilizing)
        #expect(reminder.frequency == .biweekly)
        #expect(reminder.baseFrequencyDays == ReminderFrequency.biweekly.days)
        #expect(reminder.customFrequencyDays == nil)
        #expect(reminder.preferredNotificationTime == newTime)
        #expect(reminder.priority == .high)
        #expect(reminder.enableWeatherAdjustment == true)
        #expect(reminder.isEnabled == true)
    }

    @Test("updateReminder advances lastModified")
    func advancesLastModified() async throws {
        let (service, _, _, reminder) = try await makeService()
        let pre = reminder.lastModified
        try? await Task.sleep(nanoseconds: 10_000_000) // 10 ms — ensures clock advances on fast machines

        try await service.updateReminder(
            reminder,
            title: "New title",
            message: reminder.message,
            type: reminder.reminderType,
            frequency: reminder.frequency,
            customFrequencyDays: reminder.customFrequencyDays,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: reminder.isEnabled
        )

        #expect(reminder.lastModified > pre)
    }
```

- [ ] **Step 2: Run, expect both new tests fail**

Run: `swift test --package-path GrowWisePackage --filter ReminderServiceUpdateTests 2>&1 | tail -15`

Expected: The two new tests fail (model not mutated).

- [ ] **Step 3: Implement mutation**

Extend `updateReminder` body — append after the validation block:

```swift
        // 2. Mutate the model.
        reminder.title = trimmedTitle
        reminder.message = message
        reminder.reminderType = type
        reminder.frequency = frequency
        reminder.baseFrequencyDays = frequency.days
        reminder.customFrequencyDays = (frequency == .custom) ? customFrequencyDays : nil
        reminder.preferredNotificationTime = preferredTime
        reminder.priority = priority
        reminder.enableWeatherAdjustment = enableWeatherAdjustment
        reminder.isEnabled = isEnabled
        reminder.lastModified = Date()

        // 3. Save.
        try dataService.modelContext.save()
```

- [ ] **Step 4: Run, expect all 7 pass**

Run: `swift test --package-path GrowWisePackage --filter ReminderServiceUpdateTests 2>&1 | tail -10`

Expected: 7 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift \
        GrowWisePackage/Tests/GrowWiseServicesTests/ReminderServiceUpdateTests.swift
git commit -m "$(cat <<'EOF'
feat(#274): updateReminder mutates editable fields and persists

Assigns title/message/type/frequency/customFrequencyDays/preferredTime/
priority/enableWeatherAdjustment/isEnabled, bumps lastModified, and
saves the SwiftData context.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `nextDueDate` recalculation

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift`
- Modify: `GrowWisePackage/Tests/GrowWiseServicesTests/ReminderServiceUpdateTests.swift`

- [ ] **Step 1: Add the failing tests**

Append:

```swift
    // MARK: - Schedule recalc

    @Test("updateReminder recalculates nextDueDate when frequency changes")
    func recalculatesNextDueDateOnFrequencyChange() async throws {
        let (service, _, _, reminder) = try await makeService()
        let originalDate = reminder.nextDueDate
        // Reminder was created weekly. Switch to daily — next due should move much closer.

        try await service.updateReminder(
            reminder,
            title: reminder.title,
            message: reminder.message,
            type: reminder.reminderType,
            frequency: .daily,
            customFrequencyDays: nil,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: reminder.isEnabled
        )

        #expect(reminder.nextDueDate != originalDate)
        // Daily reminder should be due within ~2 days; weekly is ~7 days out.
        let twoDays: TimeInterval = 60 * 60 * 24 * 2
        #expect(reminder.nextDueDate.timeIntervalSinceNow < twoDays)
    }

    @Test("updateReminder leaves nextDueDate alone when only title changes")
    func preservesNextDueDateWhenScheduleUnchanged() async throws {
        let (service, _, _, reminder) = try await makeService()
        let originalDate = reminder.nextDueDate

        try await service.updateReminder(
            reminder,
            title: "Renamed",
            message: reminder.message,
            type: reminder.reminderType,
            frequency: reminder.frequency,
            customFrequencyDays: reminder.customFrequencyDays,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: reminder.isEnabled
        )

        #expect(reminder.nextDueDate == originalDate)
    }

    @Test("updateReminder accepts custom frequency days")
    func acceptsCustomFrequencyDays() async throws {
        let (service, _, _, reminder) = try await makeService()

        try await service.updateReminder(
            reminder,
            title: reminder.title,
            message: reminder.message,
            type: reminder.reminderType,
            frequency: .custom,
            customFrequencyDays: 3,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: reminder.isEnabled
        )

        #expect(reminder.frequency == .custom)
        #expect(reminder.customFrequencyDays == 3)
    }
```

- [ ] **Step 2: Run, expect first two tests fail (third already passes via Task 3 mutation logic)**

Run: `swift test --package-path GrowWisePackage --filter ReminderServiceUpdateTests 2>&1 | tail -15`

Expected: 8 of 10 pass; `recalculatesNextDueDateOnFrequencyChange` and `preservesNextDueDateWhenScheduleUnchanged` fail.

- [ ] **Step 3: Implement schedule recalc**

In `ReminderService.swift`, modify `updateReminder` to snapshot the pre-mutation state for change detection and recalc `nextDueDate` only when needed.

Replace the body (everything after the validation block from Task 2) with:

```swift
        // 2. Snapshot for change detection.
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let frequencyChanged = reminder.frequency != frequency || reminder.customFrequencyDays != customFrequencyDays
        let timeChanged = reminder.preferredNotificationTime != preferredTime

        // 3. Mutate the model.
        reminder.title = trimmedTitle
        reminder.message = message
        reminder.reminderType = type
        reminder.frequency = frequency
        reminder.baseFrequencyDays = frequency.days
        reminder.customFrequencyDays = (frequency == .custom) ? customFrequencyDays : nil
        reminder.preferredNotificationTime = preferredTime
        reminder.priority = priority
        reminder.enableWeatherAdjustment = enableWeatherAdjustment
        reminder.isEnabled = isEnabled
        reminder.lastModified = Date()

        // 4. Recalculate nextDueDate when schedule inputs changed.
        if frequencyChanged || timeChanged, let plant = reminder.plant {
            let baseDays = (frequency == .custom ? (customFrequencyDays ?? frequency.days) : frequency.days)
            reminder.nextDueDate = await calculateNextDueDate(
                baseFrequencyDays: baseDays,
                reminderType: type,
                plant: plant,
                enableWeatherAdjustment: enableWeatherAdjustment,
                preferredTime: preferredTime
            )
        }

        // 5. Save.
        try dataService.modelContext.save()
```

> **Note:** Move the `let trimmedTitle = ...` line out of the validation block — keep it after validation as the snapshot setup. This is a refactor, not a new behavior.

> **Reference for `calculateNextDueDate`:** the helper already exists in `ReminderService.swift` and is used by `createSmartReminder`. Find it via `grep -n "calculateNextDueDate" GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift`. Verify the signature matches what we pass.

- [ ] **Step 4: Run, expect all 10 pass**

Run: `swift test --package-path GrowWisePackage --filter ReminderServiceUpdateTests 2>&1 | tail -10`

Expected: 10 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift \
        GrowWisePackage/Tests/GrowWiseServicesTests/ReminderServiceUpdateTests.swift
git commit -m "$(cat <<'EOF'
feat(#274): updateReminder recalculates nextDueDate on schedule change

Snapshots pre-mutation frequency/customFrequencyDays/preferredTime so
the algorithm can recalc nextDueDate via calculateNextDueDate(...)
when (and only when) those inputs change.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Type-change message prefill

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift`
- Modify: `GrowWisePackage/Tests/GrowWiseServicesTests/ReminderServiceUpdateTests.swift`

- [ ] **Step 1: Add the failing tests**

Append:

```swift
    // MARK: - Message prefill on type change

    @Test("updateReminder prefills message with new type's default when message is empty and type changes")
    func prefillsMessageOnTypeChangeWhenEmpty() async throws {
        let (service, _, _, reminder) = try await makeService()
        // Original reminder is .watering; change to .fertilizing with empty message.

        try await service.updateReminder(
            reminder,
            title: reminder.title,
            message: "",
            type: .fertilizing,
            frequency: reminder.frequency,
            customFrequencyDays: reminder.customFrequencyDays,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: reminder.isEnabled
        )

        #expect(reminder.message == ReminderType.fertilizing.defaultMessage)
    }

    @Test("updateReminder preserves user message when type changes and message is non-empty")
    func preservesUserMessageOnTypeChange() async throws {
        let (service, _, _, reminder) = try await makeService()

        try await service.updateReminder(
            reminder,
            title: reminder.title,
            message: "Custom user message",
            type: .fertilizing,
            frequency: reminder.frequency,
            customFrequencyDays: reminder.customFrequencyDays,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: reminder.isEnabled
        )

        #expect(reminder.message == "Custom user message")
    }

    @Test("updateReminder preserves empty message when type does not change")
    func preservesEmptyMessageWhenTypeUnchanged() async throws {
        let (service, _, _, reminder) = try await makeService()

        try await service.updateReminder(
            reminder,
            title: reminder.title,
            message: "",
            type: reminder.reminderType, // unchanged
            frequency: reminder.frequency,
            customFrequencyDays: reminder.customFrequencyDays,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: reminder.isEnabled
        )

        #expect(reminder.message == "")
    }
```

- [ ] **Step 2: Run, expect first test fails**

Run: `swift test --package-path GrowWisePackage --filter ReminderServiceUpdateTests 2>&1 | tail -15`

Expected: `prefillsMessageOnTypeChangeWhenEmpty` fails (model gets empty string instead of default message). The other two new tests pass — they assert behavior that's already correct.

- [ ] **Step 3: Implement the prefill rule**

In `ReminderService.swift updateReminder`, before the mutation block, compute the effective message:

Find the line `// 3. Mutate the model.` and immediately above it, add:

```swift
        // 2b. Resolve effective message: prefill the type's default
        // when the user changed the type and left the message blank.
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveMessage: String = {
            if reminder.reminderType != type, trimmedMessage.isEmpty {
                return type.defaultMessage
            }
            return message
        }()
```

Then change `reminder.message = message` to `reminder.message = effectiveMessage`.

- [ ] **Step 4: Run, expect all 13 pass**

Run: `swift test --package-path GrowWisePackage --filter ReminderServiceUpdateTests 2>&1 | tail -10`

Expected: 13 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift \
        GrowWisePackage/Tests/GrowWiseServicesTests/ReminderServiceUpdateTests.swift
git commit -m "$(cat <<'EOF'
feat(#274): updateReminder prefills default message on type change

When the user changes the reminder type and leaves the message blank,
the new type's defaultMessage is used instead of an empty string. A
non-empty user message is preserved verbatim regardless of type change.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Notification reschedule (smoke test only)

The notification side-effect (cancel-on-disable, reschedule-on-change) goes through `NotificationService.scheduleReminderNotification(for:)` and `cancelReminderNotification(for:)`. In tests we use `notificationCenter: nil`, which makes these calls into no-ops (see `NotificationService.swift:78` and :92). We can't assert call counts without a refactor, but we can verify that the algorithm runs end-to-end without throwing when scheduling is enabled.

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift`
- Modify: `GrowWisePackage/Tests/GrowWiseServicesTests/ReminderServiceUpdateTests.swift`

- [ ] **Step 1: Add the failing test**

Append:

```swift
    // MARK: - Notification reschedule

    @Test("updateReminder runs without throwing when shouldScheduleNotifications is true")
    func runsWithSchedulingEnabled() async throws {
        let dataService = try DataService.makeForTesting()
        let notificationService = NotificationService(notificationCenter: nil)
        let service = ReminderService(
            dataService: dataService,
            notificationService: notificationService,
            shouldScheduleNotifications: true
        )
        let plant = try dataService.createPlant(name: "Mint-\(UUID())", type: .herb)
        let reminder = try await service.createSmartReminder(
            for: plant,
            type: .watering,
            baseFrequencyDays: ReminderFrequency.weekly.days,
            enableWeatherAdjustment: false,
            priority: .medium,
            preferredTime: Date()
        )

        // Toggle isEnabled both ways and change frequency — exercises both cancel and schedule branches.
        try await service.updateReminder(
            reminder,
            title: reminder.title,
            message: reminder.message,
            type: reminder.reminderType,
            frequency: .daily,
            customFrequencyDays: nil,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: false // disable — should hit the cancel branch
        )

        try await service.updateReminder(
            reminder,
            title: reminder.title,
            message: reminder.message,
            type: reminder.reminderType,
            frequency: .weekly,
            customFrequencyDays: nil,
            preferredTime: reminder.preferredNotificationTime,
            priority: reminder.priority,
            enableWeatherAdjustment: reminder.enableWeatherAdjustment,
            isEnabled: true // re-enable — should hit the cancel + schedule branches
        )

        #expect(reminder.isEnabled == true)
    }
```

- [ ] **Step 2: Run, expect failure (no throw, but the rescheduling code path doesn't exist yet — so no specific assertion fails; this test is a regression guard for the next step)**

Run: `swift test --package-path GrowWisePackage --filter ReminderServiceUpdateTests 2>&1 | tail -15`

Expected: 14 of 14 pass. The test asserts only that the call succeeds and the final state is correct; it would still pass without the rescheduling code (the call doesn't throw either way). The test's value is to **lock in the contract**: any future regression that makes the cancel/schedule branch throw on a `nil` notificationCenter will surface here.

> **TDD note:** This is the only test in the plan whose pre-implementation state passes — that's intentional. The test guards behavior we're about to add; running it now establishes a green baseline before the change.

- [ ] **Step 3: Implement the reschedule branch**

The reschedule logic needs to compare `reminder.isEnabled` to the incoming `isEnabled` parameter — but Task 3 already mutated the model, so the comparison has to happen on a pre-mutation snapshot. Replace the entire `updateReminder` body so it cleanly orders validation → snapshot → message resolve → mutate → recalc → reschedule → save:

```swift
    public func updateReminder(
        _ reminder: PlantReminder,
        title: String,
        message: String,
        type: ReminderType,
        frequency: ReminderFrequency,
        customFrequencyDays: Int?,
        preferredTime: Date?,
        priority: ReminderPriority,
        enableWeatherAdjustment: Bool,
        isEnabled: Bool
    ) async throws {
        // 1. Validate.
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw ReminderError.emptyTitle
        }
        if frequency == .custom {
            guard let days = customFrequencyDays, days >= 1 else {
                throw ReminderError.invalidCustomFrequency
            }
            _ = days
        }

        // 2. Snapshot pre-mutation state for change detection.
        let frequencyChanged = reminder.frequency != frequency || reminder.customFrequencyDays != customFrequencyDays
        let timeChanged = reminder.preferredNotificationTime != preferredTime
        let enableStateChanged = reminder.isEnabled != isEnabled

        // 3. Resolve effective message: prefill the type's default
        // when the user changed the type and left the message blank.
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveMessage: String
        if reminder.reminderType != type, trimmedMessage.isEmpty {
            effectiveMessage = type.defaultMessage
        } else {
            effectiveMessage = message
        }

        // 4. Mutate the model.
        reminder.title = trimmedTitle
        reminder.message = effectiveMessage
        reminder.reminderType = type
        reminder.frequency = frequency
        reminder.baseFrequencyDays = frequency.days
        reminder.customFrequencyDays = (frequency == .custom) ? customFrequencyDays : nil
        reminder.preferredNotificationTime = preferredTime
        reminder.priority = priority
        reminder.enableWeatherAdjustment = enableWeatherAdjustment
        reminder.isEnabled = isEnabled
        reminder.lastModified = Date()

        // 5. Recalculate nextDueDate when schedule inputs changed.
        if frequencyChanged || timeChanged, let plant = reminder.plant {
            let baseDays = (frequency == .custom ? (customFrequencyDays ?? frequency.days) : frequency.days)
            reminder.nextDueDate = await calculateNextDueDate(
                baseFrequencyDays: baseDays,
                reminderType: type,
                plant: plant,
                enableWeatherAdjustment: enableWeatherAdjustment,
                preferredTime: preferredTime
            )
        }

        // 6. Reschedule notification.
        if shouldScheduleNotifications {
            if !isEnabled {
                await notificationService.cancelReminderNotification(for: reminder.id)
            } else if frequencyChanged || timeChanged || enableStateChanged {
                await notificationService.cancelReminderNotification(for: reminder.id)
                try await notificationService.scheduleReminderNotification(for: reminder)
            }
        }

        // 7. Save.
        try dataService.modelContext.save()
    }
```

- [ ] **Step 4: Run all tests, expect all 14 pass**

Run: `swift test --package-path GrowWisePackage --filter ReminderServiceUpdateTests 2>&1 | tail -10`

Expected: 14 tests, 0 failures.

- [ ] **Step 5: Run the full ReminderService test set to catch regressions**

Run: `swift test --package-path GrowWisePackage --filter ReminderService 2>&1 | tail -15`

Expected: All ReminderService-related tests still pass (no regressions in updateWateringSchedule, createSmartReminder, etc.).

- [ ] **Step 6: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift \
        GrowWisePackage/Tests/GrowWiseServicesTests/ReminderServiceUpdateTests.swift
git commit -m "$(cat <<'EOF'
feat(#274): updateReminder cancels/reschedules notification

When the reminder is disabled, cancel any pending notification. When
schedule inputs (frequency, custom days, preferred time, isEnabled)
change and the reminder is enabled, cancel + reschedule. The cancel
covers the case where the prior notification request had different
timing data so the new schedule isn't shadowed.

Notification scheduling only fires when shouldScheduleNotifications
is true — same gate the rest of ReminderService uses to keep tests
fast and offline-safe.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: `EditReminderView.FormState` and its tests

The reminder → form-state mapping is the only piece of EditReminderView that's worth unit-testing without a SwiftUI host.

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseFeature/Views/EditReminderView.swift`
- Create: `GrowWisePackage/Tests/GrowWiseFeatureTests/EditReminderViewTests.swift`

- [ ] **Step 1: Create the test file**

Create `GrowWisePackage/Tests/GrowWiseFeatureTests/EditReminderViewTests.swift`:

```swift
import Testing
import Foundation
@testable import GrowWiseFeature
@testable import GrowWiseModels

@Suite("EditReminderView.FormState mapping")
struct EditReminderViewTests {
    @Test("FormState.initial maps all editable fields")
    func mapsAllFields() {
        let preferred = Date(timeIntervalSinceReferenceDate: 100_000)
        let reminder = PlantReminder(
            title: "Water the basil",
            message: "Check for dry soil first",
            reminderType: .watering,
            frequency: .biweekly,
            nextDueDate: Date(),
            plant: nil
        )
        reminder.priority = .high
        reminder.enableWeatherAdjustment = true
        reminder.preferredNotificationTime = preferred
        reminder.customFrequencyDays = nil
        reminder.isEnabled = true

        let state = EditReminderView.FormState.initial(from: reminder)

        #expect(state.title == "Water the basil")
        #expect(state.message == "Check for dry soil first")
        #expect(state.type == .watering)
        #expect(state.frequency == .biweekly)
        #expect(state.preferredTime == preferred)
        #expect(state.priority == .high)
        #expect(state.enableWeatherAdjustment == true)
        #expect(state.isEnabled == true)
    }

    @Test("FormState.initial uses nextDueDate when preferredNotificationTime is nil")
    func defaultsPreferredTimeToNextDueDate() {
        let dueDate = Date(timeIntervalSinceReferenceDate: 200_000)
        let reminder = PlantReminder(
            title: "Test",
            message: "Test",
            reminderType: .watering,
            frequency: .weekly,
            nextDueDate: dueDate,
            plant: nil
        )
        reminder.preferredNotificationTime = nil

        let state = EditReminderView.FormState.initial(from: reminder)

        #expect(state.preferredTime == dueDate)
    }

    @Test("FormState.initial defaults customDays to frequency.days when nil")
    func defaultsCustomDaysFromFrequency() {
        let reminder = PlantReminder(
            title: "Test",
            message: "Test",
            reminderType: .watering,
            frequency: .weekly,
            nextDueDate: Date(),
            plant: nil
        )
        reminder.customFrequencyDays = nil

        let state = EditReminderView.FormState.initial(from: reminder)

        #expect(state.customDays == ReminderFrequency.weekly.days)
    }

    @Test("FormState.initial preserves customDays when set")
    func preservesCustomDays() {
        let reminder = PlantReminder(
            title: "Test",
            message: "Test",
            reminderType: .watering,
            frequency: .custom,
            nextDueDate: Date(),
            plant: nil
        )
        reminder.customFrequencyDays = 5

        let state = EditReminderView.FormState.initial(from: reminder)

        #expect(state.customDays == 5)
    }
}
```

- [ ] **Step 2: Run, expect compile failure**

Run: `swift test --package-path GrowWisePackage --filter EditReminderViewTests 2>&1 | tail -10`

Expected: Compile error — `Cannot find 'EditReminderView' in scope` (or `'FormState' is not a member of 'EditReminderView'`).

- [ ] **Step 3: Create the EditReminderView file with just the FormState type**

Create `GrowWisePackage/Sources/GrowWiseFeature/Views/EditReminderView.swift`:

```swift
import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct EditReminderView: View {
    let reminder: PlantReminder
    let reminderService: ReminderService
    let onSave: () -> Void
    let onDelete: (PlantReminder) -> Void

    @Environment(\.dismiss)
    private var dismiss

    public init(
        reminder: PlantReminder,
        reminderService: ReminderService,
        onSave: @escaping () -> Void,
        onDelete: @escaping (PlantReminder) -> Void
    ) {
        self.reminder = reminder
        self.reminderService = reminderService
        self.onSave = onSave
        self.onDelete = onDelete
    }

    public var body: some View {
        // Body filled in by Task 8.
        Text("EditReminderView pending")
    }
}

extension EditReminderView {
    struct FormState: Equatable {
        var title: String
        var message: String
        var type: ReminderType
        var frequency: ReminderFrequency
        var customDays: Int
        var preferredTime: Date
        var priority: ReminderPriority
        var enableWeatherAdjustment: Bool
        var isEnabled: Bool

        static func initial(from reminder: PlantReminder) -> FormState {
            FormState(
                title: reminder.title,
                message: reminder.message,
                type: reminder.reminderType,
                frequency: reminder.frequency,
                customDays: reminder.customFrequencyDays ?? max(1, reminder.frequency.days),
                preferredTime: reminder.preferredNotificationTime ?? reminder.nextDueDate,
                priority: reminder.priority,
                enableWeatherAdjustment: reminder.enableWeatherAdjustment,
                isEnabled: reminder.isEnabled
            )
        }
    }
}
```

> **Why a placeholder body:** keeping Task 7 focused on FormState. The full body lands in Task 8 — the placeholder is harmless because `PlantReminderDetailView` still constructs the **old** placeholder until Task 9.

- [ ] **Step 4: Run tests, expect 4 pass**

Run: `swift test --package-path GrowWisePackage --filter EditReminderViewTests 2>&1 | tail -10`

Expected: 4 tests, 0 failures.

- [ ] **Step 5: Build to ensure the package still compiles**

Run: `swift build --package-path GrowWisePackage 2>&1 | tail -5`

Expected: `Build complete!`. There will be a name collision because `PlantReminderDetailView.swift` still defines its own `EditReminderView` struct. Two `struct EditReminderView` declarations in the same module is a compile error.

> **Resolution if build fails:** Temporarily rename the placeholder struct in `PlantReminderDetailView.swift:681` from `struct EditReminderView` to `struct EditReminderViewPlaceholder` and update the corresponding `.sheet(item:)` constructor call at `PlantReminderDetailView.swift:81` to `EditReminderViewPlaceholder(...)`. The placeholder is fully replaced in Task 9, so this rename is short-lived.
>
> Then re-run `swift build`.

- [ ] **Step 6: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/EditReminderView.swift \
        GrowWisePackage/Tests/GrowWiseFeatureTests/EditReminderViewTests.swift \
        GrowWisePackage/Sources/GrowWiseFeature/Views/PlantReminderDetailView.swift
git commit -m "$(cat <<'EOF'
feat(#274): add EditReminderView shell with FormState mapping

Introduces EditReminderView in its own file with a nested FormState
value type. FormState.initial(from:) is the unit-testable mapping
from PlantReminder to the editable form fields, with sensible
defaults for nil preferredNotificationTime and customFrequencyDays.

The placeholder EditReminderView in PlantReminderDetailView is
renamed to EditReminderViewPlaceholder to avoid a same-name collision
during the cutover. The placeholder is fully removed in a follow-up
commit once the new view's body is implemented.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: EditReminderView body

Implement the full form. This task is the largest single change in the plan; if dispatched to a subagent, give it the spec section "View-layer change" verbatim plus the AddReminderView reference.

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/EditReminderView.swift`

- [ ] **Step 1: Replace the placeholder body with the full implementation**

Open `GrowWisePackage/Sources/GrowWiseFeature/Views/EditReminderView.swift` and replace the entire file with:

```swift
import GrowWiseModels
import GrowWiseServices
import SwiftUI

public struct EditReminderView: View {
    let reminder: PlantReminder
    let reminderService: ReminderService
    let onSave: () -> Void
    let onDelete: (PlantReminder) -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State private var title: String
    @State private var message: String
    @State private var reminderType: ReminderType
    @State private var frequency: ReminderFrequency
    @State private var customDays: Int
    @State private var preferredTime: Date
    @State private var priority: ReminderPriority
    @State private var enableWeatherAdjustment: Bool
    @State private var isPaused: Bool

    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?
    @State private var errorMessage: String?

    public init(
        reminder: PlantReminder,
        reminderService: ReminderService,
        onSave: @escaping () -> Void,
        onDelete: @escaping (PlantReminder) -> Void
    ) {
        self.reminder = reminder
        self.reminderService = reminderService
        self.onSave = onSave
        self.onDelete = onDelete
        let initial = FormState.initial(from: reminder)
        _title = State(initialValue: initial.title)
        _message = State(initialValue: initial.message)
        _reminderType = State(initialValue: initial.type)
        _frequency = State(initialValue: initial.frequency)
        _customDays = State(initialValue: initial.customDays)
        _preferredTime = State(initialValue: initial.preferredTime)
        _priority = State(initialValue: initial.priority)
        _enableWeatherAdjustment = State(initialValue: initial.enableWeatherAdjustment)
        _isPaused = State(initialValue: !initial.isEnabled)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.backgroundSecondary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: CultivationTheme.Spacing.sectionGap) {
                        Capsule()
                            .fill(CultivationTheme.Colors.cardBorder)
                            .frame(width: 36, height: 4)
                            .padding(.top, 8)

                        plantHeader
                        reminderTypeSection
                        frequencySection
                        timingSection
                        prioritySection
                        customContentSection
                        pauseSection

                        Button(role: .destructive) {
                            onDelete(reminder)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                Text("Delete Reminder")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.bordered)
                        .tint(CultivationTheme.Colors.statusAlert)
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                        .accessibilityIdentifier("editreminder_button_delete")

                        Button {
                            save()
                        } label: {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text(isSaving ? "Saving..." : "Save Changes")
                            }
                        }
                        .buttonStyle(GradientButtonStyle(isDisabled: isSaving))
                        .disabled(isSaving)
                        .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
                        .accessibilityIdentifier("plantreminder_button_edit_save")
                        .padding(.bottom, 24)
                    }
                }

                if isSaving {
                    ZStack {
                        CultivationTheme.Colors.textPrimary.opacity(0.25)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView().scaleEffect(1.2)
                            Text("Saving changes...")
                                .font(.headline)
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        }
                        .padding(32)
                        .paperCard()
                    }
                }
            }
            .navigationTitle("Edit Reminder")
            .gwNavigationBarTitleDisplayMode(.inline)
            .onDisappear { saveTask?.cancel() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("plantreminder_button_edit_cancel")
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    // MARK: - Plant header (read-only)

    private var plantHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plant")
                .sectionLabelStyle()
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)

            HStack(spacing: 12) {
                IconBubble(
                    systemName: plantIcon(for: reminder.plant),
                    color: plantColor(for: reminder.plant),
                    size: 36,
                    iconSize: 16
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.plant?.name ?? "Unknown Plant")
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    Text(reminder.plant?.plantType?.displayName ?? "Unknown Type")
                        .font(.system(.caption))
                        .foregroundStyle(CultivationTheme.Colors.textSecondary)
                }

                Spacer()
            }
            .padding(CultivationTheme.Spacing.cardPadding)
            .glassCard()
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
        }
    }

    // MARK: - Form sections

    private var reminderTypeSection: some View {
        formSection(title: "Reminder Type") {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ReminderType.allCases, id: \.self) { type in
                            GlassPill(
                                label: type.displayName,
                                isSelected: reminderType == type,
                                accessibilityID: "editreminder_pill_type_\(type.rawValue)"
                            ) {
                                reminderType = type
                            }
                        }
                    }
                }
                Text(reminderType.defaultMessage)
                    .font(.system(.caption))
                    .foregroundStyle(CultivationTheme.Colors.textTertiary)
            }
        }
    }

    private var frequencySection: some View {
        formSection(title: "Frequency") {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(frequencyOptions, id: \.self) { freq in
                            GlassPill(
                                label: freq.displayName,
                                isSelected: frequency == freq,
                                // swiftlint:disable:next line_length
                                accessibilityID: "editreminder_pill_frequency_\(freq.displayName.lowercased().replacingOccurrences(of: " ", with: "_"))"
                            ) {
                                frequency = freq
                            }
                        }
                    }
                }

                if case .custom = frequency {
                    HStack {
                        Text("Every")
                            .font(.system(.subheadline))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                        Spacer()
                        TextField("Days", value: $customDays, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .accessibilityIdentifier("editreminder_textfield_customdays")
                        Text("days")
                            .font(.system(.subheadline))
                            .foregroundStyle(CultivationTheme.Colors.textSecondary)
                    }
                }
            }
        }
    }

    private var timingSection: some View {
        formSection(title: "Timing") {
            VStack(spacing: 12) {
                HStack {
                    IconBubble(systemName: "clock.fill", color: CultivationTheme.Colors.brandForest, size: 28, iconSize: 13)
                    DatePicker("Preferred Time", selection: $preferredTime, displayedComponents: .hourAndMinute)
                        .font(.system(.subheadline))
                        .accessibilityIdentifier("editreminder_datepicker_time")
                }

                Divider().background(CultivationTheme.Colors.divider)

                HStack {
                    IconBubble(systemName: "cloud.sun.fill", color: CultivationTheme.Colors.accentAmber, size: 28, iconSize: 13)
                    Text("Smart Weather Adjustment")
                        .font(.system(.subheadline))
                        .foregroundStyle(CultivationTheme.Colors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $enableWeatherAdjustment)
                        .accessibilityIdentifier("editreminder_toggle_weatheradjustment")
                }
            }
        }
    }

    private var prioritySection: some View {
        formSection(title: "Priority") {
            HStack(spacing: 8) {
                // swiftlint:disable:next identifier_name
                ForEach(ReminderPriority.allCases, id: \.self) { p in
                    GlassPill(
                        label: p.displayName,
                        isSelected: priority == p,
                        accessibilityID: "editreminder_pill_priority_\(p.displayName.lowercased())"
                    ) {
                        priority = p
                    }
                }
            }
        }
    }

    private var customContentSection: some View {
        formSection(title: "Title & Message") {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    IconBubble(systemName: "textformat", color: CultivationTheme.Colors.brandSage, size: 28, iconSize: 13)
                    ValidatedTextField(
                        "Title",
                        text: $title,
                        validation: { ValidationService.shared.validateText($0, fieldName: "Title", maxLength: 100) }
                    )
                    .accessibilityIdentifier("editreminder_textfield_title")
                }

                Divider().background(CultivationTheme.Colors.divider)

                HStack(alignment: .top, spacing: 10) {
                    IconBubble(systemName: "text.alignleft", color: CultivationTheme.Colors.brandSage, size: 28, iconSize: 13)
                        .padding(.top, 2)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $message)
                            .frame(minHeight: 80)
                            .font(.system(.body))
                            .foregroundStyle(CultivationTheme.Colors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .accessibilityIdentifier("editreminder_texteditor_message")
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(CultivationTheme.Colors.cardBorder, lineWidth: 1)
                            )
                            .onChange(of: message) { _, newValue in
                                let validation = ValidationService.shared.validateText(
                                    newValue, fieldName: "Message", maxLength: 500
                                )
                                if !validation.isValid {
                                    message = String(newValue.prefix(500))
                                }
                            }

                        if message.isEmpty {
                            Text("Message")
                                .foregroundStyle(CultivationTheme.Colors.textTertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
    }

    private var pauseSection: some View {
        formSection(title: "Status") {
            HStack {
                IconBubble(systemName: "pause.circle.fill", color: CultivationTheme.Colors.textSecondary, size: 28, iconSize: 13)
                Text("Pause Reminder")
                    .font(.system(.subheadline))
                    .foregroundStyle(CultivationTheme.Colors.textPrimary)
                Spacer()
                Toggle("", isOn: $isPaused)
                    .accessibilityIdentifier("editreminder_toggle_pause")
            }
        }
    }

    // MARK: - Section builder

    private func formSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .sectionLabelStyle()
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            content()
                .padding(CultivationTheme.Spacing.cardPadding)
                .glassCard()
                .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
        }
    }

    // MARK: - Computed

    private var frequencyOptions: [ReminderFrequency] {
        [.daily, .everyOtherDay, .twiceWeekly, .weekly, .biweekly, .monthly, .custom]
    }

    // MARK: - Helpers

    private func plantIcon(for plant: Plant?) -> String {
        switch plant?.plantType {
        case .houseplant: "house.fill"
        case .succulent: "circle.hexagongrid.fill"
        case .herb: "leaf.fill"
        case .vegetable: "carrot.fill"
        case .flower: "camera.macro"
        case .fruit: "apple.logo"
        case .tree: "tree.fill"
        case .shrub: "leaf.circle.fill"
        case .none: "questionmark.circle.fill"
        }
    }

    private func plantColor(for plant: Plant?) -> Color {
        switch plant?.plantType {
        case .houseplant, .herb, .shrub: CultivationTheme.Colors.brandLeaf
        case .succulent: .mint
        case .vegetable: .orange
        case .flower: .pink
        case .fruit: .red
        case .tree: .brown
        case .none: CultivationTheme.Colors.textTertiary
        }
    }

    // MARK: - Save

    private func save() {
        isSaving = true
        saveTask = Task {
            do {
                try await reminderService.updateReminder(
                    reminder,
                    title: title,
                    message: message,
                    type: reminderType,
                    frequency: frequency,
                    customFrequencyDays: frequency == .custom ? customDays : nil,
                    preferredTime: preferredTime,
                    priority: priority,
                    enableWeatherAdjustment: enableWeatherAdjustment,
                    isEnabled: !isPaused
                )
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                await MainActor.run {
                    isSaving = false
                    onSave()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

extension EditReminderView {
    struct FormState: Equatable {
        var title: String
        var message: String
        var type: ReminderType
        var frequency: ReminderFrequency
        var customDays: Int
        var preferredTime: Date
        var priority: ReminderPriority
        var enableWeatherAdjustment: Bool
        var isEnabled: Bool

        static func initial(from reminder: PlantReminder) -> FormState {
            FormState(
                title: reminder.title,
                message: reminder.message,
                type: reminder.reminderType,
                frequency: reminder.frequency,
                customDays: reminder.customFrequencyDays ?? max(1, reminder.frequency.days),
                preferredTime: reminder.preferredNotificationTime ?? reminder.nextDueDate,
                priority: reminder.priority,
                enableWeatherAdjustment: reminder.enableWeatherAdjustment,
                isEnabled: reminder.isEnabled
            )
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build --package-path GrowWisePackage 2>&1 | tail -10`

Expected: `Build complete!`. If there are reference errors for any of `ValidationService`, `IconBubble`, `GlassPill`, `paperCard()`, `glassCard()`, `sectionLabelStyle()`, `GradientButtonStyle`, `CultivationTheme.Colors.statusAlert`, or `CultivationTheme.Colors.brandSage` — these are defined in `GrowWisePackage/Sources/GrowWiseFeature/Design/CultivationTheme.swift` and `Design/ViewModifiers.swift` and are already used by `AddReminderView`. If a symbol is missing, find its actual location with `grep -rn "<symbol>" GrowWisePackage/Sources/GrowWiseFeature/Design/` and adjust.

- [ ] **Step 3: Run all the tests we have for the reminder area**

Run: `swift test --package-path GrowWisePackage --filter "ReminderServiceUpdateTests|EditReminderViewTests" 2>&1 | tail -10`

Expected: 14 + 4 = 18 tests pass.

- [ ] **Step 4: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/EditReminderView.swift
git commit -m "$(cat <<'EOF'
feat(#274): implement EditReminderView body

Full editing form mirroring AddReminderView's structure: read-only
plant header, type/frequency/timing/priority/title/message sections,
a Pause toggle, a destructive Delete button, and a save flow that
calls ReminderService.updateReminder(...) with progress overlay and
error alert. Cancel/save toolbar buttons preserve the placeholder
view's accessibility identifiers (plantreminder_button_edit_cancel,
plantreminder_button_edit_save) so any future XCUITests targeting
the edit flow continue to find them.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Wire up `PlantReminderDetailView` and remove the placeholder

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/PlantReminderDetailView.swift`

- [ ] **Step 1: Update the sheet construction call site**

In `PlantReminderDetailView.swift`, find the `.sheet(item: $selectedReminder)` block (around line 80–90). It currently constructs `EditReminderViewPlaceholder(...)` (renamed in Task 7) or the original `EditReminderView(...)` (if Task 7 didn't need to rename). Either way, change the constructor to call the new view explicitly:

```swift
.sheet(item: $selectedReminder) { reminder in
    EditReminderView(
        reminder: reminder,
        reminderService: reminderService,
        onSave: { loadReminders() },
        onDelete: { reminderToDelete in
            self.reminderToDelete = reminderToDelete
            showingDeleteConfirmation = true
        }
    )
}
```

- [ ] **Step 2: Delete the placeholder struct**

Find lines 680–708 (the `/// Placeholder for EditReminderView` comment and the `struct EditReminderViewPlaceholder` definition — or `struct EditReminderView` if Task 7 didn't rename it). Delete the whole block. The file should end with the close of the `SuggestionCard` struct (around line 678) followed directly by `#Preview`.

- [ ] **Step 3: Build the package**

Run: `swift build --package-path GrowWisePackage 2>&1 | tail -5`

Expected: `Build complete!` with no warnings about unused `EditReminderViewPlaceholder` (it's gone) and no missing references (the call site uses the real `EditReminderView`).

- [ ] **Step 4: Run all reminder tests + the full feature suite to catch regressions**

Run: `swift test --package-path GrowWisePackage --filter "Reminder" 2>&1 | tail -10`

Expected: All reminder-related tests pass (existing AddReminder tests, the 14 new ReminderServiceUpdateTests, the 4 new EditReminderViewTests).

Run: `swift test --package-path GrowWisePackage 2>&1 | grep -E "All tests|Test run with"`

Expected: All tests pass — no regressions.

- [ ] **Step 5: SwiftLint clean run**

Run: `swiftlint lint --strict --config .swiftlint.yml --path GrowWisePackage/Sources/GrowWiseFeature/Views/EditReminderView.swift --path GrowWisePackage/Sources/GrowWiseFeature/Views/PlantReminderDetailView.swift --path GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift 2>&1 | tail -10`

Expected: 0 violations on these files (the broader codebase has 500+ pre-existing violations from other rules; we don't introduce new ones).

- [ ] **Step 6: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/PlantReminderDetailView.swift
git commit -m "$(cat <<'EOF'
feat(#274): replace placeholder EditReminderView in PlantReminderDetailView

Wires the existing .sheet(item: $selectedReminder) plumbing to the
new public EditReminderView and removes the local placeholder struct
that displayed "Edit Reminder - Coming Soon".

Closes the dead-end edit flow described in #274.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Push branch + open PR + watch CI

**Files:** none (workflow only)

- [ ] **Step 1: Push the branch**

```bash
git push -u origin feat/issue-274-reminder-editing
```

- [ ] **Step 2: Open the PR**

```bash
gh pr create --repo jbcrane13/GrowWise \
    --title "fix(#274): implement full reminder editing" \
    --body "$(cat <<'EOF'
## Summary
- Replace the "Edit Reminder - Coming Soon" placeholder with a full editing form modeled on AddReminderView.
- Add `ReminderService.updateReminder(...)` as the single entry point for mutation, nextDueDate recalculation, and notification rescheduling.
- Add `ReminderError.emptyTitle` and `.invalidCustomFrequency` cases for input validation.
- Add a "Pause Reminder" toggle backed by `isEnabled`, plus a destructive Delete button that delegates to the parent's existing confirmation alert.
- Add 14 service-layer tests covering validation, mutation, schedule recalc, message prefill on type change, and a notification-scheduling smoke test, plus 4 FormState mapping tests.

Closes #274.

## Decisions
- Plant association is **fixed** for an existing reminder. To re-target, users create a new reminder and delete the old. Brainstorming locked this in to avoid notification-rescheduling complexity around plant changes.
- Notification side-effects use the existing `shouldScheduleNotifications` gate; tests run with `notificationCenter: nil` (no real notification calls) and assert algorithm correctness rather than notification-call counts.
- Message prefill: when the user changes reminder type and leaves the message blank, the new type's `defaultMessage` is used so the body never references the prior type.

## Test plan
- [x] `swift test --package-path GrowWisePackage --filter ReminderServiceUpdateTests` — 14/14 pass locally
- [x] `swift test --package-path GrowWisePackage --filter EditReminderViewTests` — 4/4 pass locally
- [x] `swift test --package-path GrowWisePackage` — full suite green, no regressions
- [x] `swift build --package-path GrowWisePackage` succeeds
- [x] `swiftlint lint --strict --config .swiftlint.yml` reports 0 new violations on touched files
- [ ] CI green (Build, Test, SwiftLint, SwiftFormat, Coverage Threshold, QA — iOS Simulator)
- [ ] Manual smoke (mac-mini sim): tap edit on a reminder → form pre-filled with current values → change frequency to "Daily" → Save → list shows updated due date. Re-open and toggle "Pause Reminder" → Save → list shows reminder grayed out. Re-open and tap "Delete Reminder" → parent confirmation alert → Delete → list updates.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Verify the PR opened and watch CI**

```bash
gh pr view --repo jbcrane13/GrowWise --json number,url,state,mergeable,statusCheckRollup | jq '{number, url, state, mergeable, checks: [.statusCheckRollup[]? | {name, conclusion, status}]}'
```

Expected: The PR is OPEN, MERGEABLE, with checks queued or in-progress. Wait for required checks to be green or report blockers.

- [ ] **Step 4: Hand back to user**

Do **not** auto-merge. Do **not** close issue #274 yourself — `gh pr merge` (when invoked by the maintainer with the `Closes #274` body keyword) will close the issue on merge.

Comment: "PR opened, all required checks green. Awaiting your review/merge approval."

---

## Verification (final, after Task 10)

- [ ] PR opened and links to issue #274 (body says `Closes #274`).
- [ ] Required CI checks (Build, Test, SwiftLint, SwiftFormat, Coverage Threshold, QA — iOS Simulator) are green.
- [ ] No regressions to existing tests.
- [ ] The 14 ReminderServiceUpdateTests all pass.
- [ ] The 4 EditReminderViewTests all pass.
- [ ] `EditReminderView` is in its own file at `GrowWisePackage/Sources/GrowWiseFeature/Views/EditReminderView.swift`.
- [ ] The placeholder struct in `PlantReminderDetailView.swift` is removed.
- [ ] Issue #274 will close automatically when the maintainer merges.

## Notes for the implementer

- **Working branch is `feat/issue-274-reminder-editing`** — already created with the design spec committed (`e03b71e`). Do not re-branch.
- **`swift test` runs locally** on this machine (Mac mini Pro / gateway). Do not SSH to mac-mini for unit tests. UI tests / `xcodebuild test` still need mac-mini, but this plan doesn't add UI tests.
- **One commit per task.** Each task is a logically complete change with its own commit message; that lets us roll back individual steps if needed.
- **SwiftFormat may rewrite test method names that start with `test`.** Don't fight it — adjust test names so they don't start with `test` (e.g., `mutatesEditableFields` not `testMutatesEditableFields`). Swift Testing's `@Test` attribute is what matters, not the method-name prefix.
- **If a build fails because of a `EditReminderView` name collision** (Task 7 → Task 9 transition), confirm the placeholder rename in PlantReminderDetailView.swift was applied, or apply it now: `struct EditReminderView` → `struct EditReminderViewPlaceholder`, plus the corresponding constructor call. The placeholder is fully removed in Task 9 so this rename is short-lived.
- **The `calculateNextDueDate(...)` private helper exists in ReminderService.swift.** Find the exact signature with `grep -n "private func calculateNextDueDate" GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift`. The plan's call uses the parameters that helper expects today; verify before pasting.
