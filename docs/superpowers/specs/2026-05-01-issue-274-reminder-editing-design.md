# Issue #274 — Full reminder editing

**Date:** 2026-05-01
**Issue:** [#274](https://github.com/jbcrane13/GrowWise/issues/274) — Reminder edit opens Coming Soon dead end
**Type:** bug, priority:high
**Author:** Blake Crane

## Problem

Tapping a reminder's edit affordance in `PlantReminderDetailView` presents an `EditReminderView` whose body is the literal text "Edit Reminder - Coming Soon". The Save button does nothing useful (calls `onSave()` and dismisses without applying any changes), the Cancel button works but provides no value, and the user has no way to modify a reminder once created. Source: `PlantReminderDetailView.swift:680-708`.

The PR description for the fix offered two options — implement editing, or remove the affordance. We chose to **implement editing fully** (no schedule pressure, sharing/care features are core to the product, and the existing data model already supports every editable field).

## Goals

1. Replace the placeholder `EditReminderView` with a working form that lets users modify a reminder's editable fields and persist the change.
2. Reschedule the local notification when changes affect timing or enablement.
3. Cover the new behavior with unit tests at the service layer and a small mapping test at the view layer.

## Non-Goals

- Changing the plant a reminder is attached to. (Plant is fixed; users wanting to point at a different plant create a new reminder and delete the old one.)
- Snooze-count or `maxSnoozeCount` editing — these are runtime-managed.
- Per-reminder quiet hours overrides — the global `ReminderSettings.quietHours*` continues to apply.
- Bulk multi-reminder edit.

## Decisions

- **Plant fixed.** Edit form shows the plant as a read-only header (icon + name + type), no picker. Confirmed in brainstorming.
- **Single service entry point.** A new `ReminderService.updateReminder(...)` owns mutation, schedule recalc, and notification rescheduling. The view does not touch SwiftData or `NotificationService` directly.
- **`isEnabled` toggle.** The model already exposes `isEnabled`, the home/list filters already respect it, but no UI surface lets a user pause a reminder. Add a "Pause Reminder" toggle (inverted to `isEnabled`).
- **Delete inside the form.** EditReminderView keeps its existing `onDelete` callback contract; the parent `PlantReminderDetailView` continues to own the destructive-confirmation alert via the same `showingDeleteConfirmation` plumbing it already has. EditReminderView calls `onDelete(reminder); dismiss()` and lets the parent handle the alert.
- **No bundled refactor of `AddReminderView`.** Tempting to extract a shared `ReminderFormView`, but that's scope creep beyond a P1 bug fix. EditReminderView is its own file mirroring AddReminderView's structure; the duplication is manageable and a future refactor can DRY them in one PR.

## Editable fields

| Field | UI | Save behavior |
|---|---|---|
| Reminder type | Horizontal `GlassPill` row over `ReminderType.allCases` | Mutate `reminder.reminderType`. If the user-edited message is empty *and* the type changed, prefill `reminder.message` with the new type's `defaultMessage` so the body never references the prior type. |
| Frequency | `GlassPill` row over `[.daily, .everyOtherDay, .twiceWeekly, .weekly, .biweekly, .monthly, .custom]` (matches AddReminderView) | Mutate `reminder.frequency` and `baseFrequencyDays = frequency.days`. |
| Custom days | TextField shown only when `frequency == .custom`, validated `Int >= 1` | Mutate `reminder.customFrequencyDays`. |
| Preferred time | `DatePicker(displayedComponents: .hourAndMinute)` | Mutate `reminder.preferredNotificationTime`. |
| Priority | `GlassPill` row over `ReminderPriority.allCases` | Mutate `reminder.priority`. |
| Smart weather adjustment | `Toggle` | Mutate `reminder.enableWeatherAdjustment`. |
| Title | `ValidatedTextField` (1–100 chars; non-blank) | Mutate `reminder.title`. |
| Message | `TextEditor` (≤500 chars; clamped on input like AddReminderView does) | Mutate `reminder.message`. |
| Active (`isEnabled`) | "Pause Reminder" toggle (inverted: `isPaused = !isEnabled`) | Mutate `reminder.isEnabled`. Also drives notification reschedule (cancel on disable; schedule on re-enable). |

The plant header above the form is read-only and uses the same `IconBubble` + name + type treatment as `AddReminderView`'s `plantSelectionSection` (sans the "Change" button).

## Service-layer change

### New method

```swift
@MainActor
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
) async throws
```

Located adjacent to `updateWateringSchedule(...)` at `ReminderService.swift:136`.

### Algorithm

1. **Validate inputs.**
   - `title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty` → throw `ReminderError.emptyTitle`.
   - `frequency == .custom && (customFrequencyDays ?? 0) < 1` → throw `ReminderError.invalidCustomFrequency`.
2. **Snapshot pre-mutation state** for change-detection:
   - `frequencyChanged = reminder.frequency != frequency || reminder.customFrequencyDays != customFrequencyDays`
   - `timeChanged = reminder.preferredNotificationTime != preferredTime`
   - `enableStateChanged = reminder.isEnabled != isEnabled`
3. **Resolve effective message.** If `reminder.reminderType != type && message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`, use `type.defaultMessage` as the effective message. Otherwise use `message` as supplied. (This is what the "type changes ⇒ default-message prefill if empty" rule in the editable-fields table maps to.)
4. **Mutate the model:** assign `title`, the effective message from step 3, `reminderType = type`, `frequency`, `baseFrequencyDays = frequency.days`, `customFrequencyDays`, `preferredNotificationTime = preferredTime`, `priority`, `enableWeatherAdjustment`, `isEnabled`, `lastModified = Date()`.
5. **Recalculate `nextDueDate`** if `frequencyChanged || timeChanged`. Use the existing private `calculateNextDueDate(...)` helper that already powers `createSmartReminder`. This preserves weather adjustment for users who have it enabled.
6. **Reschedule notification:**
   - `if !isEnabled` → `await notificationService.cancelReminderNotification(for: reminder.id)`.
   - `else if frequencyChanged || timeChanged || enableStateChanged` → cancel + `try await notificationService.scheduleReminderNotification(for: reminder)`. Cancel covers the case where the prior identifier had different timing data.
7. **Save context:** `try dataService.modelContext.save()`.

### New `ReminderError` cases

Add to the existing enum at `ReminderService.swift:1017`:

```swift
case emptyTitle
case invalidCustomFrequency
```

With matching `errorDescription` strings ("Reminder title cannot be empty.", "Custom frequency requires at least 1 day.").

## View-layer change

### New file: `EditReminderView.swift`

Mirrors `AddReminderView`'s file structure. High-level outline:

```swift
public struct EditReminderView: View {
    let reminder: PlantReminder
    let reminderService: ReminderService
    let onSave: () -> Void
    let onDelete: (PlantReminder) -> Void

    @Environment(\.dismiss) private var dismiss

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

    // body: { plantHeader; reminderTypeSection; frequencySection; timingSection; prioritySection; customContentSection; pauseSection; deleteButton }
    // toolbar: Cancel (leading), Save (primaryAction)
}
```

### `EditReminderView.FormState`

A nested value type that owns the reminder → initial-state mapping, so the mapping is unit-testable without rendering SwiftUI:

```swift
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

### Save handler

```swift
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
```

### Delete handler

```swift
private func deleteReminder() {
    onDelete(reminder)
    dismiss()
}
```

### Removal in `PlantReminderDetailView`

Delete the placeholder struct (`PlantReminderDetailView.swift:680-708`) and its leading comment. The existing `.sheet(item: $selectedReminder)` plumbing already constructs the new `EditReminderView` with the same signature, so no other changes are needed in that file.

## Tests

### `ReminderServiceUpdateTests` (new, `GrowWiseServicesTests`)

In-memory `DataService` via `makeForTesting()`. Notification effects are asserted via a test double passed to `ReminderService.init`. The double conforms to whatever protocol `NotificationService` exposes today — verify in implementation.

| # | Name | Assertion |
|---|---|---|
| 1 | `updateReminder mutates editable fields` | All passed-in fields land on the model. |
| 2 | `updateReminder recalculates nextDueDate when frequency changes` | `nextDueDate` differs from pre-call value. |
| 3 | `updateReminder leaves nextDueDate alone when only title changes` | `nextDueDate` exactly equal to pre-call value. |
| 4 | `updateReminder applies custom frequency days` | `frequency == .custom`, `baseFrequencyDays == 3`, `customFrequencyDays == 3`. |
| 5 | `updateReminder rejects invalid custom days` | Throws `ReminderError.invalidCustomFrequency` for `0` and `nil`. |
| 6 | `updateReminder rejects empty title` | Throws `ReminderError.emptyTitle` for `""` and `"   "`. |
| 7 | `updateReminder cancels notification when disabled` | Double records exactly one cancel; zero schedule calls. |
| 8 | `updateReminder reschedules when frequency changes and enabled` | Double records cancel + schedule, in that order. |
| 9 | `updateReminder schedules notification when re-enabled from disabled` | Double records schedule call. |
| 10 | `updateReminder updates lastModified` | `lastModified` strictly later than pre-call value. |
| 11 | `updateReminder prefills message when type changes and message is empty` | New message equals the new type's `defaultMessage`. (Bonus assertion to lock in the type-change UX behavior described above.) |

### `EditReminderViewTests` (new, `GrowWiseFeatureTests`)

| # | Name | Assertion |
|---|---|---|
| 1 | `FormState.initial maps all editable fields` | Each of title/message/type/frequency/customDays/preferredTime/priority/enableWeatherAdjustment/isEnabled equals the source reminder's value. |
| 2 | `FormState.initial uses nextDueDate when preferredNotificationTime is nil` | Source has `preferredNotificationTime = nil`; result has `preferredTime == reminder.nextDueDate`. |
| 3 | `FormState.initial defaults customDays to frequency.days when nil` | Source has `frequency = .weekly`, `customFrequencyDays = nil`; result has `customDays == 7`. |
| 4 | `FormState.initial preserves customDays when set` | Source has `customFrequencyDays = 5`; result has `customDays == 5`. |

## Verification

| Step | Command / check |
|---|---|
| 1 | `swift build --package-path GrowWisePackage` succeeds |
| 2 | `swiftlint lint --strict --config .swiftlint.yml` reports 0 new violations |
| 3 | `swift test --package-path GrowWisePackage --filter ReminderServiceUpdateTests` — 11/11 pass |
| 4 | `swift test --package-path GrowWisePackage --filter EditReminderViewTests` — 4/4 pass |
| 5 | Full suite green: `swift test --package-path GrowWisePackage` |
| 6 | Manual smoke (mac-mini sim) — open Plants → tap a plant with a reminder → tap the gear icon on a reminder → form shows current values → change frequency to "Daily" → Save → list shows updated due date and frequency. Then re-open, toggle "Pause Reminder" → Save → list shows the reminder grayed out (existing `opacity(0.6)` behavior on `isEnabled == false`). Then re-open and tap "Delete Reminder" → confirmation alert (parent's existing alert) → Delete → list updates. |

## File inventory

**New (3):**
- `GrowWisePackage/Sources/GrowWiseFeature/Views/EditReminderView.swift`
- `GrowWisePackage/Tests/GrowWiseServicesTests/ReminderServiceUpdateTests.swift`
- `GrowWisePackage/Tests/GrowWiseFeatureTests/EditReminderViewTests.swift`

**Modified (2):**
- `GrowWisePackage/Sources/GrowWiseServices/ReminderService.swift` — add `updateReminder(...)` (~50 lines) and 2 `ReminderError` cases (~2 lines)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/PlantReminderDetailView.swift` — delete placeholder struct at lines 680-708 (-28 lines)

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| `NotificationService` test-double doesn't exist; existing tests may inject the real service. | Inspect the existing `ReminderServiceTests` setup; reuse whatever fake/spy pattern they already use (likely a `MockNotificationService` of some kind). If none exists, the cancel/schedule assertions can fall back to verifying state changes on the reminder (e.g., that `nextDueDate` got recalculated) — covers the schedule path indirectly. |
| `cancelReminderNotification(for:)` takes a `UUID` (`reminder.id`); passing the reminder model is wrong. | Use the existing API — `await notificationService.cancelReminderNotification(for: reminder.id)`. |
| Saving a reminder with an unchanged `nextDueDate` but rescheduled notification could create timing drift. | Recalc only when `frequencyChanged \|\| timeChanged`. Pure title/message/priority edits leave the schedule untouched. |
| Validation of `customDays` collides with the live TextField input flow (user typing "3" passes through partial states). | Validate at save time only, not on every keystroke. The TextField uses `format: .number` so non-numeric input is already rejected by SwiftUI. |
| The placeholder's `accessibilityIdentifier`s (`plantreminder_button_edit_cancel`, `plantreminder_button_edit_save`) might be referenced by UI tests. | Audit `GrowWiseUITests/` for any reference; preserve those identifiers in the new view, or update the UI tests to the new identifiers if they don't exist there yet. The plan will include this audit step. |

## Sequencing

Independent of #271/#272/#275/#277. Can land in any order. Recommended: after #275 (#277) merges so the SwiftLint rule lands first.
