import SwiftUI
import SwiftData

@Model
final class Bill {
    var id: UUID
    var name: String
    var amount: Double
    var currencyCode: String
    var dueDate: Date
    var isPaid: Bool
    var isAutoPay: Bool
    var frequencyRaw: String
    var repeatEndDate: Date?
    /// Day-of-month (1…31) used to avoid monthly drift (e.g. Jan 31 → Feb 28 → Mar 31).
    var recurrenceAnchorDay: Int?
    var reminderDaysBefore: Int
    var reminderTime: Date
    var notes: String?
    @Attribute(.externalStorage) var attachmentImageData: Data?

    @Relationship
    var category: Category?

    @Relationship
    var account: Account?

    @Relationship(deleteRule: .cascade, inverse: \PaymentRecord.bill)
    var paymentHistory: [PaymentRecord]?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        currencyCode: String = Locale.current.currency?.identifier ?? "USD",
        dueDate: Date = Date(),
        isPaid: Bool = false,
        isAutoPay: Bool = false,
        frequency: BillFrequency = .monthly,
        repeatEndDate: Date? = nil,
        recurrenceAnchorDay: Int? = nil,
        reminderDaysBefore: Int = 1,
        reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date(),
        notes: String? = nil,
        attachmentImageData: Data? = nil,
        category: Category? = nil,
        account: Account? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.currencyCode = currencyCode
        self.dueDate = dueDate
        self.isPaid = isPaid
        self.isAutoPay = isAutoPay
        self.frequencyRaw = frequency.rawValue
        self.repeatEndDate = repeatEndDate
        self.recurrenceAnchorDay = recurrenceAnchorDay
            ?? Calendar.current.component(.day, from: dueDate)
        self.reminderDaysBefore = reminderDaysBefore
        self.reminderTime = reminderTime
        self.notes = notes
        self.attachmentImageData = attachmentImageData
        self.category = category
        self.account = account
        self.paymentHistory = []
    }

    var frequency: BillFrequency {
        get { BillFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    var status: BillStatus {
        if isPaid { return .paid }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: dueDate)

        if dueDay < today {
            return .overdue
        } else if dueDay == today {
            return .dueToday
        } else {
            let components = calendar.dateComponents([.day], from: today, to: dueDay)
            if let days = components.day, days <= 3 {
                return .dueSoon
            }
            return .upcoming
        }
    }

    var statusColor: Color {
        switch status {
        case .overdue: return .red
        case .dueToday: return .orange
        case .dueSoon: return .yellow
        case .upcoming: return .blue
        case .paid: return .green
        }
    }

    var formattedAmount: String {
        CurrencyFormatter.string(amount: amount, currencyCode: currencyCode)
    }

    var hasPaymentHistory: Bool {
        !(paymentHistory?.isEmpty ?? true)
    }

    /// Product rule: **one Mark Paid = one period**.
    /// Advances `dueDate` exactly once (anchor-aware). Multi-period overdue requires multiple pays
    /// so each period gets its own `PaymentRecord`.
    func markAsPaid(paidAmount: Double? = nil, confirmationCode: String? = nil, notes: String? = nil, receiptData: Data? = nil) {
        let periodDueDate = dueDate
        let record = PaymentRecord(
            paidDate: Date(),
            amountPaid: paidAmount ?? amount,
            periodDueDate: periodDueDate,
            confirmationCode: confirmationCode,
            notes: notes,
            receiptImageData: receiptData
        )
        if paymentHistory == nil {
            paymentHistory = []
        }
        paymentHistory?.append(record)

        if frequency == .once {
            isPaid = true
            return
        }

        guard let nextDate = frequency.nextDueDate(from: dueDate, anchorDay: effectiveAnchorDay) else {
            isPaid = true
            return
        }

        if let endDate = repeatEndDate, nextDate > endDate {
            isPaid = true
        } else {
            dueDate = nextDate
            isPaid = false
        }
    }

    /// Restores the last paid period's due date and returns the record so the caller can delete it from the context.
    @discardableResult
    func undoLastPayment() -> PaymentRecord? {
        guard let history = paymentHistory, !history.isEmpty else {
            isPaid = false
            return nil
        }

        let last = history.max(by: { $0.paidDate < $1.paidDate })!
        if let period = last.periodDueDate {
            dueDate = period
        }
        paymentHistory?.removeAll { $0.id == last.id }
        isPaid = false
        return last
    }

    /// Prefer stored anchor; fall back to current due day for legacy rows.
    var effectiveAnchorDay: Int {
        if let recurrenceAnchorDay, (1...31).contains(recurrenceAnchorDay) {
            return recurrenceAnchorDay
        }
        return Calendar.current.component(.day, from: dueDate)
    }

    func syncRecurrenceAnchor(from date: Date) {
        recurrenceAnchorDay = Calendar.current.component(.day, from: date)
    }
}
