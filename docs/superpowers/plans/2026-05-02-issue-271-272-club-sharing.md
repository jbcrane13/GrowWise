# Issues #271 + #272 — Full Club Sharing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up real photo sharing in Garden Clubs end-to-end — photo picker in the composer, multi-club selection, CloudKit publish with CKAsset, and real photos displayed in the feed (replacing the gradient placeholder).

**Architecture:** Single-photo per post. Photos compress to ≤1.5MB JPEG (max 1920px) before publish. Local copy lives in `Documents/ClubPostPhotos/{activity.id}.jpg` (relative path stored in `ClubActivity.photoURL`); CloudKit copy travels as a `CKAsset` under field key `photoAsset` on the existing `clubActivity` record. Composer extends `dataService.createClubPost(...)` with a `photo:` parameter (additive) and adds an explicit `clubID:` for multi-club selection. CloudKit publish is soft-fail: local save commits regardless; on CK failure show a "Posted locally" banner. Feed `PostCard` adds a `ClubPostPhotoView` that loads the local file off the main thread and falls back to a gradient placeholder while loading.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, CloudKit (CKAsset on existing `clubActivity` records), `PhotosPicker` (PhotosUI), Swift Testing.

**Working branch:** `feat/issue-271-272-club-sharing` (already created with the design spec committed at `768a42a`).

**Spec:** [`docs/superpowers/specs/2026-05-01-issue-271-272-club-sharing-design.md`](../specs/2026-05-01-issue-271-272-club-sharing-design.md)

---

## File inventory

**Will create (5):**
- `GrowWisePackage/Sources/GrowWiseServices/ClubPostPhoto.swift` (~15 lines)
- `GrowWisePackage/Sources/GrowWiseServices/PhotoCompressionService.swift` (~50 lines)
- `GrowWisePackage/Tests/GrowWiseServicesTests/ClubSharingTests.swift` (~250 lines)
- `GrowWisePackage/Tests/GrowWiseServicesTests/PhotoCompressionTests.swift` (~80 lines)
- `GrowWisePackage/Tests/GrowWiseFeatureTests/GardenClubFeedViewMappingTests.swift` (~100 lines)

**Will modify (4):**
- `GrowWisePackage/Sources/GrowWiseServices/Repositories/ClubRepository.swift` — add `fetch(by:)` (~6 lines, confirmed missing)
- `GrowWisePackage/Sources/GrowWiseServices/DataService+GardenClub.swift` — rewrite `createClubPost` with new signature (~60 lines net)
- `GrowWisePackage/Sources/GrowWiseServices/ClubCloudKitService.swift` — add `photo:` parameter to `publishActivity` (~5 lines)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubShareComposerSheet.swift` — photo picker, club selector, empty state, soft-fail flow (~150 lines net)
- `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/GardenClubFeedView.swift` — `photoFileURL` on view data, `ClubPostPhotoView`, conditional render in `PostCard` (~30 lines net)

**Conventions to follow:**
- New tests use Swift Testing (`@Test`, `@Suite`, `#expect`). Method names must NOT start with `test` (a SwiftFormat hook strips the prefix and breaks `--filter` references).
- Test setup uses `DataService.makeForTesting()`. CloudKit-touching code (anything in `ClubCloudKitService`) cannot be unit-tested without entitlements — covered by manual smoke only.
- Pre-commit hooks run SwiftFormat + SwiftLint and may rewrite your changes. If a commit gets reformatted, that's fine — re-stage and re-commit.
- Run unit tests **locally** with `swift test --package-path GrowWisePackage --filter <FilterName> 2>&1 | tail -10`. Do not SSH to mac-mini for unit tests; do not use `xcodebuild test` on this machine.
- Every new interactive control needs `.accessibilityIdentifier("share_composer_<kind>_<descriptor>")` or the equivalent for feed views.
- Ignore `bd sync` warnings during commits — beads is decommissioned.
- One commit per task; use the exact commit message in each task's "Step N: Commit" block, including the `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` footer.

---

## Task 1: Add `ClubRepository.fetch(by:)`

Tiny prerequisite — `DataService.createClubPost(clubID:)` (Task 4) needs a way to look up a club by UUID. Verified missing.

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/Repositories/ClubRepository.swift`
- Modify: `GrowWisePackage/Tests/GrowWiseServicesTests/ClubSharingTests.swift` (create the file with one test for this method)

- [ ] **Step 1: Create the test file with one failing test**

Create `GrowWisePackage/Tests/GrowWiseServicesTests/ClubSharingTests.swift`:

```swift
import Testing
import Foundation
@testable import GrowWiseServices
@testable import GrowWiseModels

@Suite("Club sharing (photo + multi-club + CloudKit)")
@MainActor
struct ClubSharingTests {
    // MARK: - Helpers

    private func makeService() throws -> DataService {
        try DataService.makeForTesting()
    }

    private func makeClub(in service: DataService, name: String, ownerID: String = "owner-\(UUID())") throws -> GardenClub {
        try service.createClub(name: name, ownerID: ownerID)
    }

    // MARK: - ClubRepository.fetch(by:)

    @Test("ClubRepository.fetch(by:) returns the matching club")
    func fetchByIDReturnsMatchingClub() throws {
        let service = try makeService()
        let club = try makeClub(in: service, name: "Test Club")
        guard let clubID = club.id else {
            Issue.record("Newly created club has no id")
            return
        }
        let repo = ClubRepository(context: service.mainContext)
        let fetched = try repo.fetch(by: clubID)
        #expect(fetched?.id == clubID)
    }

