import CloudKit
import Foundation
import Observation

/// PRO-gated optional iCloud sync via SwiftData + CloudKit private database.
@Observable
final class CloudSyncManager {
    static let shared = CloudSyncManager()

    static let containerIdentifier = "iCloud.com.antigravity.billsmanager"
    static let enabledKey = "iCloudSyncEnabled"
    static let migrationPendingKey = "iCloudMigrationPending"
    static let migrationDirectionKey = "iCloudMigrationDirection"
    static let restartRequiredKey = "iCloudRestartRequired"

    private(set) var accountStatusText: String = L10n.s("Checking…")
    private(set) var isAccountAvailable: Bool = false
    private(set) var restartRequired: Bool

    private init() {
        restartRequired = UserDefaults.standard.bool(forKey: Self.restartRequiredKey)
    }

    var isSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    /// Whether the app should open the CloudKit-backed SwiftData store on launch.
    static var shouldUseCloudKit: Bool {
        shared.isSyncEnabled
    }

    @MainActor
    func refreshAccountStatus() async {
        do {
            let status = try await CKContainer(identifier: Self.containerIdentifier).accountStatus()
            switch status {
            case .available:
                accountStatusText = L10n.s("iCloud Available")
                isAccountAvailable = true
            case .noAccount:
                accountStatusText = L10n.s("Not Signed In to iCloud")
                isAccountAvailable = false
            case .restricted:
                accountStatusText = L10n.s("iCloud Restricted")
                isAccountAvailable = false
            case .couldNotDetermine:
                accountStatusText = L10n.s("Unknown")
                isAccountAvailable = false
            case .temporarilyUnavailable:
                accountStatusText = L10n.s("iCloud Temporarily Unavailable")
                isAccountAvailable = false
            @unknown default:
                accountStatusText = L10n.s("Unknown")
                isAccountAvailable = false
            }
        } catch {
            accountStatusText = L10n.s("Unknown")
            isAccountAvailable = false
        }
    }

    /// Persists preference and marks migration + restart. Returns `true` when a relaunch is required.
    @discardableResult
    func requestSyncEnabled(_ enabled: Bool) -> Bool {
        guard enabled != isSyncEnabled else { return false }
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        UserDefaults.standard.set(true, forKey: Self.migrationPendingKey)
        UserDefaults.standard.set(enabled ? "toCloud" : "toLocal", forKey: Self.migrationDirectionKey)
        UserDefaults.standard.set(true, forKey: Self.restartRequiredKey)
        restartRequired = true
        return true
    }

    func acknowledgeRestartRequired() {
        UserDefaults.standard.set(false, forKey: Self.restartRequiredKey)
        restartRequired = false
    }
}
