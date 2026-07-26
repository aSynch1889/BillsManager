import Foundation
import UserNotifications
import UIKit

final class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            return try await UNUserNotificationCenter.current().requestAuthorization(options: options)
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }
    
    func scheduleNotification(for bill: Bill) {
        guard !bill.isPaid else {
            cancelNotification(for: bill)
            return
        }
        
        let center = UNUserNotificationCenter.current()
        let identifier = bill.id.uuidString
        
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: bill.reminderTime)
        
        // Calculate reminder date by subtracting reminderDaysBefore from dueDate
        guard let notificationDate = calendar.date(byAdding: .day, value: -bill.reminderDaysBefore, to: bill.dueDate) else { return }
        
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: notificationDate)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Bill Due Reminder", comment: "")
        let formattedAmount = bill.formattedAmount
        
        if bill.reminderDaysBefore == 0 {
            content.body = String(format: NSLocalizedString("%@ is due today (%@)!", comment: ""), bill.name, formattedAmount)
        } else {
            content.body = String(format: NSLocalizedString("%@ (%@) is due in %d days.", comment: ""), bill.name, formattedAmount, bill.reminderDaysBefore)
        }
        
        content.sound = .default
        content.badge = 1
        
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
                try await UNUserNotificationCenter.current().setBadgeCount(overdueCount)
            } catch {
                print("Failed to set badge count: \(error)")
            }
        }
    }
}
