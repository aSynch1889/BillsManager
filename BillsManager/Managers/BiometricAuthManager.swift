import Foundation
import LocalAuthentication
import SwiftUI

@Observable
final class BiometricAuthManager {
    static let shared = BiometricAuthManager()
    
    var isAppLockEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "isAppLockEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "isAppLockEnabled") }
    }
    
    var isUnlocked: Bool = false
    var authError: String?
    
    var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }
    
    var biometricName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return L10n.s("Passcode")
        }
    }
    
    init() {
        if !isAppLockEnabled {
            isUnlocked = true
        }
    }
    
    @MainActor
    func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        let reason = L10n.s("Unlock Bills Manager to view financial data.")
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                if success {
                    isUnlocked = true
                    authError = nil
                    return true
                }
            } catch {
                authError = error.localizedDescription
                isUnlocked = false
                return false
            }
        } else {
            authError = error?.localizedDescription ?? L10n.s("Biometrics or passcode unavailable.")
        }
        return false
    }
    
    func lockApp() {
        if isAppLockEnabled {
            isUnlocked = false
        }
    }
}
