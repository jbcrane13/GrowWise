# PRD #256: Cannot Add or Delete Garden

## Issue
Since the UI refresh, users cannot add or delete gardens in Cultivation (GrowWise).

## Root Cause
1. **Add garden**: The "New Garden" (`+`) button only appears in `gardenPicker`, which is gated by `viewModel.gardens.count > 1`. If user has 0 or 1 garden, the picker row is hidden — no way to add a garden.
2. **Delete garden**: The `gardenToDelete` state exists and the alert confirmation is wired up, but no UI trigger sets it. The garden picker chips have no long-press, swipe, or context menu to initiate deletion.

## Files to Modify
- `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenView.swift` — main view

## Tasks

### T1: Make "Add Garden" always accessible
- If `gardens.count == 0`: Show the "Add Plant" empty state but also add a "Create Garden" CTA button before it (can't add plants without a garden)
- If `gardens.count == 1`: Show the gardenPicker row (removes the `count > 1` gate). The single garden chip + "New" `+` button should always be visible.
- If `gardens.count > 1`: Already works (picker is shown). No change needed.
- **Approach**: Change the condition from `count > 1` to `count >= 1`, and add a "Create Garden" button in the empty state for `count == 0`.

### T2: Add garden delete interaction
- Add `.contextMenu` to each garden picker chip with a "Delete Garden" option
- Tapping "Delete Garden" sets `gardenToDelete` and `showDeleteConfirmation = true`
- The existing alert and `viewModel.deleteGarden()` call handles the rest
- Do NOT allow deleting the last garden without at least one other garden existing (guard: `viewModel.gardens.count > 1`)
- Add appropriate accessibility identifiers: `garden_context_delete`, `garden_picker_chip_{name}`

### T3: Verify
- Build: `xcodebuild -project GrowWise.xcodeproj -scheme GrowWise -destination 'generic/platform=iOS Simulator' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
- The existing tests should pass
- Manual verification: garden picker shows for 1+ gardens, add button works, context menu delete works

## Constraints
- Follow existing CultivationTheme design tokens (colors, fonts, spacing, radius)
- Use existing animation patterns (`CultivationTheme.Animation.selection`)
- Use `.buttonStyle(.plain)` on all custom buttons
- Add accessibility identifiers following `{screen}_{element}_{descriptor}` snake_case convention
- Do not modify `GardenViewModel` or `DataService` — the create/delete logic already works
- Swift 6 strict concurrency — no Sendable violations

## Definition of Done
- [ ] "Add Garden" is accessible when 0 gardens exist
- [ ] "Add Garden" is accessible when 1 garden exists (gardenPicker always visible)
- [ ] Garden picker chips have context menu with "Delete Garden"
- [ ] Cannot delete the only remaining garden
- [ ] Build succeeds for iOS Simulator target
- [ ] Accessibility identifiers added
