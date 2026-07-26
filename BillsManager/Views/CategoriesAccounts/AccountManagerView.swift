import SwiftUI
import SwiftData

struct AccountManagerView: View {
    @Query private var accounts: [Account]
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingAddAccountSheet: Bool = false
    
    @State private var accountName: String = ""
    @State private var last4: String = ""
    @State private var iconName: String = "creditcard.fill"
    @State private var accountColor: Color = .blue
    
    var body: some View {
        List {
            ForEach(accounts) { account in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(account.color)
                            .frame(width: 36, height: 36)
                        Image(systemName: account.iconName)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name)
                            .font(.body.weight(.medium))
                        if let last4 = account.accountNumberLast4, !last4.isEmpty {
                            Text("•••• \(last4)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if account.isDefault {
                        Text(NSLocalizedString("Default", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        modelContext.delete(account)
                        try? modelContext.save()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("Payment Accounts", comment: ""))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    accountName = ""
                    last4 = ""
                    iconName = "creditcard.fill"
                    accountColor = .blue
                    showingAddAccountSheet = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddAccountSheet) {
            NavigationStack {
                Form {
                    Section(NSLocalizedString("Account Info", comment: "")) {
                        TextField(NSLocalizedString("Account Name (e.g. Chase Visa)", comment: ""), text: $accountName)
                        TextField(NSLocalizedString("Last 4 Digits (Optional)", comment: ""), text: $last4)
                            .keyboardType(.numberPad)
                        
                        NavigationLink(destination: IconPickerView(selectedIcon: $iconName)) {
                            HStack {
                                Text(NSLocalizedString("Icon", comment: ""))
                                Spacer()
                                Image(systemName: iconName)
                                    .font(.title3)
                                    .foregroundStyle(accountColor)
                            }
                        }
                        
                        ColorPicker(NSLocalizedString("Color", comment: ""), selection: $accountColor)
                    }
                }
                .navigationTitle(NSLocalizedString("Add Account", comment: ""))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingAddAccountSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard !accountName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            let newAcc = Account(
                                name: accountName,
                                accountNumberLast4: last4.isEmpty ? nil : last4,
                                iconName: iconName,
                                hexColor: accountColor.toHex(),
                                isDefault: accounts.isEmpty
                            )
                            modelContext.insert(newAcc)
                            try? modelContext.save()
                            showingAddAccountSheet = false
                        }
                        .disabled(accountName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }
}
