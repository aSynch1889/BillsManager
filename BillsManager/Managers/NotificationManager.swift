import Foundation
import UserNotifications
import UIKit

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
    }

    /// Call once at app launch so foreground notifications can present banners.
    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
    }

    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            return try await UNUserNotificationCenter.current().requestAuthorization(options: options)
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }

    /// Request permission when status is `.notDetermined`; otherwise return current grant state.
    @discardableResult
    func ensureAuthorization() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await requestAuthorization()
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        Task { @MainActor in
            await UIApplication.shared.open(url)
        }
    }

    func scheduleNotification(for bill: Bill) {
        guard !bill.isPaid else {
            cancelNotification(for: bill)
            return
        }

        let center = UNUserNotificationCenter.current()
        let identifier = bill.id.uuidString

        // Replace any existing pending request for this bill.
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: bill.reminderTime)

        guard let notificationDate = calendar.date(byAdding: .day, value: -bill.reminderDaysBefore, to: bill.dueDate) else { return }

        var dateComponents = calendar.dateComponents([.year, .month, .day], from: notificationDate)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute

        // Skip past fire times — expired reminders would never deliver usefully.
        if let fireDate = calendar.date(from: dateComponents), fireDate < Date() {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = L10n.s("Bill Due Reminder")
        let formattedAmount = bill.formattedAmount

        if bill.reminderDaysBefore == 0 {
            content.body = String(format: L10n.s("%@ is due today (%@)!"), bill.name, formattedAmount)
        } else {
            content.body = String(format: L10n.s("%@ (%@) is due in %d days."), bill.name, formattedAmount, bill.reminderDaysBefore)
        }

        content.sound = .default
        // Badge is managed centrally via `updateBadgeCount`; do not hardcode 1 on each notification.

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Failed to add notification for bill \(bill.name): \(error)")
            }
        }
    }

    func cancelNotification(for bill: Bill) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [bill.id.uuidString])
    }

    func updateBadgeCount(overdueCount: Int) {
        Task { @MainActor in
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(max(0, overdueCount))
            } catch {
                print("Failed to set badge count: \(error)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
