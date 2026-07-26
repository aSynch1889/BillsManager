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
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
    }
    
    func markAsPaid(paidAmount: Double? = nil, confirmationCode: String? = nil, notes: String? = nil, receiptData: Data? = nil) {
        let record = PaymentRecord(
            paidDate: Date(),
            amountPaid: paidAmount ?? amount,
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
        } else {
            // Recurring bill: advance due date to next period if within end date
            if let nextDate = frequency.nextDueDate(from: dueDate) {
                if let endDate = repeatEndDate, nextDate > endDate {
                    isPaid = true
                } else {
                    dueDate = nextDate
                    isPaid = false
                }
            } else {
                isPaid = true
            }
        }
    }
    
    func markAsUnpaid() {
        isPaid = false
    }
}
