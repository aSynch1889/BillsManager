import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProductID: String = StoreManager.yearlyProID
    @State private var restoreAlertTitle: String = ""
    @State private var restoreAlertMessage: String = ""
    @State private var showingRestoreAlert: Bool = false
    @State private var purchaseAlertMessage: String?
    
    private var selectedProduct: Product? {
        storeManager.products.first(where: { $0.id == selectedProductID }) ?? storeManager.products.first
    }

    private var isSelectedSubscription: Bool {
        selectedProductID == StoreManager.monthlyProID || selectedProductID == StoreManager.yearlyProID
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.orange, .amber], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white)
                    }
                    
                    Text(L10n.s("Bills Manager PRO"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    
                    Text(L10n.s("Choose monthly, yearly, or lifetime. Unlock PRO on this Apple ID."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 24)
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "icloud.fill", color: .cyan, title: L10n.s("iCloud Sync"), subtitle: L10n.s("Optional private iCloud sync across your iPhone and iPad (off by default)."))
                    FeatureRow(icon: "folder.badge.plus", color: .purple, title: L10n.s("Unlimited Categories & Accounts"), subtitle: L10n.s("Create unlimited custom expense categories"))
                    FeatureRow(icon: "square.and.arrow.up.fill", color: .blue, title: L10n.s("CSV Export & JSON Backup"), subtitle: L10n.s("Export all bill records to CSV or backup database"))
                    FeatureRow(icon: "lock.shield.fill", color: .green, title: L10n.s("Face ID / Touch ID Security"), subtitle: L10n.s("Secure bill data with biometric lock on device."))
                    FeatureRow(icon: "chart.pie.fill", color: .orange, title: L10n.s("Advanced Analytics"), subtitle: L10n.s("Category breakdown with paid vs due metrics"))
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal)
                
                if storeManager.isLoadingProducts {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(L10n.s("Loading Products..."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else if storeManager.products.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundStyle(.orange)
                        Text(storeManager.productsLoadErrorMessage ?? L10n.s("No products available. Check your network or try again."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Text(L10n.s("Expected: monthly, yearly, and lifetime PRO products."))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                        Button(L10n.s("Retry")) {
                            Task { await storeManager.loadProducts() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        ForEach(storeManager.products, id: \.id) { product in
                            Button(action: { selectedProductID = product.id }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(productDisplayName(product))
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        if let length = subscriptionPeriodText(product) {
                                            Text(String(format: L10n.s("Length: %@"), length))
                                                .font(.caption.bold())
                                                .foregroundStyle(.secondary)
                                        } else if product.id == StoreManager.lifetimeProID {
                                            Text(L10n.s("One-time purchase · never expires"))
                                                .font(.caption.bold())
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(product.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(priceWithPeriod(product))
                                        .font(.title3.bold())
                                        .foregroundStyle(.blue)
                                        .multilineTextAlignment(.trailing)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(productAccessibilityLabel(product))
                                .padding()
                                .background(selectedProductID == product.id ? Color.blue.opacity(0.12) : Color(.secondarySystemGroupedBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(selectedProductID == product.id ? Color.blue : Color.clear, lineWidth: 2)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                
                VStack(spacing: 12) {
                    if let selectedProduct {
                        Button(action: {
                            Task {
                                let success = await storeManager.purchase(selectedProduct)
                                if success {
                                    dismiss()
                                } else if let err = storeManager.purchaseErrorMessage {
                                    purchaseAlertMessage = err
                                }
                            }
                        }) {
                            Text(String(format: L10n.s("Continue with %@"), priceWithPeriod(selectedProduct)))
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    
                    Button(action: {
                        Task {
                            let ok = await storeManager.restorePurchases()
                            if ok && storeManager.isProUser {
                                restoreAlertTitle = L10n.s("Purchases Restored")
                                restoreAlertMessage = L10n.s("Your PRO access has been restored.")
                                showingRestoreAlert = true
                            } else if ok {
                                restoreAlertTitle = L10n.s("No Purchases Found")
                                restoreAlertMessage = L10n.s("We couldn't find an active PRO purchase for this Apple ID.")
                                showingRestoreAlert = true
                            } else {
                                restoreAlertTitle = L10n.s("Restore Failed")
                                restoreAlertMessage = storeManager.purchaseErrorMessage ?? L10n.s("Please try again later.")
                                showingRestoreAlert = true
                            }
                        }
                    }) {
                        Text(L10n.s("Restore Purchases"))
                            .font(.subheadline.bold())
                            .foregroundStyle(.blue)
                    }

                    Link(destination: LegalLinks.manageSubscriptions) {
                        Text(L10n.s("Manage Subscriptions"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                
                VStack(spacing: 8) {
                    if isSelectedSubscription {
                        Text(L10n.s("Payment will be charged to your Apple ID account. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Manage or cancel in Apple ID Subscriptions."))
                    } else {
                        Text(L10n.s("Payment will be charged to your Apple ID account at confirmation of purchase. This is a one-time Non-Consumable purchase that unlocks PRO permanently for this Apple ID."))
                    }
                    HStack(spacing: 16) {
                        Link(L10n.s("Privacy Policy"), destination: LegalLinks.privacyPolicy)
                        Link(L10n.s("Terms of Use"), destination: LegalLinks.termsOfUse)
                    }
                    .font(.caption.bold())
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            if storeManager.products.isEmpty {
                await storeManager.loadProducts()
            }
            if selectedProduct == nil, let first = storeManager.products.first {
                selectedProductID = first.id
            }
        }
        .alert(restoreAlertTitle, isPresented: $showingRestoreAlert) {
            Button(L10n.s("OK"), role: .cancel) {
                if storeManager.isProUser { dismiss() }
            }
        } message: {
            Text(restoreAlertMessage)
        }
        .alert(L10n.s("Purchase Failed"), isPresented: Binding(
            get: { purchaseAlertMessage != nil },
            set: { if !$0 { purchaseAlertMessage = nil } }
        )) {
            Button(L10n.s("OK"), role: .cancel) { purchaseAlertMessage = nil }
        } message: {
            Text(purchaseAlertMessage ?? "")
        }
    }

    private func productDisplayName(_ product: Product) -> String {
        switch product.id {
        case StoreManager.monthlyProID:
            return L10n.s("Monthly PRO")
        case StoreManager.yearlyProID:
            return L10n.s("Yearly PRO")
        case StoreManager.lifetimeProID:
            return L10n.s("Lifetime PRO")
        default:
            return product.displayName
        }
    }

    private func subscriptionPeriodText(_ product: Product) -> String? {
        guard let period = product.subscription?.subscriptionPeriod else { return nil }
        let value = period.value
        switch period.unit {
        case .day:
            return value == 1 ? L10n.s("1 day") : String(format: L10n.s("%d days"), value)
        case .week:
            return value == 1 ? L10n.s("1 week") : String(format: L10n.s("%d weeks"), value)
        case .month:
            return value == 1 ? L10n.s("1 month") : String(format: L10n.s("%d months"), value)
        case .year:
            return value == 1 ? L10n.s("1 year") : String(format: L10n.s("%d years"), value)
        @unknown default:
            return nil
        }
    }

    private func priceWithPeriod(_ product: Product) -> String {
        if let length = subscriptionPeriodText(product) {
            return String(format: L10n.s("%@ / %@"), product.displayPrice, length)
        }
        return product.displayPrice
    }

    private func productAccessibilityLabel(_ product: Product) -> String {
        let name = productDisplayName(product)
        let price = priceWithPeriod(product)
        if let length = subscriptionPeriodText(product) {
            return "\(name), \(length), \(price)"
        }
        return "\(name), \(price)"
    }
}

private extension Color {
    static let amber = Color(red: 0.95, green: 0.65, blue: 0.15)
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
