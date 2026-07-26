import SwiftUI
import SwiftData

@main
struct BillsManagerApp: App {
    @State private var authManager = BiometricAuthManager.shared
    @State private var storeManager = StoreManager.shared
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
        .modelContainer(container)
    }

    private func seedInitialDataIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Category>()
        let existingCategories = (try? context.fetch(descriptor)) ?? []
        
        if existingCategories.isEmpty {
            for cat in Category.defaults {
                context.insert(cat)
            }
            for acc in Account.defaults {
                context.insert(acc)
            }
            
            let utilitiesCat = Category.defaults.first(where: { $0.name == "Utilities" })
            let housingCat = Category.defaults.first(where: { $0.name == "Housing" })
            let subCat = Category.defaults.first(where: { $0.name == "Subscriptions" })
            let defaultAcc = Account.defaults.first(where: { $0.isDefault })
            
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
        }
    }
}
