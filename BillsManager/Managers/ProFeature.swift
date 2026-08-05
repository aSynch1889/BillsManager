import Foundation

/// Premium capabilities gated behind StoreKit PRO entitlement.
enum ProFeature: String, CaseIterable {
    case unlimitedCategories
    case unlimitedAccounts
    case exportBackup
    case appLock
    case advancedAnalytics

    /// Free-tier caps (system categories do not count toward the category limit).
    static let freeCustomCategoryLimit = 5
    static let freeAccountLimit = 3
}

extension StoreManager {
    func canAccess(_ feature: ProFeature) -> Bool {
        isProUser
    }

    /// Returns `true` when the user may add another custom (non-system) category.
    func canAddCustomCategory(currentCustomCount: Int) -> Bool {
        if canAccess(.unlimitedCategories) { return true }
        return currentCustomCount < ProFeature.freeCustomCategoryLimit
    }

    /// Returns `true` when the user may add another payment account.
    func canAddAccount(currentCount: Int) -> Bool {
        if canAccess(.unlimitedAccounts) { return true }
        return currentCount < ProFeature.freeAccountLimit
    }
}
