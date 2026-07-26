import Foundation
import SwiftData

@Model
final class PaymentRecord {
    var id: UUID
    var paidDate: Date
    var amountPaid: Double
    var confirmationCode: String?
    var notes: String?
    @Attribute(.externalStorage) var receiptImageData: Data?
    
    @Relationship(deleteRule: .nullify)
    var bill: Bill?
    
    init(id: UUID = UUID(), paidDate: Date = Date(), amountPaid: Double, confirmationCode: String? = nil, notes: String? = nil, receiptImageData: Data? = nil) {
        self.id = id
        self.paidDate = paidDate
        self.amountPaid = amountPaid
        self.confirmationCode = confirmationCode
        self.notes = notes
        self.receiptImageData = receiptImageData
    }
}
