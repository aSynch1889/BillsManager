import Foundation
import LocalAuthentication
import SwiftUI

@Observable
final class BiometricAuthManager {
    static let shared = BiometricAuthManager()

    private static let enabledKey = "isAppLockEnabled"

    var isAppLockEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    var isUnlocked: Bool = false
    var authError: String?
    /// Shown in App Switcher / inactive to hide financial content.
    var showPrivacyBlur: Bool = false

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

    /// Enable or disable App Lock only after successful authentication; rolls back on failure.
    @MainActor
    @discardableResult
    func setAppLockEnabled(_ enabled: Bool) async -> Bool {
        if enabled == isAppLockEnabled {
            if enabled { isUnlocked = true }
            return true
        }

        let reasonContext = LAContext()
        var error: NSError?
        let reason = enabled
            ? L10n.s("Authenticate to enable App Lock.")
            : L10n.s("Authenticate to disable App Lock.")

        guard reasonContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            authError = error?.localizedDescription ?? L10n.s("Biometrics or passcode unavailable.")
            return false
        }

        do {
            let success = try await reasonContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            guard success else {
                isUnlocked = false
                return false
            }
            isAppLockEnabled = enabled
            isUnlocked = true
            authError = nil
            return true
        } catch {
            authError = error.localizedDescription
            // Keep previous enabled state; do not leave lock "on" while unlocked=false after a failed enable.
            if !isAppLockEnabled {
                isUnlocked = true
            }
            return false
        }
    }

    func lockApp() {
        if isAppLockEnabled {
            isUnlocked = false
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .inactive:
            // Hide content in App Switcher even when lock is off (privacy for financial data).
            showPrivacyBlur = true
        case .active:
            showPrivacyBlur = false
        case .background:
            showPrivacyBlur = true
            lockApp()
        @unknown default:
            break
        }
    }
}