    @Test("ClubRepository.fetch(by:) returns nil for unknown id")
    func fetchByIDReturnsNilForUnknown() throws {
        let service = try makeService()
        let repo = ClubRepository(context: service.mainContext)
        let fetched = try repo.fetch(by: UUID())
        #expect(fetched == nil)
    }
}
```

- [ ] **Step 2: Run the test, expect compile failure**

Run: `swift test --package-path GrowWisePackage --filter ClubSharingTests 2>&1 | tail -10`

Expected: Compile error — `value of type 'ClubRepository' has no member 'fetch'` (the `(by:)` overload).

- [ ] **Step 3: Add `fetch(by:)` to ClubRepository**

Open `GrowWisePackage/Sources/GrowWiseServices/Repositories/ClubRepository.swift`. After `fetchActive()` and before `fetchByInviteCode(...)` (or in the natural slot — keep alphabetical/logical order), add:

```swift
    public func fetch(by id: UUID) throws -> GardenClub? {
        var descriptor = FetchDescriptor<GardenClub>(
            predicate: #Predicate<GardenClub> { club in
                club.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
```

- [ ] **Step 4: Run, expect both tests pass**

Run: `swift test --package-path GrowWisePackage --filter ClubSharingTests 2>&1 | tail -10`

Expected: 2 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/Repositories/ClubRepository.swift \
        GrowWisePackage/Tests/GrowWiseServicesTests/ClubSharingTests.swift
git commit -m "$(cat <<'EOF'
feat(#271): add ClubRepository.fetch(by:) for clubID lookup

Required by the upcoming createClubPost(clubID:) extension so the
composer can target a specific club rather than always falling back
to fetchPrimaryClub().

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add `ClubPostPhoto` value type

Tiny pure-data carrier. No behavior to test — just creates the type the next tasks compile against.

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseServices/ClubPostPhoto.swift`

- [ ] **Step 1: Create the file**

```swift
import Foundation

/// Photo payload accompanying a ClubActivity post.
///
/// Local persistence writes the JPEG bytes to
/// `Documents/ClubPostPhotos/{filename}` and stores the relative path on
/// `ClubActivity.photoURL`. The temporary file URL exists for CloudKit's
/// CKAsset, which requires a `file://` URL on disk.
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

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build --package-path GrowWisePackage 2>&1 | tail -5`

Expected: `Build complete!`.

- [ ] **Step 3: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/ClubPostPhoto.swift
git commit -m "$(cat <<'EOF'
feat(#271): add ClubPostPhoto value type for shared club post media

Sendable carrier holding the compressed JPEG bytes, on-disk filename,
the temp URL CloudKit's CKAsset needs, and the UUID that the consuming
flows use to keep the local file path and ClubActivity.id in sync.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `PhotoCompressionService` + tests

JPEG-encode + downscale a `UIImage` to fit CKAsset's size budget.

**Files:**
- Create: `GrowWisePackage/Sources/GrowWiseServices/PhotoCompressionService.swift`
- Create: `GrowWisePackage/Tests/GrowWiseServicesTests/PhotoCompressionTests.swift`

- [ ] **Step 1: Create the failing tests**

Create `GrowWisePackage/Tests/GrowWiseServicesTests/PhotoCompressionTests.swift`:

```swift
import Testing
import Foundation
@testable import GrowWiseServices

#if canImport(UIKit)
import UIKit

@Suite("PhotoCompressionService")
struct PhotoCompressionTests {
    private func makeImage(width: CGFloat, height: CGFloat, color: UIColor = .systemGreen) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @Test("compressForCloudKit returns non-nil for tiny image")
    func returnsNonNilForTinyImage() throws {
        let img = makeImage(width: 100, height: 100)
        let data = PhotoCompressionService.compressForCloudKit(img)
        #expect(data != nil)
    }

    @Test("compressForCloudKit returns data within the size cap for typical photo")
    func returnsDataWithinSizeCap() throws {
        let img = makeImage(width: 3000, height: 2000)
        let data = try #require(PhotoCompressionService.compressForCloudKit(img))
        #expect(data.count <= PhotoCompressionService.maxBytes)
    }

    @Test("compressForCloudKit downscales when longest dimension exceeds 1920px")
    func downscalesWhenTooLarge() throws {
        let img = makeImage(width: 4000, height: 3000)
        let data = try #require(PhotoCompressionService.compressForCloudKit(img))
        let decoded = try #require(UIImage(data: data))
        let longest = max(decoded.size.width, decoded.size.height)
        #expect(longest <= PhotoCompressionService.maxDimension)
    }

    @Test("compressForCloudKit preserves aspect ratio when downscaling")
    func preservesAspectRatio() throws {
        let img = makeImage(width: 4000, height: 3000)
        let data = try #require(PhotoCompressionService.compressForCloudKit(img))
        let decoded = try #require(UIImage(data: data))
        let originalRatio = 4000.0 / 3000.0
        let resultRatio = decoded.size.width / decoded.size.height
        #expect(abs(resultRatio - originalRatio) < 0.01)
    }
}

#endif
```

- [ ] **Step 2: Run, expect compile failure**

Run: `swift test --package-path GrowWisePackage --filter PhotoCompressionTests 2>&1 | tail -10`

Expected: Compile error — `Cannot find 'PhotoCompressionService' in scope`.

- [ ] **Step 3: Create the service**

Create `GrowWisePackage/Sources/GrowWiseServices/PhotoCompressionService.swift`:

```swift
#if canImport(UIKit)
import UIKit

/// JPEG-compresses and downscales `UIImage` data to fit within CKAsset budget.
///
/// CKAsset's hard limit is ~5MB; we cap at 1.5MB to leave headroom and reduce
/// transfer time. Downscaling preserves aspect ratio.
public enum PhotoCompressionService {
    public static let maxBytes = 1_500_000   // ~1.5MB
    public static let maxDimension: CGFloat = 1920

    /// JPEG-encoded data, downscaled to `maxDimension` and progressively
    /// re-encoded until the size cap is met. Returns `nil` only for images
    /// that cannot be drawn at all.
    public static func compressForCloudKit(_ image: UIImage) -> Data? {
        let resized = downscale(image, maxDimension: maxDimension)
        for quality in stride(from: 0.8, through: 0.3, by: -0.1) {
            if let data = resized.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
        }
        // Last resort: return the smallest-quality data even if over the cap.
        return resized.jpegData(compressionQuality: 0.3)
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

- [ ] **Step 4: Run tests, expect 4/4 pass**

Run: `swift test --package-path GrowWisePackage --filter PhotoCompressionTests 2>&1 | tail -10`

Expected: 4 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/PhotoCompressionService.swift \
        GrowWisePackage/Tests/GrowWiseServicesTests/PhotoCompressionTests.swift
git commit -m "$(cat <<'EOF'
feat(#271): add PhotoCompressionService for CKAsset-bound JPEGs

Downscales to a 1920px longest-edge cap and progressively re-encodes
JPEG quality from 0.8 → 0.3 until the resulting bytes fit under
~1.5MB, comfortably under CKAsset's ~5MB ceiling.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Extend `DataService.createClubPost` with `photo:` and `clubID:`

This is the meatiest service-layer change.

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/DataService+GardenClub.swift`
- Modify: `GrowWisePackage/Tests/GrowWiseServicesTests/ClubSharingTests.swift` (extend with new tests)

- [ ] **Step 1: Add the failing tests**

Append to the `ClubSharingTests` suite:

```swift
    // MARK: - createClubPost extended signature

    @Test("createClubPost without photo persists nil photoURL")
    func createPostWithoutPhotoLeavesPhotoURLNil() throws {
        let service = try makeService()
        _ = try makeClub(in: service, name: "Solo")
        let activity = try service.createClubPost(
            caption: "Just a text post",
            activityType: "shared",
            plantName: nil,
            photo: nil,
            clubID: nil
        )
        #expect(activity.photoURL == nil)
    }

    @Test("createClubPost with photo writes file under ClubPostPhotos/")
    func createPostWithPhotoWritesFile() throws {
        let service = try makeService()
        _ = try makeClub(in: service, name: "Solo")

        let activityID = UUID()
        let bytes = Data([0xFF, 0xD8, 0xFF, 0xE0]) // bare JPEG magic + 1 byte; not a real image but that's irrelevant for this test
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("\(activityID).jpg")
        try bytes.write(to: temp)
        let photo = ClubPostPhoto(
            data: bytes,
            filename: "\(activityID).jpg",
            temporaryFileURL: temp,
            activityID: activityID
        )

        let activity = try service.createClubPost(
            caption: "With photo",
            activityType: "shared",
            plantName: nil,
            photo: photo,
            clubID: nil
        )

        #expect(activity.photoURL == "ClubPostPhotos/\(activityID).jpg")

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let written = docs?.appendingPathComponent("ClubPostPhotos/\(activityID).jpg")
        #expect(written != nil)
        #expect(FileManager.default.fileExists(atPath: written?.path ?? ""))

        // Cleanup so the test file doesn't pollute the simulator's documents dir between runs.
        if let written { try? FileManager.default.removeItem(at: written) }
        try? FileManager.default.removeItem(at: temp)
    }

    @Test("createClubPost with photo uses photo.activityID as the activity id")
    func createPostUsesPhotoActivityID() throws {
        let service = try makeService()
        _ = try makeClub(in: service, name: "Solo")

        let activityID = UUID()
        let bytes = Data([0xFF])
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("\(activityID).jpg")
        try bytes.write(to: temp)
        let photo = ClubPostPhoto(
            data: bytes,
            filename: "\(activityID).jpg",
            temporaryFileURL: temp,
            activityID: activityID
        )

        let activity = try service.createClubPost(
            caption: "x",
            activityType: "shared",
            plantName: nil,
            photo: photo,
            clubID: nil
        )

        #expect(activity.id == activityID)

        // Cleanup.
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let written = docs?.appendingPathComponent("ClubPostPhotos/\(activityID).jpg")
        if let written { try? FileManager.default.removeItem(at: written) }
        try? FileManager.default.removeItem(at: temp)
    }

    @Test("createClubPost with explicit clubID targets that club")
    func createPostHonoursExplicitClubID() throws {
        let service = try makeService()
        _ = try makeClub(in: service, name: "Primary")
        let secondary = try makeClub(in: service, name: "Secondary")
        guard let secondaryID = secondary.id else {
            Issue.record("Secondary club has no id")
            return
        }

        let activity = try service.createClubPost(
            caption: "Hello secondary",
            activityType: "shared",
            plantName: nil,
            photo: nil,
            clubID: secondaryID
        )

        #expect(activity.clubID == secondaryID)
    }

    @Test("createClubPost with invalid clubID throws noClub")
    func createPostInvalidClubIDThrows() throws {
        let service = try makeService()
        _ = try makeClub(in: service, name: "Primary")

        #expect(throws: CreateClubPostError.self) {
            try service.createClubPost(
                caption: "Hello",
                activityType: "shared",
                plantName: nil,
                photo: nil,
                clubID: UUID()  // not in DB
            )
        }
    }

    @Test("createClubPost falls back to primary when clubID is nil")
    func createPostFallsBackToPrimary() throws {
        let service = try makeService()
        let primary = try makeClub(in: service, name: "Primary")

        let activity = try service.createClubPost(
            caption: "x",
            activityType: "shared",
            plantName: nil,
            photo: nil,
            clubID: nil
        )

        #expect(activity.clubID == primary.id)
    }

    @Test("createClubPost throws noClub when no clubs exist")
    func createPostNoClubsThrows() throws {
        let service = try makeService()
        // Intentionally do not create any club.
        #expect(throws: CreateClubPostError.self) {
            try service.createClubPost(
                caption: "x",
                activityType: "shared",
                plantName: nil,
                photo: nil,
                clubID: nil
            )
        }
    }
```

- [ ] **Step 2: Run, expect compile failure (the new signature doesn't exist yet)**

Run: `swift test --package-path GrowWisePackage --filter ClubSharingTests 2>&1 | tail -15`

Expected: Compile errors — `extra arguments at positions #4, #5 in call` (the existing signature has only 3 parameters; the tests pass 5).

- [ ] **Step 3: Replace `createClubPost` with the extended signature**

Open `GrowWisePackage/Sources/GrowWiseServices/DataService+GardenClub.swift`. Replace the existing `createClubPost(...)` method (the one declared near line 59) with:

```swift
    /// Create and persist a new ClubActivity post.
    ///
    /// - Parameters:
    ///   - caption: Post body text (required, non-empty trimmed).
    ///   - activityType: One of "shared", "watered", "harvested", "planted", etc.
    ///   - plantName: Optional plant name prepended to the description.
    ///   - photo: Optional photo payload. When provided, JPEG bytes are written to
    ///     `Documents/ClubPostPhotos/{filename}` and the relative path is stored
    ///     on `activity.photoURL`. The activity's `id` is set to `photo.activityID`
    ///     so the local file path and the activity stay in sync.
    ///   - clubID: Optional explicit club id. When `nil`, falls back to
    ///     `fetchPrimaryClub()` (legacy behavior).
    /// - Throws: `CreateClubPostError.noClub` when no club can be resolved.
    @discardableResult
    @MainActor
    func createClubPost(
        caption: String,
        activityType: String,
        plantName: String? = nil,
        photo: ClubPostPhoto? = nil,
        clubID: UUID? = nil
    ) throws -> ClubActivity {
        // 1. Resolve target club: explicit id wins over primary fallback.
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

        // 3. Construct activity. If a photo is provided, use its activityID so
        // the on-disk filename and the model id stay in sync.
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

        // 4. If a photo is provided, write the JPEG to documents.
        if let photo {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dir = docs.appendingPathComponent("ClubPostPhotos", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let dest = dir.appendingPathComponent(photo.filename)
                try photo.data.write(to: dest)
                activity.photoURL = "ClubPostPhotos/\(photo.filename)"
            } catch {
                // Log via Logger here in production code; for the test harness, leave photoURL nil.
                activity.photoURL = nil
            }
        }

        // 5. Persist. On save failure, clean up any photo we just wrote.
        let repo = ClubActivityRepository(context: mainContext)
        do {
            try repo.save(activity)
        } catch {
            if let photoPath = activity.photoURL {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let toDelete = docs.appendingPathComponent(photoPath)
                try? FileManager.default.removeItem(at: toDelete)
            }
            throw error
        }

        return activity
    }
```

> **Note:** The pre-existing 3-parameter call site in `ClubShareComposerSheet.swift:214` keeps working because the new `photo:` and `clubID:` parameters default to `nil`. We'll update that call site explicitly in Task 6.

- [ ] **Step 4: Run, expect 9 tests pass (2 from Task 1 + 7 new)**

Run: `swift test --package-path GrowWisePackage --filter ClubSharingTests 2>&1 | tail -15`

Expected: 9 tests, 0 failures.

- [ ] **Step 5: Run the broader test set to catch regressions**

Run: `swift test --package-path GrowWisePackage --filter "Club" 2>&1 | tail -15`

Expected: All Club-related tests pass.

- [ ] **Step 6: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/DataService+GardenClub.swift \
        GrowWisePackage/Tests/GrowWiseServicesTests/ClubSharingTests.swift
git commit -m "$(cat <<'EOF'
feat(#271): extend createClubPost with photo and explicit clubID

The composer can now pass a ClubPostPhoto (writes to
Documents/ClubPostPhotos/{id}.jpg + records the relative path on
activity.photoURL) and an explicit clubID (falls back to
fetchPrimaryClub when nil).

Both new parameters default to nil so existing call sites stay
compiling. Save-failure path cleans up any photo file that was
written.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Extend `ClubCloudKitService.publishActivity` with `photo:`

Adds the CKAsset attachment. Cannot be unit-tested without iCloud entitlements — covered by manual smoke (Task 9) and the surrounding code review.

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseServices/ClubCloudKitService.swift`

- [ ] **Step 1: Replace `publishActivity` with the extended signature**

In `ClubCloudKitService.swift`, find `publishActivity(_:)` (around line 318). Replace its signature and add the CKAsset attachment line. The new method:

```swift
    /// Saves an activity record into the club's shared zone so all members can see it.
    /// When `photo` is provided, attaches its temporary file URL as a CKAsset under
    /// the `photoAsset` field key — the read side reads the same key.
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

The default `photo: nil` keeps any existing call sites compiling.

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build --package-path GrowWisePackage 2>&1 | tail -5`

Expected: `Build complete!`.

- [ ] **Step 3: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseServices/ClubCloudKitService.swift
git commit -m "$(cat <<'EOF'
feat(#271): publishActivity attaches CKAsset for photo

When a ClubPostPhoto is supplied, the photo's temp file URL is
attached as a CKAsset under field key "photoAsset". The read side
in GardenClubFeedView uses the same key.

The new parameter defaults to nil so existing call sites (none yet
in production) stay compiling.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: ClubShareComposerSheet — photo picker

Add the picker UI and the photo-state plumbing. Defer the multi-club selector and empty state to Task 7 to keep diffs reviewable.

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubShareComposerSheet.swift`

- [ ] **Step 1: Add PhotosUI import and new @State**

At the top of `ClubShareComposerSheet.swift`, add `import PhotosUI` after the existing imports.

In the struct's @State declarations (around line 17), add:

```swift
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var preview: UIImage?
    @State private var showCloudKitWarning = false
```

- [ ] **Step 2: Add a photo section to the scroll content**

Find `private var scrollContent: some View` (around line 64). Insert a new section between the captionSection and the `if plant != nil { plantContextSection }`:

```swift
    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                photoSection         // NEW
                captionSection
                if plant != nil {
                    plantContextSection
                }
                postFooterHint
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.top, CultivationTheme.Spacing.sectionGap)
            .padding(.bottom, 40)
        }
    }
```

Then add the `photoSection` computed property after `captionSection`:

```swift
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Photo")
                .sectionLabelStyle()
                .padding(.leading, 4)

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                if let preview {
                    photoPreviewTile(preview)
                } else {
                    photoEmptyTile
                }
            }
            .accessibilityIdentifier("share_composer_button_addphoto")
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task<Void, Never> { await loadPhoto(from: newItem) }
            }
        }
    }

    private func photoPreviewTile(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("share_composer_image_preview")

            Button {
                selectedPhotoItem = nil
                selectedPhotoData = nil
                preview = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(CultivationTheme.Colors.statusAlert)
                    .background(Circle().fill(.white))
                    .padding(4)
            }
            .accessibilityIdentifier("share_composer_button_clearphoto")
        }
    }

    private var photoEmptyTile: some View {
        VStack(spacing: 4) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 24))
                .foregroundStyle(CultivationTheme.Colors.brandSage)
            Text("Add Photo")
                .font(CultivationTheme.Fonts.body(11))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
        }
        .frame(width: 100, height: 100)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    CultivationTheme.Colors.cardBorder,
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        )
    }

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let img = UIImage(data: data) else {
                return
            }
            selectedPhotoData = data
            preview = img
        } catch {
            errorMessage = "Couldn't load photo: \(error.localizedDescription)"
            showError = true
        }
    }
```

- [ ] **Step 3: Build to verify**

Run: `swift build --package-path GrowWisePackage 2>&1 | tail -5`

Expected: `Build complete!`.

- [ ] **Step 4: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubShareComposerSheet.swift
git commit -m "$(cat <<'EOF'
feat(#271): add photo picker to ClubShareComposerSheet

Single-photo picker via PhotosPicker (matches ClubChatView and
AddPlantSheet patterns). 100x100 preview tile with an X button to
clear, or a dashed-border "Add Photo" tile when nothing is selected.
The selected photo data is held in @State for Task 7's submitPost
rewrite.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: ClubShareComposerSheet — multi-club selector + empty state + soft-fail submit

The remaining composer changes: club picker (when 2+), 0-club empty state, and the rewritten `submitPost()` that calls the extended `createClubPost(...)` and CK `publishActivity(...)` with soft-fail.

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubShareComposerSheet.swift`

- [ ] **Step 1: Inject ClubCloudKitService and add club state**

Add to the `@Environment` declarations near the top of the struct:

```swift
    @Environment(ClubCloudKitService.self) private var clubCloudKitService
```

Add to @State:

```swift
    @State private var availableClubs: [GardenClub] = []
    @State private var selectedClubID: UUID?
```

Replace the existing `init` to accept an optional `onRequestCreateClub` callback for the empty-state CTA:

```swift
    public init(
        plant: Plant? = nil,
        initialCaption: String? = nil,
        onPost: @escaping () -> Void = {},
        onRequestCreateClub: @escaping () -> Void = {}
    ) {
        self.plant = plant
        self.initialCaption = initialCaption
        self.onPost = onPost
        self.onRequestCreateClub = onRequestCreateClub
        if let ic = initialCaption {
            _caption = State(initialValue: ic)
        }
    }
```

Add the matching stored property:

```swift
    let onRequestCreateClub: () -> Void
```

(Place it next to `var onPost: () -> Void = {}`.)

- [ ] **Step 2: Replace `loadClubName()` with `loadClubs()`**

Find the existing `loadClubName()` (around line 227). Replace it with:

```swift
    private func loadClubs() {
        do {
            let clubs = try dataService.fetchClubs()
            availableClubs = clubs
            if let primary = dataService.fetchPrimaryClub() {
                clubName = primary.name ?? "Your Club"
                selectedClubID = primary.id
            } else if let first = clubs.first {
                clubName = first.name ?? "Your Club"
                selectedClubID = first.id
            }
        } catch {
            availableClubs = []
        }
    }
```

In the `.task { loadClubName() }` modifier near line 57, change `loadClubName()` to `loadClubs()`.

- [ ] **Step 3: Add club selector UI**

Add a new computed property `clubSelectorSection` (used only when `availableClubs.count >= 2`):

```swift
    private var clubSelectorSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Post to")
                .sectionLabelStyle()
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableClubs, id: \.id) { club in
                        Button {
                            if let id = club.id {
                                selectedClubID = id
                                clubName = club.name ?? "Your Club"
                            }
                        } label: {
                            Text(club.name ?? "Club")
                                .font(CultivationTheme.Fonts.body(13, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(
                                            selectedClubID == club.id
                                                ? CultivationTheme.Colors.smartTagBackground
                                                : CultivationTheme.Colors.backgroundSecondary
                                        )
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            selectedClubID == club.id
                                                ? CultivationTheme.Colors.brandLeaf.opacity(0.6)
                                                : CultivationTheme.Colors.cardBorder,
                                            lineWidth: 1
                                        )
                                )
                                .foregroundStyle(CultivationTheme.Colors.textPrimary)
                        }
                        .accessibilityIdentifier("share_composer_pill_club_\(club.id?.uuidString ?? "unknown")")
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
```

In `scrollContent`, insert it above `photoSection`:

```swift
    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CultivationTheme.Spacing.sectionGap) {
                if availableClubs.count >= 2 {
                    clubSelectorSection
                }
                photoSection
                captionSection
                if plant != nil {
                    plantContextSection
                }
                postFooterHint
            }
            .padding(.horizontal, CultivationTheme.Spacing.screenPadding)
            .padding(.top, CultivationTheme.Spacing.sectionGap)
            .padding(.bottom, 40)
        }
    }
```

Update the `navigationTitle` to reflect the multi-club case. Replace:

```swift
.navigationTitle("Share with \(clubName)")
```

with:

```swift
.navigationTitle(availableClubs.count >= 2 ? "Share with your clubs" : "Share with \(clubName)")
```

- [ ] **Step 4: Add the empty-state view (0 clubs)**

Add a new computed property:

```swift
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.3.sequence")
                .font(.system(size: 56))
                .foregroundStyle(CultivationTheme.Colors.brandSage)
                .accessibilityIdentifier("share_composer_emptystate_icon")
            Text("Join a club to share")
                .font(CultivationTheme.Fonts.display(20, weight: .semibold))
                .foregroundStyle(CultivationTheme.Colors.textPrimary)
            Text("Garden Clubs let you swap photos and tips with other gardeners. Create your own or join one with an invite code.")
                .font(CultivationTheme.Fonts.body(13))
                .foregroundStyle(CultivationTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button {
                dismiss()
                onRequestCreateClub()
            } label: {
                Text("Create or Join a Club")
                    .font(CultivationTheme.Fonts.body(14, weight: .semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(CultivationTheme.Gradients.cta)
                    )
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("share_composer_emptystate_button_create")
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
```

In the `body`'s `ZStack`, swap content based on club availability. Replace the existing body:

```swift
    public var body: some View {
        NavigationStack {
            ZStack {
                CultivationTheme.Colors.background.ignoresSafeArea()
                if availableClubs.isEmpty {
                    emptyStateView
                } else {
                    scrollContent
                }
            }
            .navigationTitle(navigationTitleText)
            .gwNavigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Couldn't post", isPresented: $showError) {
                Button("OK") { showError = false }
                    .accessibilityIdentifier("share_composer_alert_error")
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
            .alert("Posted locally", isPresented: $showCloudKitWarning) {
                Button("OK", role: .cancel) { showCloudKitWarning = false }
            } message: {
                Text("Your post will sync to your club when iCloud is available.")
            }
            .task { loadClubs() }
        }
        .accessibilityIdentifier("screen_share_composer")
    }

    private var navigationTitleText: String {
        if availableClubs.isEmpty {
            return "Share"
        }
        return availableClubs.count >= 2 ? "Share with your clubs" : "Share with \(clubName)"
    }
```

Remove the standalone `.navigationTitle(...)` line you added in Step 3 (it's now folded into `navigationTitleText`).

- [ ] **Step 5: Rewrite `submitPost()` with soft-fail flow**

Replace the existing `submitPost()` (around line 205) with:

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
            let activityID = UUID()
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent("\(activityID).jpg")
            do {
                try compressed.write(to: temp)
            } catch {
                errorMessage = "Couldn't save photo: \(error.localizedDescription)"
                showError = true
                return
            }
            photoToShip = ClubPostPhoto(
                data: compressed,
                filename: "\(activityID).jpg",
                temporaryFileURL: temp,
                activityID: activityID
            )
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
            // Fall through to dismiss — local post is committed.
        }

        // Cleanup temp file (best-effort).
        if let photoToShip {
            try? FileManager.default.removeItem(at: photoToShip.temporaryFileURL)
        }

        onPost()
        dismiss()
    }
```

- [ ] **Step 6: Update the post-button disabled logic**

The post button should also disable when there's no club to post to. Find `private var postButton: some View` (around line 184). Change the `.disabled(captionIsEmpty)` line to `.disabled(captionIsEmpty || selectedClubID == nil)`.

- [ ] **Step 7: Update the GardenClubFeedView call site to pass `onRequestCreateClub`**

In `GardenClubFeedView.swift`, find the `.sheet(isPresented: $isPresentingComposer)` block (around line 87). Pass a no-op `onRequestCreateClub` for now — the empty state path is unreachable from this sheet entry point because the share button only shows when the user has at least one club. Update to:

```swift
        .sheet(isPresented: $isPresentingComposer) {
            ClubShareComposerSheet(
                plant: nil,
                onPost: { Task<Void, Never> { await load() } },
                onRequestCreateClub: {}
            )
            .environment(dataService)
            .environment(clubCloudKitService)
        }
```

The added `.environment(clubCloudKitService)` matters — the composer now reads `ClubCloudKitService` from environment. The feed view already has it in scope via `@Environment(ClubCloudKitService.self)`.

> **Other call sites:** Search for `ClubShareComposerSheet(` with `grep -rn "ClubShareComposerSheet(" GrowWisePackage/Sources/`. For each call site, add `.environment(clubCloudKitService)` to the sheet's view chain (the call site needs to have a `clubCloudKitService` in scope). If a call site doesn't have one, inject via `@Environment(ClubCloudKitService.self) private var clubCloudKitService` in the parent view.

- [ ] **Step 8: Build + run all club-related tests**

Run: `swift build --package-path GrowWisePackage 2>&1 | tail -10`

Expected: `Build complete!`.

Run: `swift test --package-path GrowWisePackage --filter "Club" 2>&1 | tail -15`

Expected: All Club-related tests pass (we didn't change tests in this task; this catches accidental regressions in the view glue).

- [ ] **Step 9: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubShareComposerSheet.swift \
        GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/GardenClubFeedView.swift
git commit -m "$(cat <<'EOF'
feat(#271): club selector, empty state, soft-fail CloudKit publish

ClubShareComposerSheet now:
- shows a horizontal pill row when the user is in 2+ clubs
- presents an empty-state CTA when in 0 clubs (dismisses + invokes
  onRequestCreateClub callback)
- compresses the picked photo via PhotoCompressionService and writes
  it to a temp file for CKAsset upload
- on Post: hard-fail on local save, soft-fail on CloudKit publish
  with a "Posted locally — will sync when iCloud is available"
  banner

The feed view passes the existing clubCloudKitService environment
into the sheet.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: GardenClubFeedView — render real photos in PostCard

The feed-side companion to #271/#272. Wire up `photoFileURL` on `ClubActivityViewData`, add `ClubPostPhotoView`, replace the gradient.

**Files:**
- Modify: `GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/GardenClubFeedView.swift`
- Create: `GrowWisePackage/Tests/GrowWiseFeatureTests/GardenClubFeedViewMappingTests.swift`

- [ ] **Step 1: Add the failing tests**

Create `GrowWisePackage/Tests/GrowWiseFeatureTests/GardenClubFeedViewMappingTests.swift`:

```swift
import Testing
import Foundation
@testable import GrowWiseFeature
@testable import GrowWiseModels

@Suite("GardenClubFeedView ClubActivity → ClubActivityViewData mapping")
@MainActor
struct GardenClubFeedViewMappingTests {
    @Test("viewData maps photoURL to documents-relative file URL")
    func mapsPhotoURLToDocumentsRelativeURL() {
        let activity = ClubActivity(
            clubID: UUID(),
            memberName: "Tester",
            memberID: "u1",
            activityType: "shared",
            description: "Test post"
        )
        activity.photoURL = "ClubPostPhotos/abc.jpg"

        let result = GardenClubFeedView.viewData(from: activity)
        let path = result.photoFileURL?.path ?? ""
        #expect(path.hasSuffix("/ClubPostPhotos/abc.jpg"))
    }

    @Test("viewData returns nil photoFileURL when photoURL is nil")
    func returnsNilPhotoFileURLWhenPhotoURLIsNil() {
        let activity = ClubActivity(
            clubID: UUID(),
            memberName: "Tester",
            memberID: "u1",
            activityType: "shared",
            description: "Test post"
        )
        activity.photoURL = nil

        let result = GardenClubFeedView.viewData(from: activity)
        #expect(result.photoFileURL == nil)
    }

    @Test("viewData returns nil photoFileURL when photoURL is empty string")
    func returnsNilPhotoFileURLWhenPhotoURLIsEmpty() {
        let activity = ClubActivity(
            clubID: UUID(),
            memberName: "Tester",
            memberID: "u1",
            activityType: "shared",
            description: "Test post"
        )
        activity.photoURL = ""

        let result = GardenClubFeedView.viewData(from: activity)
        #expect(result.photoFileURL == nil)
    }

    @Test("viewData preserves caption and author")
    func preservesCaptionAndAuthor() {
        let activity = ClubActivity(
            clubID: UUID(),
            memberName: "Aria",
            memberID: "u1",
            activityType: "shared",
            description: "Tomato got tall"
        )
        let result = GardenClubFeedView.viewData(from: activity)
        #expect(result.authorDisplayName == "Aria")
        #expect(result.caption == "Tomato got tall")
    }
}
```

- [ ] **Step 2: Run, expect compile failure**

Run: `swift test --package-path GrowWisePackage --filter GardenClubFeedViewMappingTests 2>&1 | tail -10`

Expected: Compile errors — `'viewData' is inaccessible due to 'private' protection level` or `value of type 'GardenClubFeedView.ClubActivityViewData' has no member 'photoFileURL'`.

- [ ] **Step 3: Add `photoFileURL` to `ClubActivityViewData`**

In `GardenClubFeedView.swift`, find `struct ClubActivityViewData: Identifiable` (around line 57). Add a new field:

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

- [ ] **Step 4: Update both `viewData(from:)` mappers and change visibility**

Change `private static func viewData(from activity: ClubActivity)` to `static func viewData(from activity: ClubActivity)` (the explicit `internal` access lets the test reach it via `@testable import`). Add the photoFileURL mapping:

```swift
    static func viewData(from activity: ClubActivity) -> ClubActivityViewData {
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

Do the same for `viewData(from record: CKRecord)` (drop `private`, add the `photoFileURL` mapping):

```swift
    static func viewData(from record: CKRecord) -> ClubActivityViewData {
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

- [ ] **Step 5: Add `ClubPostPhotoView` and update `PostCard`**

At the bottom of `GardenClubFeedView.swift` (after the `PostCard` private struct), add:

```swift
private struct ClubPostPhotoView: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            // Gradient placeholder shown while loading.
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
            guard let url else {
                image = nil
                return
            }
            let loaded = await Task.detached(priority: .userInitiated) {
                UIImage(contentsOfFile: url.path)
            }.value
            await MainActor.run { image = loaded }
        }
    }
}
```

In `PostCard`'s body, find the existing gradient block (lines 469-476):

```swift
            // Photo placeholder — wire to PhotoService asset URL when available
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [CultivationTheme.Colors.brandLeaf, CultivationTheme.Colors.brandForest],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 120)
```

Replace it with:

```swift
            if post.photoFileURL != nil {
                ClubPostPhotoView(url: post.photoFileURL)
            }
```

The conditional means posts with no photo (legacy or text-only) skip the photo block entirely — no empty space.

- [ ] **Step 6: Run feed mapping tests, expect 4/4 pass**

Run: `swift test --package-path GrowWisePackage --filter GardenClubFeedViewMappingTests 2>&1 | tail -10`

Expected: 4 tests, 0 failures.

- [ ] **Step 7: Run the full feature test set**

Run: `swift test --package-path GrowWisePackage --filter "GardenClub" 2>&1 | tail -10`

Expected: All GardenClub-related tests pass.

- [ ] **Step 8: Commit**

```bash
git add GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/GardenClubFeedView.swift \
        GrowWisePackage/Tests/GrowWiseFeatureTests/GardenClubFeedViewMappingTests.swift
git commit -m "$(cat <<'EOF'
feat(#272): render real club post photos in feed

- ClubActivityViewData now carries an optional photoFileURL
  (resolved from activity.photoURL → Documents/ClubPostPhotos/...
  for local posts, or from CKRecord["photoAsset"] CKAsset for
  CloudKit-fetched posts)
- new ClubPostPhotoView loads the file off the main thread and
  shows the existing leaf/forest gradient as a loading placeholder
- PostCard renders the photo block only when photoFileURL is non-nil
  so legacy text-only posts don't show empty space
- viewData(from:) helpers exposed at internal access for unit tests

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Final integration — full test suite + lint + push + PR

**Files:** none (workflow only)

- [ ] **Step 1: Run the full test suite**

Run: `swift test --package-path GrowWisePackage 2>&1 | tail -10`

Expected: All tests pass — no regressions. Watch for the pre-existing Signal 5 in the testing helper that loses the end-of-run summary line; it reproduces on master and is unrelated to this PR.

- [ ] **Step 2: Run SwiftLint on the touched files**

Run: `swiftlint lint --strict --config .swiftlint.yml --path GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/ClubShareComposerSheet.swift --path GrowWisePackage/Sources/GrowWiseFeature/Views/GardenClub/GardenClubFeedView.swift --path GrowWisePackage/Sources/GrowWiseServices/DataService+GardenClub.swift --path GrowWisePackage/Sources/GrowWiseServices/ClubCloudKitService.swift --path GrowWisePackage/Sources/GrowWiseServices/ClubPostPhoto.swift --path GrowWisePackage/Sources/GrowWiseServices/PhotoCompressionService.swift --path GrowWisePackage/Sources/GrowWiseServices/Repositories/ClubRepository.swift 2>&1 | tail -10`

Expected: Zero violations on these files. (If `type_body_length` shows up on `GardenClubFeedView` or `ClubShareComposerSheet` and matches the pre-existing `AddReminderView` pattern of un-fixed type_body_length warnings, leave it — it's an existing project-wide tolerance.)

- [ ] **Step 3: Run the full SwiftLint pass**

Run: `swiftlint lint --strict --config .swiftlint.yml 2>&1 | grep -E "no_growwise_user_facing|fatal|error" | head -10`

Expected: No new `no_growwise_user_facing` violations from #275's rule. Pre-existing violations from other rules are fine.

- [ ] **Step 4: Push the branch**

```bash
git push -u origin feat/issue-271-272-club-sharing
```

- [ ] **Step 5: Open the PR**

```bash
gh pr create --repo jbcrane13/GrowWise \
    --title "fix(#271,#272): full club sharing — photo, club selection, CloudKit publish" \
    --body "$(cat <<'EOF'
## Summary
- Add a single-photo picker to ClubShareComposerSheet (PhotosUI), with a 100x100 preview tile and clear button.
- Add a multi-club selector pill row when the user is in 2+ clubs (auto-hidden when 1; replaced by an empty-state "Join or create a club first" CTA when 0).
- Extend `DataService.createClubPost(...)` with optional `photo:` and `clubID:` parameters. Photos are JPEG-compressed (≤1.5MB, max 1920px), written to `Documents/ClubPostPhotos/{activity.id}.jpg`, and tracked via the existing `ClubActivity.photoURL` field.
- Extend `ClubCloudKitService.publishActivity(_:photo:)` to attach a `CKAsset` under the `photoAsset` field key on the existing `clubActivity` CKRecord.
- Soft-fail on CloudKit publish: local save commits regardless; on CK error a "Posted locally — will sync when iCloud is available" banner is shown and the sheet still dismisses.
- Replace `PostCard`'s gradient placeholder with a real `ClubPostPhotoView` that loads the photo file off the main thread and falls back to the gradient as a loading state.

Closes #271, #272.

## Decisions (locked in brainstorming)
- Single photo per post; multi-photo carousel is deferred.
- Soft-fail on CloudKit publish so users get instant local feedback even when offline.
- Hide the club selector when in exactly 1 club; show pills when in 2+; show empty-state CTA when in 0.

## Test plan
- [x] `swift test --package-path GrowWisePackage --filter "ClubSharingTests|PhotoCompressionTests|GardenClubFeedViewMappingTests"` — all new tests pass locally
- [x] `swift test --package-path GrowWisePackage` — full suite green, no regressions
- [x] `swift build --package-path GrowWisePackage` succeeds
- [x] `swiftlint lint --strict --config .swiftlint.yml` reports 0 new violations on touched files
- [ ] CI green (Build, Test, SwiftLint, SwiftFormat, Coverage Threshold, QA — iOS Simulator)
- [ ] Manual smoke (mac-mini sim, signed in to iCloud):
  - Tap Club tab → Share → pick a photo → write caption → Post → confirm sheet dismisses, post appears in feed with the actual photo (not a gradient).
  - Force-quit the app, relaunch → post still in feed (CloudKit roundtrip).
  - Toggle airplane mode → post a photo → "Posted locally" banner shows, post appears in feed.
  - With 2+ clubs, confirm the pill selector appears and the post lands in the selected club.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 6: Watch CI**

```bash
gh pr view --repo jbcrane13/GrowWise --json number,url,state,mergeable,statusCheckRollup | jq '{number, url, state, mergeable, checks: [.statusCheckRollup[]? | {name, conclusion, status}]}'
```

Expected: PR opens, all checks queued or running. Wait for required checks to be green.

- [ ] **Step 7: Hand back to user**

Do **not** auto-merge. Do **not** close issues #271 or #272 yourself — `gh pr merge` (when invoked by the maintainer with the `Closes #271, #272` keyword in the body) will close both on merge.

Comment: "PR opened, all required checks green. Awaiting your review/merge approval."

---

## Verification (final, after Task 9)

- [ ] PR opened and links both issues (body says `Closes #271, #272`).
- [ ] Required CI checks (Build, Test, SwiftLint, SwiftFormat, Coverage Threshold, QA — iOS Simulator) are green.
- [ ] No regressions to existing tests.
- [ ] The new tests all pass: `ClubSharingTests` (9 tests), `PhotoCompressionTests` (4 tests), `GardenClubFeedViewMappingTests` (4 tests) = 17 new tests total.
- [ ] `ClubPostPhoto.swift`, `PhotoCompressionService.swift` are in `Sources/GrowWiseServices/`.
- [ ] `ClubShareComposerSheet.swift` has photo picker, club selector, empty state, soft-fail flow.
- [ ] `GardenClubFeedView.swift` PostCard renders real photos via `ClubPostPhotoView`.
- [ ] Issues #271 and #272 will close automatically when the maintainer merges.

## Notes for the implementer

- **Working branch is `feat/issue-271-272-club-sharing`** — already created with the design spec committed (`768a42a`). Do not re-branch.
- **Tests run locally** via `swift test --package-path GrowWisePackage`. Do not SSH to mac-mini for unit tests; do not use `xcodebuild test` on this machine.
- **CloudKit publish (`publishActivity`) cannot be unit-tested** without iCloud entitlements. Manual smoke covers it.
- **One commit per task** — Tasks 1-8 each produce one commit (9 commits total). Task 9 is workflow only (push + PR).
- **`Documents/ClubPostPhotos/` test cleanup** — unit tests that write photos to documents must clean up in their `defer` or after assertions, otherwise they pollute the simulator's documents dir between runs and may cause non-deterministic state.
- **Linter rewrites** — `.swiftlint.yml` is strict (rules elevated to errors). The pre-commit hook formats and lints. Expect SwiftFormat to rewrite test method names that start with `test` (a hook strips that prefix); use names like `mapsPhotoURLToDocumentsRelativeURL`, not `testMapsPhotoURLToDocumentsRelativeURL`.
- **`@testable import GrowWiseFeature` reaches internal members.** The mapping test file uses this import to call `GardenClubFeedView.viewData(from:)`. The visibility change in Task 8 Step 4 (private → internal) is what makes this work.
- **Pre-existing `type_body_length` warnings** — `GardenClubFeedView` already has a `// swiftlint:disable:this type_body_length` comment on line 15. Don't remove it; the new code may push the body further over 300 lines and the disable still applies.
- **`ClubActivity.id` reassignment** — the `ClubActivity.init` sets `id = UUID()`, then `createClubPost` may reassign to `photo.activityID` so the local file path matches. This is valid because the property is `var`, not `let`. Verified at `GrowWisePackage/Sources/GrowWiseModels/ClubActivity.swift:6`.
