import Foundation
import SwiftData

enum SampleDataSeeder {
    static let knownSampleNames: Set<String> = [
        "Electricity Bill",
        "Apartment Rent",
        "Streaming Subscription"
    ]

    /// Inserts three demo bills once. No-ops if any sample bills already exist.
    @discardableResult
    static func insertSamplesIfNeeded(context: ModelContext) -> Bool {
        let existing = (try? context.fetch(FetchDescriptor<Bill>())) ?? []
        if existing.contains(where: { $0.isSample || knownSampleNames.contains($0.name) }) {
            return false
        }

        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let utilitiesCat = categories.first(where: { $0.name == "Utilities" })
        let housingCat = categories.first(where: { $0.name == "Housing" })
        let subCat = categories.first(where: { $0.name == "Subscriptions" })
        let defaultAcc = accounts.first(where: { $0.isDefault }) ?? accounts.first

        let sample1 = Bill(
            name: "Electricity Bill",
            amount: 125.50,
            dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
            frequency: .monthly,
            isSample: true,
            category: utilitiesCat,
            account: defaultAcc
        )
        let sample2 = Bill(
            name: "Apartment Rent",
            amount: 1500.00,
            dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            frequency: .monthly,
            isSample: true,
            category: housingCat,
            account: defaultAcc
        )
        let sample3 = Bill(
            name: "Streaming Subscription",
            amount: 14.99,
            dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            isPaid: true,
            frequency: .monthly,
            isSample: true,
            category: subCat,
            account: defaultAcc
        )

        context.insert(sample1)
        context.insert(sample2)
        context.insert(sample3)
        try? context.save()
        return true
    }

    @discardableResult
    static func removeSamples(context: ModelContext) -> Int {
        let bills = (try? context.fetch(FetchDescriptor<Bill>())) ?? []
        let samples = bills.filter { $0.isSample || knownSampleNames.contains($0.name) }
        for bill in samples {
            NotificationManager.shared.cancelNotification(for: bill)
            context.delete(bill)
        }
        if !samples.isEmpty {
            try? context.save()
            NotificationManager.shared.refreshBadge(using: context)
        }
        return samples.count
    }

    static func sampleCount(in context: ModelContext) -> Int {
        let bills = (try? context.fetch(FetchDescriptor<Bill>())) ?? []
        return bills.filter { $0.isSample || knownSampleNames.contains($0.name) }.count
    }
}
