# Issues #271 + #272 — Full club sharing (photo + club selection + CloudKit publish)

**Date:** 2026-05-01
**Issues:**
- [#271](https://github.com/jbcrane13/GrowWise/issues/271) — Club sharing is partial — no photo picker, no club selection, no CloudKit publish path
- [#272](https://github.com/jbcrane13/GrowWise/issues/272) — Club feed photos are gradient placeholders, not real images
**Type:** bug, priority:high
**Author:** Blake Crane

## Problem

The Garden Club share flow ships incomplete:

- **#271** — `ClubShareComposerSheet` only writes a SwiftData record via `dataService.createClubPost(...)`. It has no photo picker, no UI for choosing which club to post to (always uses `fetchPrimaryClub()`), and never publishes to CloudKit. So when User A posts, User B in the same club never sees the post.
- **#272** — `GardenClubFeedView`'s `PostCard` ignores any photo data and renders a hardcoded coral/leaf gradient rectangle for every post. The comment at line 469 acknowledges this: `// Photo placeholder — wire to PhotoService asset URL when available`.

These are coupled — fixing #271 alone produces posts with photos that the feed can't display, and fixing #272 alone produces a feed that looks for photos posts never carried.

The PR description for #271 said "this is a central piece of branding — get it right". We're treating the pair as a single feature that delivers actual cross-device club sharing.

## Goals

1. Add a single-photo picker to `ClubShareComposerSheet` and persist the photo locally + ship it to CloudKit so other club members see it.
2. Add a multi-club selector when the user is in 2+ clubs; auto-select the primary club when in 1; show an empty-state CTA when in 0 clubs.
3. Render real photos in `GardenClubFeedView`'s `PostCard`, sourcing from either a local file (author's own posts) or a CKAsset (posts from other club members).
4. Soft-fail CloudKit publish errors: local post sticks, banner tells the user it'll sync later.

## Non-Goals

- **Multi-photo posts.** Single photo per post for v1; carousel UX deferred.
- **Editing or deleting posts.** Composer is create-only.
- **Photo zoom / full-screen viewer.** PostCard renders inline at fixed height.
- **Comments / likes.** Long-standing TODO, not part of #271/#272.
- **Web/Android cross-platform sync.** CloudKit is iOS/macOS only.
- **Migrating legacy CKRecords to add a `photoAsset` field.** No legacy records exist; the field is additive.

## Decisions

- **Single photo per post.** Confirmed in brainstorming.
- **Soft-fail on CloudKit publish error.** Local SwiftData save commits regardless; CloudKit retry happens later (manual via re-opening the feed, which calls `load()` and re-merges). Banner message: "Posted locally — will sync when iCloud is available".
- **Hide club selector when in exactly 1 club.** When in 2+ clubs, show a horizontal `GlassPill` row at the top of the composer; default selection = first club. When in 0 clubs, replace the entire form with a "Join or create a club first" CTA.
- **Photo storage:** local copy in `Documents/ClubPostPhotos/{activity.id}.jpg` (relative path stored in `activity.photoURL`), and a `CKAsset` attached to the CloudKit record under field key `photoAsset`. Author sees the local file; other members see the CKAsset.
- **Photo cap:** ~1.5MB JPEG, max 1920px on the longest dimension. Compression service progressively lowers quality from 0.8 → 0.3 until the size cap is satisfied. CKAsset's hard limit is ~5MB; we leave generous headroom.
- **`ClubActivity` model gains no new fields.** The existing `photoURL: String?` field is repurposed to hold a documents-relative path. Schema unchanged → no SwiftData migration.

## Composer flow (`ClubShareComposerSheet`)

### Empty state — 0 clubs

Replace the entire `scrollContent` with a centered VStack:

- Icon: `person.3.sequence`, sized 56pt
- Headline: "Join a club to share"
- Body: "Garden Clubs let you swap photos and tips with other gardeners. Create your own or join one with an invite code."
- Primary button: "Create or Join a Club" → `dismiss()` and (where the sheet is presented from) routes to `CreateClubSheet` via the existing `ProfileView → Garden Clubs` path. The composer doesn't navigate directly; it just dismisses with a callback signal that the parent can act on. New `onRequestCreateClub: () -> Void = {}` init parameter lets the caller wire it; default no-op preserves backwards compatibility.
- Accessibility ids: `share_composer_emptystate_icon`, `share_composer_emptystate_button_create`.

### Club selector — 2+ clubs

Above the photo section, a horizontal `ScrollView`:

```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 8) {
        ForEach(availableClubs, id: \.id) { club in
            GlassPill(
                label: club.name ?? "Club",
                isSelected: selectedClubID == club.id,
                accessibilityID: "share_composer_pill_club_\(club.id?.uuidString ?? "unknown")"
            ) {
                if let id = club.id { selectedClubID = id }
            }
        }
    }
    .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
}
```

The header text shifts to "Share with your clubs" when 2+ clubs; "Share with {clubName}" when exactly 1.

### Photo section

New section above the caption:

```swift
PhotosPicker(
    selection: $selectedPhotoItem,
    matching: .images
) {
    if let preview {
        Image(uiImage: preview)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("share_composer_image_preview")
            .overlay(alignment: .topTrailing) {
                Button {
                    selectedPhotoItem = nil
                    selectedPhotoData = nil
                    preview = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(CultivationTheme.Colors.statusAlert)
                        .background(Circle().fill(.white))
                }
                .padding(4)
                .accessibilityIdentifier("share_composer_button_clearphoto")
            }
    } else {
        VStack(spacing: 4) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 24))
            Text("Add Photo")
                .font(CultivationTheme.Fonts.body(11))
        }
        .frame(width: 100, height: 100)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(CultivationTheme.Colors.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .accessibilityIdentifier("share_composer_button_addphoto")
    }
}
.onChange(of: selectedPhotoItem) { _, newItem in
    Task<Void, Never> {
        guard let newItem,
              let data = try? await newItem.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        await MainActor.run {
            selectedPhotoData = data
            preview = uiImage
        }
    }
}
```

Required new state:
```swift
@State private var selectedPhotoItem: PhotosPickerItem?
@State private var selectedPhotoData: Data?
@State private var preview: UIImage?
```

### Soft-fail CloudKit warning banner

Add `@State private var showCloudKitWarning = false` and an alert:

```swift
.alert("Posted locally", isPresented: $showCloudKitWarning) {
    Button("OK", role: .cancel) { showCloudKitWarning = false }
} message: {
    Text("Your post will sync to your club when iCloud is available.")
}
```

### `submitPost()` rewrite

```swift
@MainActor
private func submitPost() async {
    let trimmed = caption.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }

    isPosting = true
    defer { isPosting = false }

    // 1. Compress photo if present.
    let photoToShip: ClubPostPhoto?
    if let data = selectedPhotoData, let image = UIImage(data: data) {
        guard let compressed = PhotoCompressionService.compressForCloudKit(image) else {
            errorMessage = "Couldn't process photo."
            showError = true
            return
        }
        let activityID = UUID()  // Pre-generate so the file path matches the activity ID we'll set below.
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("\(activityID).jpg")
        do {
            try compressed.write(to: temp)
        } catch {
            errorMessage = "Couldn't save photo: \(error.localizedDescription)"
            showError = true
            return
        }
        photoToShip = ClubPostPhoto(data: compressed, filename: "\(activityID).jpg", temporaryFileURL: temp, activityID: activityID)
    } else {
        photoToShip = nil
    }

    // 2. Local save (hard-fail on error).
    let activity: ClubActivity
    do {
        activity = try dataService.createClubPost(
            caption: trimmed,
            activityType: "shared",
            plantName: resolvedPlantName,
            photo: photoToShip,
            clubID: selectedClubID
        )
    } catch {
        errorMessage = error.localizedDescription
        showError = true
        return
    }

    // 3. CloudKit publish (soft-fail on error).
    do {
        try await clubCloudKitService.publishActivity(activity, photo: photoToShip)
    } catch {
        showCloudKitWarning = true
        // Fall through to dismiss — local post stuck.
    }

    onPost()
    dismiss()
}
```

Note: `dataService.createClubPost(...)` accepts the photo and writes it to documents. The temp file is just for the CKAsset upload.

## Service layer changes

### `ClubPostPhoto` (new file `Sources/GrowWiseServices/ClubPostPhoto.swift`)

```swift
import Foundation

public struct ClubPostPhoto: Sendable {
    public let data: Data
    public let filename: String
    public let temporaryFileURL: URL
    public let activityID: UUID

    public init(data: Data, filename: String, temporaryFileURL: URL, activityID: UUID) {
        self.data = data
        self.filename = filename
        self.temporaryFileURL = temporaryFileURL
        self.activityID = activityID
    }
}
```

The `activityID` ensures the local file path uses the same UUID the activity will use, so they stay in sync.

### `PhotoCompressionService` (new file `Sources/GrowWiseServices/PhotoCompressionService.swift`)

```swift
#if canImport(UIKit)
import UIKit

public enum PhotoCompressionService {
    public static let maxBytes = 1_500_000   // ~1.5MB
    public static let maxDimension: CGFloat = 1920

    /// Returns JPEG-encoded data within `maxBytes`, downscaled to `maxDimension`.
    /// Returns `nil` only if the image cannot be drawn at all.
    public static func compressForCloudKit(_ image: UIImage) -> Data? {
        let resized = downscale(image, maxDimension: maxDimension)
        for quality in stride(from: 0.8, through: 0.3, by: -0.1) {
            if let data = resized.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
        }
        return resized.jpegData(compressionQuality: 0.3)  // last resort, may exceed cap
    }

    static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
#endif
```

`#if canImport(UIKit)` because the package's macOS target shouldn't compile UIKit. Tests live behind the same conditional.

### `DataService.createClubPost` extended signature

In `Sources/GrowWiseServices/DataService+GardenClub.swift`, replace the existing method with:

```swift
@discardableResult
@MainActor
func createClubPost(
    caption: String,
    activityType: String,
    plantName: String? = nil,
    photo: ClubPostPhoto? = nil,
    clubID: UUID? = nil
) throws -> ClubActivity {
    // 1. Resolve target club: explicit > primary.
    let targetClub: GardenClub
    if let clubID {
        guard let found = try ClubRepository(context: mainContext).fetch(by: clubID) else {
            throw CreateClubPostError.noClub
        }
        targetClub = found
    } else {
        guard let primary = fetchPrimaryClub() else {
            throw CreateClubPostError.noClub
        }
        targetClub = primary
    }
    guard let resolvedClubID = targetClub.id else {
        throw CreateClubPostError.noClub
    }

    // 2. Build description.
    let user = getCurrentUser()
    let memberName = user?.displayName ?? "Gardener"
    let memberID = user?.id.uuidString ?? UUID().uuidString
    let description: String = if let plantName {
        "\(plantName): \(caption)"
    } else {
        caption
    }

    // 3. Construct activity. Use photo's activityID if provided so the file path matches.
    let activity = ClubActivity(
        clubID: resolvedClubID,
        memberName: memberName,
        memberID: memberID,
        activityType: activityType,
        description: description
    )
    if let photo {
        activity.id = photo.activityID
    }

    // 4. If photo provided, write to documents/ClubPostPhotos/{id}.jpg.
    if let photo {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("ClubPostPhotos", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(photo.filename)
        do {
            try photo.data.write(to: dest)
            activity.photoURL = "ClubPostPhotos/\(photo.filename)"
        } catch {
            // Don't block local save on photo write — but record nothing if write fails.
            activity.photoURL = nil
        }
    }

    // 5. Persist.
    let repo = ClubActivityRepository(context: mainContext)
    do {
        try repo.save(activity)
    } catch {
        // If save failed, clean up any photo we just wrote.
        if let photoURL = activity.photoURL {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let toDelete = docs.appendingPathComponent(photoURL)
            try? FileManager.default.removeItem(at: toDelete)
        }
        throw error
    }

    return activity
}
```

`ClubRepository.fetch(by:)` does not currently exist — verify and add if missing. (Check with `grep -n "fetch(by:" GrowWisePackage/Sources/GrowWiseServices/Repositories/ClubRepository.swift`. If absent, add a one-liner.)

### `ClubCloudKitService.publishActivity` extended signature

In `Sources/GrowWiseServices/ClubCloudKitService.swift`, change:

```swift
public func publishActivity(_ activity: ClubActivity, photo: ClubPostPhoto? = nil) async throws {
    try await requireAvailableAccount()

    guard let clubID = activity.clubID else { throw ClubCloudKitError.missingIdentifier }
    guard let activityID = activity.id else { throw ClubCloudKitError.missingIdentifier }

    let zoneName = CloudKitSchema.Zone.gardenClub
    let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    let recordID = CKRecord.ID(recordName: activityID.uuidString, zoneID: zoneID)

    let record = CKRecord(recordType: CloudKitSchema.RecordType.clubActivity, recordID: recordID)
    record["clubID"] = clubID.uuidString
    record["memberName"] = activity.memberName ?? ""
    record["memberID"] = activity.memberID ?? ""
    record["activityType"] = activity.activityType ?? ""
    record["activityDescription"] = activity.activityDescription ?? ""
    record["gardenName"] = activity.gardenName ?? ""
    record["timestamp"] = activity.timestamp ?? Date()
    if let photo {
        record["photoAsset"] = CKAsset(fileURL: photo.temporaryFileURL)
    }

    do {
        _ = try await privateDatabase.save(record)
        logger.info("Published activity \(activityID.uuidString) to shared zone")
    } catch {
        logger.error("Failed to publish activity: \(error.localizedDescription)")
        throw ClubCloudKitError.saveFailed(error.localizedDescription)
    }
}
```

The CKAsset is attached only when `photo != nil`. Field key `photoAsset` is the contract — read side uses the same key.

## Feed display changes (`GardenClubFeedView`)

### `ClubActivityViewData` adds `photoFileURL`

```swift
struct ClubActivityViewData: Identifiable {
    let id: UUID
    let authorDisplayName: String
    let caption: String?
    let zoneTag: String?
    let relativeTimeLabel: String?
    let likeCount: Int
    let commentCount: Int
    let photoFileURL: URL?           // NEW
}
```

### `viewData(from activity:)` resolves the local path

```swift
private static func viewData(from activity: ClubActivity) -> ClubActivityViewData {
    let id = activity.id ?? UUID()
    let author = activity.memberName ?? "Member"
    let caption = activity.activityDescription
    let label: String?
    if let timestamp = activity.timestamp {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        label = formatter.localizedString(for: timestamp, relativeTo: .now)
    } else {
        label = nil
    }
    let photoFileURL: URL? = {
        guard let path = activity.photoURL, !path.isEmpty else { return nil }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent(path)
    }()
    return ClubActivityViewData(
        id: id,
        authorDisplayName: author,
        caption: caption,
        zoneTag: nil,
        relativeTimeLabel: label,
        likeCount: 0,
        commentCount: 0,
        photoFileURL: photoFileURL
    )
}
```

### `viewData(from record:)` reads the CKAsset

```swift
private static func viewData(from record: CKRecord) -> ClubActivityViewData {
    let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
    let author = record["memberName"] as? String ?? "Member"
    let caption = record["activityDescription"] as? String
    let timestamp = record["timestamp"] as? Date
    let label: String?
    if let timestamp {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        label = formatter.localizedString(for: timestamp, relativeTo: .now)
    } else {
        label = nil
    }
    let photoFileURL = (record["photoAsset"] as? CKAsset)?.fileURL
    return ClubActivityViewData(
        id: id,
        authorDisplayName: author,
        caption: caption,
        zoneTag: nil,
        relativeTimeLabel: label,
        likeCount: 0,
        commentCount: 0,
        photoFileURL: photoFileURL
    )
}
```

### `PostCard` body update

Replace the existing gradient block (lines 469-476) with:

```swift
if post.photoFileURL != nil {
    ClubPostPhotoView(url: post.photoFileURL)
}
```

The conditional avoids showing the placeholder for posts without photos (legacy or photo-less new posts).

### `ClubPostPhotoView` (file-scope helper view, in same file as `PostCard`)

```swift
private struct ClubPostPhotoView: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            // Gradient placeholder shown while loading or as fallback.
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [CultivationTheme.Colors.brandLeaf, CultivationTheme.Colors.brandForest],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: url) {
            guard let url else { image = nil; return }
            let loaded = await Task.detached(priority: .userInitiated) {
                UIImage(contentsOfFile: url.path)
            }.value
            await MainActor.run { image = loaded }
        }
    }
}
```

Loading happens off the main thread via `Task.detached`. The gradient stays visible during load (~50ms for typical photos) so the layout doesn't jump.

## Tests

### `ClubSharingTests` (new, `GrowWiseServicesTests`)

In-memory `DataService.makeForTesting()`. Photos are real (small) JPEGs generated in test setup.

| # | Name | Assertion |
|---|---|---|
| 1 | `createClubPost without photo persists nil photoURL` | `activity.photoURL == nil` |
| 2 | `createClubPost with photo writes file under ClubPostPhotos/` | File exists at `documents/ClubPostPhotos/{photo.filename}`; `activity.photoURL == "ClubPostPhotos/{photo.filename}"` |
| 3 | `createClubPost with photo uses photo.activityID for the activity id` | `activity.id == photo.activityID` |
| 4 | `createClubPost with explicit clubID targets that club` | Two clubs exist; pass clubID of the second; assert `activity.clubID == secondClub.id` |
| 5 | `createClubPost with invalid clubID throws noClub` | Non-existent UUID → throws `CreateClubPostError.noClub` |
| 6 | `createClubPost falls back to primary when clubID is nil` | Single club exists; `clubID = nil`; assert `activity.clubID == primary.id` (existing behavior preserved) |
| 7 | `createClubPost throws when no clubs exist and clubID is nil` | Existing test — preserve |

### `PhotoCompressionTests` (new, `GrowWiseServicesTests`)

`#if canImport(UIKit)` guarded. Generate test images with `UIGraphicsImageRenderer`.

| # | Name | Assertion |
|---|---|---|
| 1 | `compressForCloudKit returns data within 1.5MB cap for typical photo` | Generate solid-color 3000x2000 image (compresses very well to start, but assert size constraint holds) |
| 2 | `compressForCloudKit downscales when longest dimension exceeds 1920px` | Generate 4000x3000 image; decode result; assert `max(decoded.size.width, decoded.size.height) == 1920` |
| 3 | `compressForCloudKit returns non-nil for tiny image` | 100x100 image → non-nil data |
| 4 | `compressForCloudKit preserves aspect ratio when downscaling` | Generate 4000x3000; result aspect ratio matches 4:3 within rounding |

### `GardenClubFeedViewMappingTests` (new, `GrowWiseFeatureTests`)

Tests the static mapping helpers. CKRecord cannot be constructed in unit tests easily (no entitlements), so we test only the `ClubActivity → ViewData` path.

| # | Name | Assertion |
|---|---|---|
| 1 | `viewData(from:) maps photoURL to documents-relative file URL` | Activity with `photoURL = "ClubPostPhotos/abc.jpg"` → `result.photoFileURL?.path` ends in `/Documents/ClubPostPhotos/abc.jpg` |
| 2 | `viewData(from:) returns nil photoFileURL when photoURL is nil` | `result.photoFileURL == nil` |
| 3 | `viewData(from:) returns nil photoFileURL when photoURL is empty` | `result.photoFileURL == nil` |
| 4 | `viewData(from:) preserves caption, author, timestamp` | Existing fields still populated correctly (regression guard) |

To make these tests reachable, expose `viewData(from activity:)` as `internal static` (currently `private static`). The shorter-term option is a `@testable import GrowWiseFeature` + visibility shim.

### Manual smoke (post-merge, on mac-mini sim)

CloudKit publish/fetch can't be unit-tested without entitlements. Required manual smoke:

1. Sign into iCloud on the simulator.
2. Open Club tab → tap "Share" → pick a photo from Photos library → write caption → tap Post → confirm sheet dismisses.
3. Confirm post appears in feed with the actual photo (not a gradient).
4. Force-quit the app, relaunch — post still in feed (CloudKit roundtrip).
5. From a second iCloud account on a second simulator, confirm the post appears in the same club.
6. With airplane mode on, post a photo — confirm "Posted locally" banner, post appears in feed.

## File inventory

**New (5):**
- `GrowWisePackage/Sources/GrowWiseServices/ClubPostPhoto.swift`
- `GrowWisePackage/Sources/GrowWiseServices/PhotoCompressionService.swift`
- `GrowWisePackage/Tests/GrowWiseServicesTests/ClubSharingTests.swift`
- `GrowWisePackage/Tests/GrowWiseServicesTests/PhotoCompressionTests.swift`
- `GrowWisePackage/Tests/GrowWiseFeatureTests/GardenClubFeedViewMappingTests.swift`

**Modified (4):**
- `GrowWisePackage/Sources/GrowWiseServices/DataService+GardenClub.swift` (rewrite `createClubPost`)
- `GrowWisePackage/Sources/GrowWiseServices/ClubCloudKitService.swift` (add `photo:` parameter to `publishActivity`)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubShareComposerSheet.swift` (photo picker, club selector, soft-fail flow, empty state)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/GardenClubFeedView.swift` (`photoFileURL` on view data, `ClubPostPhotoView`, conditional render in `PostCard`)

## Verification

| Step | Command / check |
|---|---|
| 1 | `swift build --package-path GrowWisePackage` succeeds |
| 2 | `swiftlint lint --strict --config .swiftlint.yml` reports 0 new violations on touched files |
| 3 | `swift test --package-path GrowWisePackage --filter "ClubSharingTests\|PhotoCompressionTests\|GardenClubFeedViewMappingTests"` — all pass |
| 4 | Full suite green: `swift test --package-path GrowWisePackage` |
| 5 | Manual smoke (mac-mini sim): the 6 steps above |

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| CKAsset's 5MB hard cap | `PhotoCompressionService` enforces 1.5MB cap before publish |
| Documents file orphaned if SwiftData save fails | `createClubPost` cleans up the file in the `catch` branch |
| `PhotoCompressionService` requires UIKit; macOS package target may not build it | `#if canImport(UIKit)` guard + tests under same guard. Macoa target compilations succeed because UIKit isn't imported there. |
| `ClubCloudKitService` has no protocol → can't unit-test publish | CloudKit publish is exercised manually only; unit tests cover the local persistence and compression pieces |
| Two posts in the same instant collide on filename | Filename uses `{activity.id}.jpg` where id is a fresh UUID — collision-resistant |
| `ClubRepository.fetch(by:)` may not exist | Plan instructs the implementer to grep and add it as a one-liner if absent |
| Existing legacy `ClubActivity` records have `photoURL == nil` | The conditional `if post.photoFileURL != nil` in PostCard ensures legacy posts render without the photo block, no visible regression |
| `ClubChat` already uses PhotosPicker | Unrelated code path; we mirror the picker pattern but route to club post, not chat message |
| Two devices simultaneously publish same `activity.id` | `id` is a fresh UUID per `ClubActivity` init — collision odds negligible |

## Sequencing

Independent of #275/#274. Recommended order in queue: after #277 (#275 lint guard) and #281 (#274 reminder edit) merge — but no hard dependency.
