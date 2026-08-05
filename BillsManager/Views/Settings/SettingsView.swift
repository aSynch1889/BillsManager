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
    
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"
    @AppStorage("defaultReminderDays") private var defaultReminderDays: Int = 1

    @State private var notificationStatusText: String = L10n.s("Checking…")
    @State private var notificationDenied: Bool = false

    private static let commonCurrencyCodes = ["USD", "EUR", "GBP", "JPY", "CNY", "HKD", "AUD", "CAD", "SGD", "CHF"]
    
    var body: some View {
        List {
            // Pro Subscription Header Banner
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
                            
                            Text(storeManager.isProUser ? L10n.s("All premium features unlocked") : L10n.s("Ad-free, unlimited categories, data backup"))
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
            
            // Management Section
            Section(header: Text(L10n.s("Manage Data"))) {
                NavigationLink(destination: CategoryManagerView()) {
                    Label(L10n.s("Categories"), systemImage: "folder.fill")
                }
                
                NavigationLink(destination: AccountManagerView()) {
                    Label(L10n.s("Payment Accounts"), systemImage: "creditcard.fill")
                }
            }
            
            // Preferences
            Section(header: Text(L10n.s("Preferences"))) {
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
            }

            // Notifications
            Section(header: Text(L10n.s("Notifications"))) {
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
            }

            // Security Section
            Section(header: Text(L10n.s("Security & Privacy"))) {
                Toggle(isOn: Binding(
                    get: { authManager.isAppLockEnabled },
                    set: { newValue in
                        authManager.isAppLockEnabled = newValue
                        if newValue {
                            Task {
                                _ = await authManager.authenticate()
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
            
            // Backup & Export Section
            Section(header: Text(L10n.s("Export & Backup"))) {
                Button(action: exportCSV) {
                    Label(L10n.s("Export to CSV"), systemImage: "arrow.down.doc.fill")
                }
                
                Button(action: exportJSONBackup) {
                    Label(L10n.s("Create JSON Backup"), systemImage: "externaldrive.fill")
                }
            }
            
            // Language Section
            Section {
                NavigationLink {
                    LanguageSelectionView()
                } label: {
                    Label(L10n.s("Language"), systemImage: "globe")
                }
            }

            // App Info Section
            Section(header: Text(L10n.s("About"))) {
                HStack {
                    Text(L10n.s("App Version"))
                    Spacer()
                    Text("1.0.0 (Build 1)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text(L10n.s("Minimum iOS Required"))
                    Spacer()
                    Text("iOS 17.0+")
                        .foregroundStyle(.secondary)
                }
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
        .task {
            await refreshNotificationStatus()
        }
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
        try? csvString.write(to: tempURL, atomically: true, encoding: .utf8)
        csvShareURL = tempURL
        showingCSVShareSheet = true
    }
    
    private func exportJSONBackup() {
        if let data = try? ExportManager.shared.generateJSONBackup(bills: bills, categories: categories, accounts: accounts) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("BillsBackup_\(Date().timeIntervalSince1970).json")
            try? data.write(to: tempURL)
            jsonShareURL = tempURL
            showingJSONShareSheet = true
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
