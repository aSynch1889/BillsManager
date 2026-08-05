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
    
    // Product IDs
    static let lifetimeProID = "com.billsmanager.pro.lifetime"
    static let monthlyProID = "com.billsmanager.pro.monthly"
    static let yearlyProID = "com.billsmanager.pro.yearly"
    
    private let productIDs = [lifetimeProID, monthlyProID, yearlyProID]
    private var transactionListener: Task<Void, Error>?
    
    var isProUser: Bool {
        !purchasedProductIDs.isEmpty
    }

    /// Known PRO product IDs — only these entitlements unlock premium features.
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
    
    @MainActor
    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            print("Failed to load StoreKit products: \(error)")
        }
    }
    
    @MainActor
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                guard knownProductIDs.contains(transaction.productID) else {
                    await transaction.finish()
                    return false
                }
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
                return true
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseErrorMessage = error.localizedDescription
            return false
        }
    }
    
    @MainActor
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            purchaseErrorMessage = error.localizedDescription
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
