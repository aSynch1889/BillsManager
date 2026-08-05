import SwiftUI
import SwiftData

@main
struct BillsManagerApp: App {
    @State private var authManager = BiometricAuthManager.shared
    @State private var storeManager = StoreManager.shared
    @State private var languageManager = LanguageManager.shared
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showingSplash: Bool = true

    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                Bill.self,
                Category.self,
                Account.self,
                PaymentRecord.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
            
            seedInitialDataIfNeeded(context: container.mainContext)
        } catch {
            fatalError("Could not initialize SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootContentView {
                ZStack {
                    if showingSplash {
                        SplashView {
                            showingSplash = false
                        }
                        .transition(.opacity)
                    } else if !hasCompletedOnboarding {
                        OnboardingView()
                            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading)))
                    } else {
                        ZStack {
                            MainTabView()
                                .environment(authManager)
                                .environment(storeManager)

                            if authManager.isAppLockEnabled && !authManager.isUnlocked {
                                PasscodeLockView()
                                    .environment(authManager)
                                    .transition(.opacity)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.default, value: showingSplash)
                .animation(.default, value: hasCompletedOnboarding)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .background {
                        authManager.lockApp()
                    }
                }
            }
            .environment(languageManager)
            #if DEBUG
            .onAppear { LocalizationSelfCheck.run() }
            #endif
        }
        .modelContainer(container)
    }

    private func seedInitialDataIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Category>()
        let existingCategories = (try? context.fetch(descriptor)) ?? []
        
        if existingCategories.isEmpty {
            // Create defaults once and reuse the same instances for sample bill relationships.
            // Calling Category.defaults / Account.defaults again would allocate new @Model
            // objects and SwiftData would insert duplicates via bill associations.
            let defaultCategories = Category.defaults
            let defaultAccounts = Account.defaults
            defaultCategories.forEach(context.insert)
            defaultAccounts.forEach(context.insert)
            
            let utilitiesCat = defaultCategories.first(where: { $0.name == "Utilities" })
            let housingCat = defaultCategories.first(where: { $0.name == "Housing" })
            let subCat = defaultCategories.first(where: { $0.name == "Subscriptions" })
            let defaultAcc = defaultAccounts.first(where: { $0.isDefault })
            
            let sample1 = Bill(
                name: "Electricity Bill",
                amount: 125.50,
                dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
                frequency: .monthly,
                category: utilitiesCat,
                account: defaultAcc
            )
            
            let sample2 = Bill(
                name: "Apartment Rent",
                amount: 1500.00,
                dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                frequency: .monthly,
                category: housingCat,
                account: defaultAcc
            )
            
            let sample3 = Bill(
                name: "Streaming Subscription",
                amount: 14.99,
                dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                isPaid: true,
                frequency: .monthly,
                category: subCat,
                account: defaultAcc
            )
            
            context.insert(sample1)
            context.insert(sample2)
            context.insert(sample3)
            
            try? context.save()

            #if DEBUG
            assertSeedIntegrity(context: context, expectedCategories: defaultCategories, expectedAccounts: defaultAccounts)
            #endif
        }
    }

    #if DEBUG
    /// First-launch assertion: exactly 7 categories, 3 accounts, 3 sample bills, no duplicate names.
    private func assertSeedIntegrity(
        context: ModelContext,
        expectedCategories: [Category],
        expectedAccounts: [Account]
    ) {
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let bills = (try? context.fetch(FetchDescriptor<Bill>())) ?? []

        assert(categories.count == 7, "Seed expected 7 categories, got \(categories.count)")
        assert(accounts.count == 3, "Seed expected 3 accounts, got \(accounts.count)")
        assert(bills.count == 3, "Seed expected 3 sample bills, got \(bills.count)")

        let categoryNames = categories.map(\.name)
        let accountNames = accounts.map(\.name)
        assert(Set(categoryNames).count == categoryNames.count, "Duplicate category names after seed: \(categoryNames)")
        assert(Set(accountNames).count == accountNames.count, "Duplicate account names after seed: \(accountNames)")

        assert(Set(categories.map(\.id)) == Set(expectedCategories.map(\.id)),
               "Seed categories must be the same inserted instances")
        assert(Set(accounts.map(\.id)) == Set(expectedAccounts.map(\.id)),
               "Seed accounts must be the same inserted instances")
    }
    #endif
}
