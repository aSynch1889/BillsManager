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

    /// Months to add for calendar-month based frequencies; `nil` for non-month cadences.
    private var monthStep: Int? {
        switch self {
        case .monthly: return 1
        case .bimonthly: return 2
        case .quarterly: return 3
        case .semiannually: return 6
        case .yearly: return 12
        default: return nil
        }
    }

    /// Next due date. When `anchorDay` is set (1…31), month-based cadences land on that
    /// day-of-month (clamped to the month length) so `1/31 → 2/28 → 3/31` instead of drifting to `3/28`.
    func nextDueDate(from date: Date, anchorDay: Int? = nil) -> Date? {
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
        case .monthly, .bimonthly, .quarterly, .semiannually, .yearly:
            guard let step = monthStep,
                  let tentative = calendar.date(byAdding: .month, value: step, to: date) else {
                return nil
            }
            guard let anchorDay, (1...31).contains(anchorDay) else {
                return tentative
            }
            return Self.dateBySettingDay(anchorDay, inSameMonthAs: tentative, calendar: calendar, preservingTimeFrom: date)
        }
    }

    private static func dateBySettingDay(
        _ day: Int,
        inSameMonthAs reference: Date,
        calendar: Calendar,
        preservingTimeFrom timeSource: Date
    ) -> Date? {
        guard let dayRange = calendar.range(of: .day, in: .month, for: reference) else { return reference }
        let clampedDay = min(max(day, 1), dayRange.count)
        var comps = calendar.dateComponents([.year, .month], from: reference)
        comps.day = clampedDay
        let time = calendar.dateComponents([.hour, .minute, .second], from: timeSource)
        comps.hour = time.hour
        comps.minute = time.minute
        comps.second = time.second
        return calendar.date(from: comps)
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
