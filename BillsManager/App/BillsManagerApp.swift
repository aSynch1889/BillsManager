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

            NotificationManager.shared.configure()
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
            // Create defaults once and reuse the same instances (never call .defaults twice).
            let defaultCategories = Category.defaults
            let defaultAccounts = Account.defaults
            defaultCategories.forEach(context.insert)
            defaultAccounts.forEach(context.insert)
            try? context.save()

            #if DEBUG
            assertSeedIntegrity(context: context, expectedCategories: defaultCategories, expectedAccounts: defaultAccounts)
            #endif
        }
    }

    #if DEBUG
    /// First-launch assertion: exactly 7 categories, 3 accounts, no duplicate names.
    private func assertSeedIntegrity(
        context: ModelContext,
        expectedCategories: [Category],
        expectedAccounts: [Account]
    ) {
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []

        assert(categories.count == 7, "Seed expected 7 categories, got \(categories.count)")
        assert(accounts.count == 3, "Seed expected 3 accounts, got \(accounts.count)")

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
