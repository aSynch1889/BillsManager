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
                            Text(storeManager.isProUser ? NSLocalizedString("PRO Version Active", comment: "") : NSLocalizedString("Upgrade to PRO", comment: ""))
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text(storeManager.isProUser ? NSLocalizedString("All premium features unlocked", comment: "") : NSLocalizedString("Ad-free, unlimited categories, data backup", comment: ""))
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
            Section(header: Text(NSLocalizedString("Manage Data", comment: ""))) {
                NavigationLink(destination: CategoryManagerView()) {
                    Label(NSLocalizedString("Categories", comment: ""), systemImage: "folder.fill")
                }
                
                NavigationLink(destination: AccountManagerView()) {
                    Label(NSLocalizedString("Payment Accounts", comment: ""), systemImage: "creditcard.fill")
                }
            }
            
            // Security Section
            Section(header: Text(NSLocalizedString("Security & Privacy", comment: ""))) {
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
                        String(format: NSLocalizedString("Lock with %@", comment: ""), authManager.biometricName),
                        systemImage: authManager.biometricType == .faceID ? "faceid" : "lock.fill"
                    )
                }
            }
            
            // Backup & Export Section
            Section(header: Text(NSLocalizedString("Export & Backup", comment: ""))) {
                Button(action: exportCSV) {
                    Label(NSLocalizedString("Export to CSV", comment: ""), systemImage: "arrow.down.doc.fill")
                }
                
                Button(action: exportJSONBackup) {
                    Label(NSLocalizedString("Create JSON Backup", comment: ""), systemImage: "externaldrive.fill")
                }
            }
            
            // App Info Section
            Section(header: Text(NSLocalizedString("About", comment: ""))) {
                HStack {
                    Text(NSLocalizedString("App Version", comment: ""))
                    Spacer()
                    Text("1.0.0 (Build 1)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text(NSLocalizedString("Minimum iOS Required", comment: ""))
                    Spacer()
                    Text("iOS 17.0+")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(NSLocalizedString("Settings", comment: ""))
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
