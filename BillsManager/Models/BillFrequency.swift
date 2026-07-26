import Foundation

enum BillFrequency: String, Codable, CaseIterable, Identifiable {
    case once = "Once"
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case monthly = "Monthly"
    case bimonthly = "Bi-monthly"
    case quarterly = "Quarterly"
    case semiannually = "Semi-annually"
    case yearly = "Yearly"
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .once: return NSLocalizedString("One-time", comment: "")
        case .daily: return NSLocalizedString("Daily", comment: "")
        case .weekly: return NSLocalizedString("Weekly", comment: "")
        case .biweekly: return NSLocalizedString("Bi-weekly", comment: "")
        case .monthly: return NSLocalizedString("Monthly", comment: "")
        case .bimonthly: return NSLocalizedString("Every 2 Months", comment: "")
        case .quarterly: return NSLocalizedString("Quarterly", comment: "")
        case .semiannually: return NSLocalizedString("Semi-annually", comment: "")
        case .yearly: return NSLocalizedString("Yearly", comment: "")
        }
    }
    
    func nextDueDate(from date: Date) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .once:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .bimonthly:
            return calendar.date(byAdding: .month, value: 2, to: date)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date)
        case .semiannually:
            return calendar.date(byAdding: .month, value: 6, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
}

enum BillStatus: String, Codable, CaseIterable {
    case overdue = "Overdue"
    case dueToday = "Due Today"
    case dueSoon = "Due Soon"
    case upcoming = "Upcoming"
    case paid = "Paid"
    
    var localizedName: String {
        switch self {
        case .overdue: return NSLocalizedString("Overdue", comment: "")
        case .dueToday: return NSLocalizedString("Due Today", comment: "")
        case .dueSoon: return NSLocalizedString("Due Soon", comment: "")
        case .upcoming: return NSLocalizedString("Upcoming", comment: "")
        case .paid: return NSLocalizedString("Paid", comment: "")
        }
    }
}
