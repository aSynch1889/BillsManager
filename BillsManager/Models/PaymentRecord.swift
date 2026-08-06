import Foundation
import SwiftData

@Model
final class PaymentRecord {
    @Attribute(.unique) var id: UUID
    var paidDate: Date
    var amountPaid: Double
    /// The bill's `dueDate` for the period this payment settled (needed to undo recurring rolls).
    var periodDueDate: Date?
    var confirmationCode: String?
    var notes: String?
    @Attribute(.externalStorage) var receiptImageData: Data?

    @Relationship(deleteRule: .nullify)
    var bill: Bill?

    init(
        id: UUID = UUID(),
        paidDate: Date = Date(),
        amountPaid: Double,
        periodDueDate: Date? = nil,
        confirmationCode: String? = nil,
        notes: String? = nil,
        receiptImageData: Data? = nil
    ) {
        self.id = id
        self.paidDate = paidDate
        self.amountPaid = amountPaid
        self.periodDueDate = periodDueDate
        self.confirmationCode = confirmationCode
        self.notes = notes
        self.receiptImageData = receiptImageData
    }
}
