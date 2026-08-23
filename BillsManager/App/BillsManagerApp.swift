import SwiftUI
import SwiftData

@main
struct BillsManagerApp: App {
    @State private var authManager = BiometricAuthManager.shared
    @State private var storeManager = StoreManager.shared
    @State private var languageManager = LanguageManager.shared
    @State private var cloudSyncManager = CloudSyncManager.shared
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showingSplash: Bool = true

    private let bootstrap: BootstrapResult

    private enum BootstrapResult {
        case ready(ModelContainer)
        case failed(Error)
    }

    init() {
        do {
            do {
                try ModelContainerFactory.runPendingMigrationIfNeeded()
            } catch {
                // Stay on the local store rather than blocking launch after a CloudKit copy failure.
            }
            if CloudSyncManager.shared.isSyncEnabled && !StoreManager.cachedProEntitlement {
                _ = CloudSyncManager.shared.disableSyncDueToProExpiration()
                do {
                    try ModelContainerFactory.runPendingMigrationIfNeeded()
                } catch {
                    CloudSyncManager.shared.abortFailedCloudOpen()
                }
            }
            let container: ModelContainer
            do {
                container = try ModelContainerFactory.makeContainer(
                    cloudSyncEnabled: CloudSyncManager.shouldUseCloudKit
                )
            } catch {
                guard CloudSyncManager.shouldUseCloudKit else { throw error }
                CloudSyncManager.shared.abortFailedCloudOpen()
                container = try ModelContainerFactory.makeContainer(cloudSyncEnabled: false)
            }

            NotificationManager.shared.configure()
            Self.seedInitialDataIfNeeded(context: container.mainContext)
            if !UserDefaults.standard.bool(forKey: CloudSyncManager.migrationPendingKey) {
                CloudSyncManager.shared.acknowledgeRestartRequired()
            }
            bootstrap = .ready(container)
        } catch {
            bootstrap = .failed(error)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .ready(let container):
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
                                    .environment(cloudSyncManager)

                                if authManager.isAppLockEnabled && !authManager.isUnlocked {
                                    PasscodeLockView()
                                        .environment(authManager)
                                        .transition(.opacity)
                                }

                                if authManager.showPrivacyBlur {
                                    PrivacyBlurOverlay()
                                        .transition(.opacity)
                                        .zIndex(100)
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                    .animation(.default, value: showingSplash)
                    .animation(.default, value: hasCompletedOnboarding)
                    .onChange(of: scenePhase) { _, newPhase in
                        authManager.handleScenePhase(newPhase)
                        if newPhase == .active {
                            Task { await storeManager.updatePurchasedProducts() }
                        }
                    }
                }
                .environment(languageManager)
                #if DEBUG
                .onAppear { LocalizationSelfCheck.run() }
                #endif
                .modelContainer(container)

            case .failed(let error):
                DatabaseLaunchErrorView(error: error)
                    .environment(languageManager)
            }
        }
    }

    private static func seedInitialDataIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Category>()
        let existingCategories = (try? context.fetch(descriptor)) ?? []

        if existingCategories.isEmpty {
            let defaultCategories = Category.defaults
            let defaultAccounts = Account.defaults
            defaultCategories.forEach(context.insert)
            defaultAccounts.forEach(context.insert)
            do {
                try Persistence.save(context)
            } catch {
                print("Seed save failed: \(error)")
                return
            }

            #if DEBUG
            assertSeedIntegrity(context: context, expectedCategories: defaultCategories, expectedAccounts: defaultAccounts)
            #endif
        }
    }

    #if DEBUG
    private static func assertSeedIntegrity(
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
