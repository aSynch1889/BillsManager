import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProductID: String = StoreManager.lifetimeProID
    
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
                    
                    Text(NSLocalizedString("Bills Manager PRO", comment: ""))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    
                    Text(NSLocalizedString("Unlock full financial tracking potential & ad-free experience", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 24)
                
                // Feature Highlights List
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "star.circle.fill", color: .amber, title: "Ad-Free Experience", subtitle: "Zero banner or popup advertisements")
                    FeatureRow(icon: "folder.badge.plus", color: .purple, title: "Unlimited Categories & Accounts", subtitle: "Create unlimited custom expense categories")
                    FeatureRow(icon: "square.and.arrow.up.fill", color: .blue, title: "CSV Export & JSON Backup", subtitle: "Export all bill records to CSV or backup database")
                    FeatureRow(icon: "lock.shield.fill", color: .green, title: "Face ID / Touch ID Security", subtitle: "Secure sensitive bill data with biometric lock")
                    FeatureRow(icon: "chart.pie.fill", color: .orange, title: "Advanced Analytics", subtitle: "Detailed category breakdown & trend reports")
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal)
                
                // Product Selection Cards
                if storeManager.products.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(NSLocalizedString("Loading Products...", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
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
                                }
                            }
                        }) {
                            Text(String(format: NSLocalizedString("Continue with %@", comment: ""), selectedProduct.displayPrice))
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
                            await storeManager.restorePurchases()
                        }
                    }) {
                        Text(NSLocalizedString("Restore Purchases", comment: ""))
                            .font(.subheadline.bold())
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal)
                
                // Terms & Privacy Note
                Text(NSLocalizedString("Payment will be charged to your Apple ID account at confirmation of purchase.", comment: ""))
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
