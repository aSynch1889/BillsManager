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
        case .once: return L10n.s("One-time")
        case .daily: return L10n.s("Daily")
        case .weekly: return L10n.s("Weekly")
        case .biweekly: return L10n.s("Bi-weekly")
        case .monthly: return L10n.s("Monthly")
        case .bimonthly: return L10n.s("Every 2 Months")
        case .quarterly: return L10n.s("Quarterly")
        case .semiannually: return L10n.s("Semi-annually")
        case .yearly: return L10n.s("Yearly")
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
        case .overdue: return L10n.s("Overdue")
        case .dueToday: return L10n.s("Due Today")
        case .dueSoon: return L10n.s("Due Soon")
        case .upcoming: return L10n.s("Upcoming")
        case .paid: return L10n.s("Paid")
        }
    }
}
