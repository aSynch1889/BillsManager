import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProductID: String = StoreManager.lifetimeProID
    @State private var restoreAlertTitle: String = ""
    @State private var restoreAlertMessage: String = ""
    @State private var showingRestoreAlert: Bool = false
    @State private var purchaseAlertMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Banner
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
                    
                    Text(L10n.s("One-time purchase. Unlock PRO forever on this Apple ID."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 24)
                
                // Feature Highlights List
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "folder.badge.plus", color: .purple, title: L10n.s("Unlimited Categories & Accounts"), subtitle: L10n.s("Create unlimited custom expense categories"))
                    FeatureRow(icon: "square.and.arrow.up.fill", color: .blue, title: L10n.s("CSV Export & JSON Backup"), subtitle: L10n.s("Export all bill records to CSV or backup database"))
                    FeatureRow(icon: "lock.shield.fill", color: .green, title: L10n.s("Face ID / Touch ID Security"), subtitle: L10n.s("Secure sensitive bill data with biometric lock"))
                    FeatureRow(icon: "chart.pie.fill", color: .orange, title: L10n.s("Advanced Analytics"), subtitle: L10n.s("Detailed category breakdown & trend reports"))
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal)
                
                // Product Selection Cards
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
                        Text(String(format: L10n.s("Expected product: %@"), StoreManager.lifetimeProID))
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
                                        Text(product.displayName)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(product.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(product.displayPrice)
                                        .font(.title3.bold())
                                        .foregroundStyle(.blue)
                                }
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
                
                // Purchase Button
                VStack(spacing: 12) {
                    if let selectedProduct = storeManager.products.first(where: { $0.id == selectedProductID }) ?? storeManager.products.first {
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
                            Text(String(format: L10n.s("Continue with %@"), selectedProduct.displayPrice))
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
                
                // Legal disclosure (lifetime offer + restore of any legacy subscription)
                VStack(spacing: 8) {
                    Text(L10n.s("Payment will be charged to your Apple ID account at confirmation of purchase. This is a one-time Non-Consumable purchase that unlocks PRO permanently for this Apple ID."))
                    Text(L10n.s("If you previously subscribed monthly or yearly, use Restore Purchases or Manage Subscriptions to review or cancel auto-renewal in your Apple ID settings."))
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
