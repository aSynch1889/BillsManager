import Foundation
import SwiftData
import UniformTypeIdentifiers

enum BackupRestoreMode {
    /// Keep existing rows; upsert categories/accounts/bills by UUID (name fallback for v1).
    case merge
    /// Delete all bills, categories, and accounts, then insert from backup.
    case replace
}

enum BackupError: LocalizedError {
    case unsupportedVersion(Int)
    case emptyBackup
    case decodeFailed(underlying: Error)
    case restoreFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v):
            return String(format: L10n.s("Unsupported backup version: %d"), v)
        case .emptyBackup:
            return L10n.s("This backup file has no data.")
        case .decodeFailed:
            return L10n.s("Couldn't read the backup file. Please try again.")
        case .restoreFailed:
            return L10n.s("Couldn't restore from backup. Please try again.")
        }
    }

    var failureReason: String? {
        switch self {
        case .decodeFailed(let error), .restoreFailed(let error):
            return error.localizedDescription
        default:
            return nil
        }
    }
}

final class ExportManager {
    static let shared = ExportManager()

    /// Current on-disk backup schema. v1 backups remain readable.
    static let currentBackupVersion = 2

    private init() {}

    // MARK: - CSV

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

    // MARK: - Backup DTOs

    struct BackupData: Codable {
        struct PaymentRecordDTO: Codable {
            let id: UUID
            let paidDate: Date
            let amountPaid: Double
            let periodDueDate: Date?
            let confirmationCode: String?
            let notes: String?
            let receiptImageBase64: String?
        }

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

            // v2 fields (optional for v1 decode)
            let categoryID: UUID?
            let accountID: UUID?
            let repeatEndDate: Date?
            let recurrenceAnchorDay: Int?
            let reminderDaysBefore: Int?
            let reminderTime: Date?
            let isSample: Bool?
            let attachmentImageBase64: String?
            let paymentHistory: [PaymentRecordDTO]?
        }

        struct CategoryDTO: Codable {
            let id: UUID?
            let name: String
            let iconName: String
            let hexColor: String
            let isSystem: Bool?
        }

        struct AccountDTO: Codable {
            let id: UUID?
            let name: String
            let accountNumberLast4: String?
            let iconName: String
            let hexColor: String
            let isDefault: Bool?
        }

