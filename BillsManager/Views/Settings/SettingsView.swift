import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(StoreManager.self) private var storeManager
    @Environment(BiometricAuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext
    
    @Query private var bills: [Bill]
    @Query private var categories: [Category]
    @Query private var accounts: [Account]
    
    @State private var showingPaywall: Bool = false
    @State private var showingCSVShareSheet: Bool = false
    @State private var csvShareURL: URL? = nil
    @State private var showingJSONShareSheet: Bool = false
    @State private var jsonShareURL: URL? = nil
    @State private var showingRestoreImporter: Bool = false
    @State private var pendingBackup: ExportManager.BackupData?
    @State private var showingRestoreModeDialog: Bool = false
    @State private var restoreSuccessMessage: String?
    
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"
    @AppStorage("defaultReminderDays") private var defaultReminderDays: Int = 1

    @State private var notificationStatusText: String = L10n.s("Checking…")
    @State private var notificationDenied: Bool = false
    @State private var sampleBillCount: Int = 0
    @State private var persistenceError: String?

    private static let commonCurrencyCodes = ["USD", "EUR", "GBP", "JPY", "CNY", "HKD", "AUD", "CAD", "SGD", "CHF"]
    
    var body: some View {
        List {
            // PRO
            Section {
                Button(action: { showingPaywall = true }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 48, height: 48)

                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(storeManager.isProUser ? L10n.s("PRO Version Active") : L10n.s("Upgrade to PRO"))
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(storeManager.isProUser ? L10n.s("All premium features unlocked") : L10n.s("Unlimited categories, backup & analytics"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if !storeManager.isProUser {
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            // General — language, preferences, notifications, app lock
            Section(header: Text(L10n.s("General"))) {
                NavigationLink {
                    LanguageSelectionView()
                } label: {
                    Label(L10n.s("Language"), systemImage: "globe")
                }

                Picker(L10n.s("Default Currency"), selection: $defaultCurrency) {
                    ForEach(Self.commonCurrencyCodes, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }

                Picker(L10n.s("Default Reminder"), selection: $defaultReminderDays) {
                    Text(L10n.s("On due date")).tag(0)
                    Text(L10n.s("1 day before")).tag(1)
                    Text(L10n.s("2 days before")).tag(2)
                    Text(L10n.s("3 days before")).tag(3)
                    Text(L10n.s("7 days before")).tag(7)
                }

                HStack {
                    Label(L10n.s("Permission Status"), systemImage: "bell.badge")
                    Spacer()
                    Text(notificationStatusText)
                        .foregroundStyle(.secondary)
                }

                if notificationDenied {
                    Button {
                        NotificationManager.shared.openSystemSettings()
                    } label: {
                        Label(L10n.s("Open System Settings"), systemImage: "gear")
                    }
                } else {
                    Button {
                        Task {
                            _ = await NotificationManager.shared.requestAuthorization()
                            await refreshNotificationStatus()
                        }
                    } label: {
                        Label(L10n.s("Enable Reminders"), systemImage: "bell.fill")
                    }
                }

                Toggle(isOn: Binding(
                    get: { authManager.isAppLockEnabled },
                    set: { newValue in
                        if newValue && !storeManager.canAccess(.appLock) {
                            showingPaywall = true
                            return
                        }
                        Task { @MainActor in
                            let succeeded = await authManager.setAppLockEnabled(newValue)
                            if !succeeded, let message = authManager.authError {
                                persistenceError = message
                            }
                        }
                    }
                )) {
                    Label(
                        String(format: L10n.s("Lock with %@"), authManager.biometricName),
                        systemImage: authManager.biometricType == .faceID ? "faceid" : "lock.fill"
                    )
                }
            }

            // Data — categories, accounts, samples, export & backup
            Section(header: Text(L10n.s("Data"))) {
                NavigationLink(destination: CategoryManagerView()) {
                    Label(L10n.s("Categories"), systemImage: "folder.fill")
                }

                NavigationLink(destination: AccountManagerView()) {
                    Label(L10n.s("Payment Accounts"), systemImage: "creditcard.fill")
                }

                if sampleBillCount > 0 {
                    Button(role: .destructive) {
                        do {
                            let removed = try SampleDataSeeder.removeSamples(context: modelContext)
                            sampleBillCount = max(0, sampleBillCount - removed)
                        } catch {
                            persistenceError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                        }
                    } label: {
                        Label(
                            String(format: L10n.s("Remove Sample Bills (%d)"), sampleBillCount),
                            systemImage: "trash"
                        )
                    }
                }

                Button(action: {
                    guard storeManager.canAccess(.exportBackup) else {
                        showingPaywall = true
                        return
                    }
                    exportCSV()
                }) {
                    Label(L10n.s("Export to CSV"), systemImage: "arrow.down.doc.fill")
                }

                Button(action: {
                    guard storeManager.canAccess(.exportBackup) else {
                        showingPaywall = true
                        return
                    }
                    exportJSONBackup()
                }) {
                    Label(L10n.s("Create JSON Backup"), systemImage: "externaldrive.fill")
                }

                Button(action: {
                    guard storeManager.canAccess(.exportBackup) else {
                        showingPaywall = true
                        return
                    }
                    showingRestoreImporter = true
                }) {
                    Label(L10n.s("Restore from JSON"), systemImage: "arrow.clockwise.icloud")
                }
            }

            // About — version + legal (no minimum iOS row)
            Section(header: Text(L10n.s("About"))) {
                HStack {
                    Text(L10n.s("App Version"))
                    Spacer()
                    Text(appVersionLabel)
                        .foregroundStyle(.secondary)
                }

                Link(destination: LegalLinks.privacyPolicy) {
                    Label(L10n.s("Privacy Policy"), systemImage: "hand.raised.fill")
                }

                Link(destination: LegalLinks.termsOfUse) {
                    Label(L10n.s("Terms of Use"), systemImage: "doc.plaintext")
                }

                Link(destination: LegalLinks.support) {
                    Label(L10n.s("Support"), systemImage: "questionmark.circle")
                }

                Text(L10n.s("Data is stored only on this device. There is no iCloud sync."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L10n.s("Settings"))
        .sheet(isPresented: $showingPaywall) {
            NavigationStack {
                PaywallView()
            }
        }
        .sheet(isPresented: $showingCSVShareSheet) {
            if let url = csvShareURL {
                ShareSheet(activityItems: [url])
            }
        }
        .sheet(isPresented: $showingJSONShareSheet) {
            if let url = jsonShareURL {
                ShareSheet(activityItems: [url])
            }
        }
        .fileImporter(
            isPresented: $showingRestoreImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleRestoreImport(result)
        }
        .confirmationDialog(
            L10n.s("Restore Backup"),
            isPresented: $showingRestoreModeDialog,
            titleVisibility: .visible
        ) {
            Button(L10n.s("Merge with Existing Data")) {
                performRestore(mode: .merge)
            }
            Button(L10n.s("Replace All Data"), role: .destructive) {
                performRestore(mode: .replace)
            }
            Button(L10n.s("Cancel"), role: .cancel) {
                pendingBackup = nil
            }
        } message: {
            if let backup = pendingBackup {
                Text(
                    String(
                        format: L10n.s("Backup from %@ — %d bills, %d categories, %d accounts. Choose merge or replace."),
                        backup.exportDate.formatted(date: .abbreviated, time: .shortened),
                        backup.bills.count,
                        backup.categories.count,
                        backup.accounts.count
                    )
                )
            }
        }
        .alert(L10n.s("Restore Complete"), isPresented: Binding(
            get: { restoreSuccessMessage != nil },
            set: { if !$0 { restoreSuccessMessage = nil } }
        )) {
            Button(L10n.s("OK"), role: .cancel) { restoreSuccessMessage = nil }
        } message: {
            Text(restoreSuccessMessage ?? "")
        }
        .task {
            await refreshNotificationStatus()
            sampleBillCount = SampleDataSeeder.sampleCount(in: modelContext)
        }
        .persistenceAlert($persistenceError)
    }

    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    @MainActor
    private func refreshNotificationStatus() async {
        let status = await NotificationManager.shared.authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            notificationStatusText = L10n.s("Enabled")
            notificationDenied = false
        case .denied:
            notificationStatusText = L10n.s("Denied")
            notificationDenied = true
        case .notDetermined:
            notificationStatusText = L10n.s("Not Asked")
            notificationDenied = false
        @unknown default:
            notificationStatusText = L10n.s("Unknown")
            notificationDenied = false
        }
    }
    
    private func exportCSV() {
        let csvString = ExportManager.shared.generateCSV(bills: bills)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("BillsExport_\(Date().timeIntervalSince1970).csv")
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            csvShareURL = tempURL
            showingCSVShareSheet = true
        } catch {
            persistenceError = PersistenceError.exportFailed(underlying: error).errorDescription
        }
    }
    
    private func exportJSONBackup() {
        do {
            let data = try ExportManager.shared.generateJSONBackup(bills: bills, categories: categories, accounts: accounts)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("BillsBackup_\(Date().timeIntervalSince1970).json")
            try data.write(to: tempURL)
            jsonShareURL = tempURL
            showingJSONShareSheet = true
        } catch {
            persistenceError = PersistenceError.exportFailed(underlying: error).errorDescription
        }
    }

    private func handleRestoreImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            persistenceError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                pendingBackup = try ExportManager.shared.decodeBackup(from: data)
                showingRestoreModeDialog = true
            } catch {
                persistenceError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func performRestore(mode: BackupRestoreMode) {
        guard let backup = pendingBackup else { return }
        pendingBackup = nil
        do {
            let counts = try ExportManager.shared.restoreBackup(backup, into: modelContext, mode: mode)
            sampleBillCount = SampleDataSeeder.sampleCount(in: modelContext)
            restoreSuccessMessage = String(
                format: L10n.s("Restored successfully. New items — categories: %d, accounts: %d, bills: %d."),
                counts.categories,
                counts.accounts,
                counts.bills
            )
        } catch {
            persistenceError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
