import Foundation
import CloudKit
import CoreData

@MainActor
@Observable public final class CloudSyncService {
    public private(set) var isSyncing = false
    public private(set) var lastSyncDate: Date?
    public private(set) var lastErrorMessage: String?
    public private(set) var accountStatus: CKAccountStatus = .couldNotDetermine

    private weak var dataService: DataService?
    private var cloudEventObserver: NSObjectProtocol?
    private var accountObserver: NSObjectProtocol?

    public init() {
        startObserving()
    }

    public func attach(dataService: DataService) {
        self.dataService = dataService
        Task {
            await refreshStatus()
        }
    }

    public func refreshStatus() async {
        guard let dataService else { return }
        let status = await dataService.getCloudSyncStatus()
        accountStatus = status.accountStatus
        lastSyncDate = status.lastSync
        lastErrorMessage = status.error
    }

    private func startObserving() {
        cloudEventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard
                let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event
            else {
                return
            }

            let endDate = event.endDate
            let errorDescription = event.error?.localizedDescription

            Task { @MainActor in
                if endDate == nil {
                    self.isSyncing = true
                } else {
                    self.isSyncing = false
                    self.lastSyncDate = endDate
                    UserDefaults.standard.set(endDate, forKey: "lastCloudSync")
                }

                if let errorDescription {
                    self.lastErrorMessage = errorDescription
                }
            }
        }

        accountObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshStatus()
            }
        }
    }
}
