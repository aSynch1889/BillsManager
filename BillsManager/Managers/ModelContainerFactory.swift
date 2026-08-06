import Foundation
import SwiftData

enum ModelContainerFactory {
    static let schema = Schema([
        Bill.self,
        Category.self,
        Account.self,
        PaymentRecord.self
    ])

    static let localConfigurationName = "LocalStore"
    static let cloudConfigurationName = "CloudStore"

    static func makeContainer(cloudSyncEnabled: Bool) throws -> ModelContainer {
        if cloudSyncEnabled {
            let config = ModelConfiguration(
                cloudConfigurationName,
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private(CloudSyncManager.containerIdentifier)
            )
            return try ModelContainer(for: schema, configurations: [config])
        }

        let config = ModelConfiguration(
            localConfigurationName,
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Copies data between local and cloud SwiftData stores when the user toggles sync.
    static func runPendingMigrationIfNeeded() throws {
        guard UserDefaults.standard.bool(forKey: CloudSyncManager.migrationPendingKey) else { return }

        let direction = UserDefaults.standard.string(forKey: CloudSyncManager.migrationDirectionKey) ?? "toCloud"
        let toCloud = direction == "toCloud"

        let sourceConfig = ModelConfiguration(
            toCloud ? localConfigurationName : cloudConfigurationName,
            schema: schema,
            cloudKitDatabase: toCloud ? .none : .private(CloudSyncManager.containerIdentifier)
        )
        let destConfig = ModelConfiguration(
            toCloud ? cloudConfigurationName : localConfigurationName,
            schema: schema,
            cloudKitDatabase: toCloud ? .private(CloudSyncManager.containerIdentifier) : .none
        )

        let sourceContainer = try ModelContainer(for: schema, configurations: [sourceConfig])
        let destContainer = try ModelContainer(for: schema, configurations: [destConfig])

        let sourceContext = ModelContext(sourceContainer)
        let destContext = ModelContext(destContainer)

        try copyAllData(from: sourceContext, to: destContext)
        try Persistence.save(destContext)

        UserDefaults.standard.set(false, forKey: CloudSyncManager.migrationPendingKey)
    }

    private static func copyAllData(from source: ModelContext, to destination: ModelContext) throws {
        let sourceCategories = try source.fetch(FetchDescriptor<Category>())
        let sourceAccounts = try source.fetch(FetchDescriptor<Account>())
        let sourceBills = try source.fetch(FetchDescriptor<Bill>())

        guard !(sourceCategories.isEmpty && sourceAccounts.isEmpty && sourceBills.isEmpty) else {
            return
        }

        var categoryMap: [UUID: Category] = [:]
        for item in sourceCategories {
            if category(by: item.id, in: destination) != nil { continue }
            let copy = Category(
                id: item.id,
                name: item.name,
                iconName: item.iconName,
                hexColor: item.hexColor,
                isSystem: item.isSystem
            )
            destination.insert(copy)
            categoryMap[item.id] = copy
        }
        for item in sourceCategories {
            if let existing = category(by: item.id, in: destination) {
                categoryMap[item.id] = existing
            }
        }

        var accountMap: [UUID: Account] = [:]
        for item in sourceAccounts {
            if account(by: item.id, in: destination) != nil { continue }
            let copy = Account(
                id: item.id,
                name: item.name,
                accountNumberLast4: item.accountNumberLast4,
                iconName: item.iconName,
                hexColor: item.hexColor,
                isDefault: item.isDefault
            )
            destination.insert(copy)
            accountMap[item.id] = copy
        }
        for item in sourceAccounts {
            if let existing = account(by: item.id, in: destination) {
                accountMap[item.id] = existing
            }
        }

        for item in sourceBills {
            if bill(by: item.id, in: destination) != nil { continue }

            let copy = Bill(
                id: item.id,
                name: item.name,
                amount: item.amount,
                currencyCode: item.currencyCode,
                dueDate: item.dueDate,
                isPaid: item.isPaid,
                isAutoPay: item.isAutoPay,
                frequency: item.frequency,
                repeatEndDate: item.repeatEndDate,
                recurrenceAnchorDay: item.recurrenceAnchorDay,
                reminderDaysBefore: item.reminderDaysBefore,
                reminderTime: item.reminderTime,
                notes: item.notes,
                isSample: item.isSample,
                attachmentImageData: item.attachmentImageData
            )
            if let categoryID = item.category?.id {
                copy.category = categoryMap[categoryID]
            }
            if let accountID = item.account?.id {
                copy.account = accountMap[accountID]
            }
            destination.insert(copy)

            for record in item.paymentHistory ?? [] {
                if paymentRecord(by: record.id, in: destination) != nil { continue }
                let recordCopy = PaymentRecord(
                    id: record.id,
                    paidDate: record.paidDate,
                    amountPaid: record.amountPaid,
                    periodDueDate: record.periodDueDate,
                    confirmationCode: record.confirmationCode,
                    notes: record.notes,
                    receiptImageData: record.receiptImageData
                )
                recordCopy.bill = copy
                destination.insert(recordCopy)
                copy.paymentHistory?.append(recordCopy)
            }
        }
    }

    private static func category(by id: UUID, in context: ModelContext) -> Category? {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private static func account(by id: UUID, in context: ModelContext) -> Account? {
        let descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private static func bill(by id: UUID, in context: ModelContext) -> Bill? {
        let descriptor = FetchDescriptor<Bill>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private static func paymentRecord(by id: UUID, in context: ModelContext) -> PaymentRecord? {
        let descriptor = FetchDescriptor<PaymentRecord>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}
