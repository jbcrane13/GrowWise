import Foundation

/// Central registry of CloudKit record type string constants.
/// Keeps all record names in one place to avoid magic-string bugs.
public enum CloudKitSchema {
    // MARK: - Private database record types (synced via SwiftData + CloudKit)

    public enum RecordType {
        // Existing garden data
        public static let garden = "CD_Garden"
        public static let plant = "CD_Plant"
        public static let journalEntry = "CD_JournalEntry"
        public static let reminder = "CD_Reminder"

        // Garden Club — shared zone records
        public static let gardenClub = "CD_GardenClub"
        public static let clubActivity = "CD_ClubActivity"
        public static let clubMessage = "CD_ClubMessage"
        public static let clubEvent = "CD_ClubEvent"
    }

    // MARK: - Public database record types

    public enum PublicRecordType {
        public static let publicGarden = "PublicGarden"
        public static let forumQuestion = "ForumQuestion"
        public static let forumAnswer = "ForumAnswer"
    }

    // MARK: - Custom zone names

    public enum Zone {
        /// The default CloudKit private zone used by SwiftData.
        public static let `default` = "_defaultZone"
        /// Named zone used for Garden Club CKShare records.
        public static let gardenClub = "GardenClubZone"
    }

    // MARK: - Subscription IDs

    public enum Subscription {
        public static let gardenClubChanges = "gardenclub-changes"
    }
}
