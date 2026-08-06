import Foundation
import StoreKit
import SwiftUI

@Observable
final class StoreManager {
    static let shared = StoreManager()
    
    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isLoadingProducts: Bool = false
    var purchaseErrorMessage: String?
    /// Set when product fetch finishes with an empty list (config/network/ASC mismatch).
    var productsLoadFailed: Bool = false
    var productsLoadErrorMessage: String?
    
    static let lifetimeProID = "com.billsmanager.pro.lifetime"
    static let monthlyProID = "com.billsmanager.pro.monthly"
    static let yearlyProID = "com.billsmanager.pro.yearly"

    /// All PRO products offered on the Paywall (subscriptions + lifetime).
    static let offeredProductIDs = [monthlyProID, yearlyProID, lifetimeProID]
    static let proEntitlementCacheKey = "StoreManagerProEntitlementCache"
    private let productIDs = offeredProductIDs
    private var transactionListener: Task<Void, Error>?
    
    var isProUser: Bool {
        !purchasedProductIDs.isEmpty
    }

    var knownProductIDs: Set<String> {
        Set(productIDs)
    }
    
    init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }

    private static func sortOrder(for productID: String) -> Int {
        switch productID {
        case monthlyProID: return 0
        case yearlyProID: return 1
        case lifetimeProID: return 2
        default: return 99
        }
    }
    
    @MainActor
    func loadProducts() async {
        isLoadingProducts = true
        productsLoadFailed = false
        productsLoadErrorMessage = nil
        defer { isLoadingProducts = false }
        
        do {
            let loaded = try await Product.products(for: Self.offeredProductIDs)
            products = loaded.sorted {
                Self.sortOrder(for: $0.id) < Self.sortOrder(for: $1.id)
            }
            if products.isEmpty {
                productsLoadFailed = true
                productsLoadErrorMessage = L10n.s("No products available. Check your network or try again.")
            }
        } catch {
            print("Failed to load StoreKit products: \(error)")
            products = []
            productsLoadFailed = true
            productsLoadErrorMessage = error.localizedDescription
            purchaseErrorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func purchase(_ product: Product) async -> Bool {
        purchaseErrorMessage = nil
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                guard knownProductIDs.contains(transaction.productID) else {
                    await transaction.finish()
                    purchaseErrorMessage = L10n.s("This product isn't supported by this app version.")
                    return false
                }
                purchasedProductIDs.insert(transaction.productID)
                persistProEntitlementCache()
                await transaction.finish()
                return true
            case .userCancelled:
                return false
            case .pending:
                purchaseErrorMessage = L10n.s("Purchase is pending approval. You'll get PRO after it's approved.")
                return false
            @unknown default:
                purchaseErrorMessage = L10n.s("Purchase didn't complete. Please try again.")
                return false
            }
        } catch {
            purchaseErrorMessage = error.localizedDescription
            return false
        }
    }
    
    @MainActor
    func restorePurchases() async -> Bool {
        purchaseErrorMessage = nil
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            return true
        } catch {
            purchaseErrorMessage = error.localizedDescription
            return false
        }
    }
    
    @MainActor
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                guard knownProductIDs.contains(transaction.productID) else { continue }
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }
        self.purchasedProductIDs = purchased
        persistProEntitlementCache()
        if isProUser {
            CloudSyncManager.shared.clearProExpirationFlag()
        }
        CloudSyncManager.enforceProRequirement(isProUser: isProUser)
    }

    private func persistProEntitlementCache() {
        UserDefaults.standard.set(isProUser, forKey: Self.proEntitlementCacheKey)
    }

    static var cachedProEntitlement: Bool {
        UserDefaults.standard.bool(forKey: proEntitlementCacheKey)
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("Transaction update failed: \(error)")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