        let version: Int
        let exportDate: Date
        let categories: [CategoryDTO]
        let accounts: [AccountDTO]
        let bills: [BillDTO]
    }

    // MARK: - Export

    func generateJSONBackup(bills: [Bill], categories: [Category], accounts: [Account]) throws -> Data {
        let catDTOs = categories.map {
            BackupData.CategoryDTO(
                id: $0.id,
                name: $0.name,
                iconName: $0.iconName,
                hexColor: $0.hexColor,
                isSystem: $0.isSystem
            )
        }
        let accDTOs = accounts.map {
            BackupData.AccountDTO(
                id: $0.id,
                name: $0.name,
                accountNumberLast4: $0.accountNumberLast4,
                iconName: $0.iconName,
                hexColor: $0.hexColor,
                isDefault: $0.isDefault
            )
        }
        let billDTOs = bills.map { bill -> BackupData.BillDTO in
            let history = (bill.paymentHistory ?? []).map { record in
                BackupData.PaymentRecordDTO(
                    id: record.id,
                    paidDate: record.paidDate,
                    amountPaid: record.amountPaid,
                    periodDueDate: record.periodDueDate,
                    confirmationCode: record.confirmationCode,
                    notes: record.notes,
                    receiptImageBase64: record.receiptImageData?.base64EncodedString()
                )
            }
            return BackupData.BillDTO(
                id: bill.id,
                name: bill.name,
                amount: bill.amount,
                currencyCode: bill.currencyCode,
                dueDate: bill.dueDate,
                isPaid: bill.isPaid,
                isAutoPay: bill.isAutoPay,
                frequencyRaw: bill.frequencyRaw,
                categoryName: bill.category?.name,
                accountName: bill.account?.name,
                notes: bill.notes,
                categoryID: bill.category?.id,
                accountID: bill.account?.id,
                repeatEndDate: bill.repeatEndDate,
                recurrenceAnchorDay: bill.recurrenceAnchorDay,
                reminderDaysBefore: bill.reminderDaysBefore,
                reminderTime: bill.reminderTime,
                isSample: bill.isSample,
                attachmentImageBase64: bill.attachmentImageData?.base64EncodedString(),
                paymentHistory: history
            )
        }

        let backup = BackupData(
            version: Self.currentBackupVersion,
            exportDate: Date(),
            categories: catDTOs,
            accounts: accDTOs,
            bills: billDTOs
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    // MARK: - Import / Restore

    func decodeBackup(from data: Data) throws -> BackupData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let backup = try decoder.decode(BackupData.self, from: data)
            guard backup.version == 1 || backup.version == 2 else {
                throw BackupError.unsupportedVersion(backup.version)
            }
            if backup.categories.isEmpty && backup.accounts.isEmpty && backup.bills.isEmpty {
                throw BackupError.emptyBackup
            }
            return backup
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.decodeFailed(underlying: error)
        }
    }

    /// Restores backup into `context`. Caller should present confirmation UI first.
    @discardableResult
    func restoreBackup(
        _ backup: BackupData,
        into context: ModelContext,
        mode: BackupRestoreMode
    ) throws -> (categories: Int, accounts: Int, bills: Int) {
        do {
            switch mode {
            case .replace:
                try clearAllData(in: context)
            case .merge:
                break
            }

            var categoryByID = Dictionary(
                uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Category>())) ?? []).map { ($0.id, $0) }
            )
            var categoryByName = Dictionary(
                uniqueKeysWithValues: categoryByID.values.map { ($0.name.lowercased(), $0) }
            )
            var accountByID = Dictionary(
                uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Account>())) ?? []).map { ($0.id, $0) }
            )
            var accountByName = Dictionary(
                uniqueKeysWithValues: accountByID.values.map { ($0.name.lowercased(), $0) }
            )
            var billByID = Dictionary(
                uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Bill>())) ?? []).map { ($0.id, $0) }
            )

            var categoryCount = 0
            for dto in backup.categories {
                let resolvedID = dto.id ?? UUID()
                if let existing = categoryByID[resolvedID]
                    ?? categoryByName[dto.name.lowercased()] {
                    existing.name = dto.name
                    existing.iconName = dto.iconName
                    existing.hexColor = dto.hexColor
                    if let isSystem = dto.isSystem {
                        existing.isSystem = isSystem
                    }
                    categoryByID[existing.id] = existing
                    categoryByName[existing.name.lowercased()] = existing
                } else {
                    let category = Category(
                        id: resolvedID,
                        name: dto.name,
                        iconName: dto.iconName,
                        hexColor: dto.hexColor,
                        isSystem: dto.isSystem ?? false
                    )
                    context.insert(category)
                    categoryByID[category.id] = category
                    categoryByName[category.name.lowercased()] = category
                    categoryCount += 1
                }
            }

            var accountCount = 0
            for dto in backup.accounts {
                let resolvedID = dto.id ?? UUID()
                if let existing = accountByID[resolvedID]
                    ?? accountByName[dto.name.lowercased()] {
                    existing.name = dto.name
                    existing.accountNumberLast4 = dto.accountNumberLast4
                    existing.iconName = dto.iconName
                    existing.hexColor = dto.hexColor
                    if let isDefault = dto.isDefault {
                        existing.isDefault = isDefault
                    }
                    accountByID[existing.id] = existing
                    accountByName[existing.name.lowercased()] = existing
                } else {
                    let account = Account(
                        id: resolvedID,
                        name: dto.name,
                        accountNumberLast4: dto.accountNumberLast4,
                        iconName: dto.iconName,
                        hexColor: dto.hexColor,
                        isDefault: dto.isDefault ?? false
                    )
                    context.insert(account)
                    accountByID[account.id] = account
                    accountByName[account.name.lowercased()] = account
                    accountCount += 1
                }
            }

            let defaultReminderTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
            var billCount = 0

            for dto in backup.bills {
                let category: Category? = {
                    if let id = dto.categoryID, let match = categoryByID[id] { return match }
                    if let name = dto.categoryName { return categoryByName[name.lowercased()] }
                    return nil
                }()
                let account: Account? = {
                    if let id = dto.accountID, let match = accountByID[id] { return match }
                    if let name = dto.accountName { return accountByName[name.lowercased()] }
                    return nil
                }()

                let bill: Bill
                if let existing = billByID[dto.id] {
                    bill = existing
                } else {
                    bill = Bill(
                        id: dto.id,
                        name: dto.name,
                        amount: dto.amount,
                        currencyCode: dto.currencyCode,
                        dueDate: dto.dueDate,
                        isPaid: dto.isPaid,
                        isAutoPay: dto.isAutoPay,
                        frequency: BillFrequency(rawValue: dto.frequencyRaw) ?? .monthly
                    )
                    context.insert(bill)
                    billByID[bill.id] = bill
                    billCount += 1
                }

                bill.name = dto.name
                bill.amount = dto.amount
                bill.currencyCode = dto.currencyCode
                bill.dueDate = dto.dueDate
                bill.isPaid = dto.isPaid
                bill.isAutoPay = dto.isAutoPay
                bill.frequencyRaw = dto.frequencyRaw
                bill.notes = dto.notes
                bill.repeatEndDate = dto.repeatEndDate
                bill.recurrenceAnchorDay = dto.recurrenceAnchorDay
                    ?? Calendar.current.component(.day, from: dto.dueDate)
                bill.reminderDaysBefore = dto.reminderDaysBefore ?? 1
                bill.reminderTime = dto.reminderTime ?? defaultReminderTime
                bill.isSample = dto.isSample ?? false
                if let attachment = dto.attachmentImageBase64 {
                    bill.attachmentImageData = Data(base64Encoded: attachment)
                }
                bill.category = category
                bill.account = account

                // Replace payment history from backup when provided (v2).
                if let historyDTOs = dto.paymentHistory {
                    if let existingHistory = bill.paymentHistory {
                        for record in existingHistory {
                            context.delete(record)
                        }
                    }
                    bill.paymentHistory = []
                    for recordDTO in historyDTOs {
                        let record = PaymentRecord(
                            id: recordDTO.id,
                            paidDate: recordDTO.paidDate,
                            amountPaid: recordDTO.amountPaid,
                            periodDueDate: recordDTO.periodDueDate,
                            confirmationCode: recordDTO.confirmationCode,
                            notes: recordDTO.notes,
                            receiptImageData: recordDTO.receiptImageBase64.flatMap { Data(base64Encoded: $0) }
                        )
                        record.bill = bill
                        context.insert(record)
                        bill.paymentHistory?.append(record)
                    }
                }
            }

            try Persistence.save(context)

            // Reschedule notifications for restored unpaid bills and refresh badge.
            let allBills = (try? context.fetch(FetchDescriptor<Bill>())) ?? []
            for bill in allBills {
                if bill.isPaid {
                    NotificationManager.shared.cancelNotification(for: bill)
                } else {
                    NotificationManager.shared.scheduleNotification(for: bill)
                }
            }
            NotificationManager.shared.refreshBadge(using: context)

            return (categoryCount, accountCount, billCount)
        } catch let error as BackupError {
            throw error
        } catch let error as PersistenceError {
            throw BackupError.restoreFailed(underlying: error)
        } catch {
            throw BackupError.restoreFailed(underlying: error)
        }
    }

    private func clearAllData(in context: ModelContext) throws {
        let bills = try context.fetch(FetchDescriptor<Bill>())
        for bill in bills {
            NotificationManager.shared.cancelNotification(for: bill)
            context.delete(bill)
        }
        let categories = try context.fetch(FetchDescriptor<Category>())
        for category in categories {
            context.delete(category)
        }
        let accounts = try context.fetch(FetchDescriptor<Account>())
        for account in accounts {
            context.delete(account)
        }
        try Persistence.save(context)
    }
}
