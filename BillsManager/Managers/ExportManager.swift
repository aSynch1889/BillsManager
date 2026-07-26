import Foundation
import SwiftData
import UniformTypeIdentifiers

final class ExportManager {
    static let shared = ExportManager()
    
    private init() {}
    
    func generateCSV(bills: [Bill]) -> String {
        var csv = "Name,Amount,Currency,Due Date,Status,Category,Account,Frequency,AutoPay,Notes\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        for bill in bills {
            let name = "\"\(bill.name.replacingOccurrences(of: "\"", with: "\"\""))\""
            let amount = String(format: "%.2f", bill.amount)
            let currency = bill.currencyCode
            let dueDate = dateFormatter.string(from: bill.dueDate)
            let status = bill.status.rawValue
            let category = "\"\(bill.category?.name ?? "Uncategorized")\""
            let account = "\"\(bill.account?.name ?? "None")\""
            let frequency = bill.frequency.rawValue
            let autoPay = bill.isAutoPay ? "Yes" : "No"
            let notes = "\"\(bill.notes?.replacingOccurrences(of: "\"", with: "\"\"") ?? "")\""
            
            let row = "\(name),\(amount),\(currency),\(dueDate),\(status),\(category),\(account),\(frequency),\(autoPay),\(notes)\n"
            csv.append(row)
        }
        
        return csv
    }
    
    struct BackupData: Codable {
        struct BillDTO: Codable {
            let id: UUID
            let name: String
            let amount: Double
            let currencyCode: String
            let dueDate: Date
            let isPaid: Bool
            let isAutoPay: Bool
            let frequencyRaw: String
            let categoryName: String?
            let accountName: String?
            let notes: String?
        }
        
        struct CategoryDTO: Codable {
            let name: String
            let iconName: String
            let hexColor: String
        }
        
        struct AccountDTO: Codable {
            let name: String
            let accountNumberLast4: String?
            let iconName: String
            let hexColor: String
        }
        
        let version: Int
        let exportDate: Date
        let categories: [CategoryDTO]
        let accounts: [AccountDTO]
        let bills: [BillDTO]
    }
    
    func generateJSONBackup(bills: [Bill], categories: [Category], accounts: [Account]) throws -> Data {
        let catDTOs = categories.map { BackupData.CategoryDTO(name: $0.name, iconName: $0.iconName, hexColor: $0.hexColor) }
        let accDTOs = accounts.map { BackupData.AccountDTO(name: $0.name, accountNumberLast4: $0.accountNumberLast4, iconName: $0.iconName, hexColor: $0.hexColor) }
        let billDTOs = bills.map {
            BackupData.BillDTO(
                id: $0.id,
                name: $0.name,
                amount: $0.amount,
                currencyCode: $0.currencyCode,
                dueDate: $0.dueDate,
                isPaid: $0.isPaid,
                isAutoPay: $0.isAutoPay,
                frequencyRaw: $0.frequencyRaw,
                categoryName: $0.category?.name,
                accountName: $0.account?.name,
                notes: $0.notes
            )
        }
        
        let backup = BackupData(
            version: 1,
            exportDate: Date(),
            categories: catDTOs,
            accounts: accDTOs,
            bills: billDTOs
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }
}
