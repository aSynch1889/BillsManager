import SwiftUI
import SwiftData

struct AccountManagerView: View {
    @Query private var accounts: [Account]
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var storeManager

    @State private var showingAddAccountSheet: Bool = false
    @State private var showingPaywall: Bool = false

    @State private var accountName: String = ""
    @State private var last4: String = ""
    @State private var iconName: String = "creditcard.fill"
    @State private var accountColor: Color = .blue
    @State private var persistenceError: String?

    var body: some View {
        List {
            if !storeManager.canAccess(.unlimitedAccounts) {
                Section {
                    Text(String(format: L10n.s("Free plan: %d / %d accounts"), accounts.count, ProFeature.freeAccountLimit))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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
                        Text(L10n.s("Default"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        modelContext.delete(account)
                        if let message = Persistence.saveReturningMessage(modelContext) {
                            persistenceError = message
                        }
                    } label: {
                        Label(L10n.s("Delete"), systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(L10n.s("Payment Accounts"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: attemptAddAccount) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddAccountSheet) {
            NavigationStack {
                Form {
                    Section(L10n.s("Account Info")) {
                        TextField(L10n.s("Account Name (e.g. Chase Visa)"), text: $accountName)
                        TextField(L10n.s("Last 4 Digits (Optional)"), text: $last4)
                            .keyboardType(.numberPad)

                        NavigationLink(destination: IconPickerView(selectedIcon: $iconName)) {
                            HStack {
                                Text(L10n.s("Icon"))
                                Spacer()
                                Image(systemName: iconName)
                                    .font(.title3)
                                    .foregroundStyle(accountColor)
                            }
                        }

                        ColorPicker(L10n.s("Color"), selection: $accountColor)
                    }
                }
                .navigationTitle(L10n.s("Add Account"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.s("Cancel")) { showingAddAccountSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.s("Save")) {
                            guard !accountName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            let trimmedLast4 = last4.trimmingCharacters(in: .whitespaces)
                            guard trimmedLast4.isEmpty || CurrencyFormatter.isValidLast4(trimmedLast4) else { return }
                            let newAcc = Account(
                                name: accountName,
                                accountNumberLast4: trimmedLast4.isEmpty ? nil : trimmedLast4,
                                iconName: iconName,
                                hexColor: accountColor.toHex(),
                                isDefault: accounts.isEmpty
                            )
                            modelContext.insert(newAcc)
                            if let message = Persistence.saveReturningMessage(modelContext) {
                                persistenceError = message
                                return
                            }
                            showingAddAccountSheet = false
                        }
                        .disabled(
                            accountName.trimmingCharacters(in: .whitespaces).isEmpty
                                || (!last4.trimmingCharacters(in: .whitespaces).isEmpty
                                    && !CurrencyFormatter.isValidLast4(last4.trimmingCharacters(in: .whitespaces)))
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            NavigationStack {
                PaywallView()
            }
        }
        .persistenceAlert($persistenceError)
    }

    private func attemptAddAccount() {
        guard storeManager.canAddAccount(currentCount: accounts.count) else {
            showingPaywall = true
            return
        }
        accountName = ""
        last4 = ""
        iconName = "creditcard.fill"
        accountColor = .blue
        showingAddAccountSheet = true
    }
}
