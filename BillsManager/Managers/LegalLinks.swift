import Foundation

enum LegalLinks {
    static let privacyPolicyEN = URL(string: "https://asynch1889.github.io/BillsManager-legal/privacy/en.html")!
    static let privacyPolicyZH = URL(string: "https://asynch1889.github.io/BillsManager-legal/privacy/zh.html")!
    static let support = URL(string: "https://asynch1889.github.io/BillsManager-legal/support/")!
    /// Apple Standard EULA (acceptable when app uses standard terms).
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let manageSubscriptions = URL(string: "https://apps.apple.com/account/subscriptions")!

    static var privacyPolicy: URL {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return code.hasPrefix("zh") ? privacyPolicyZH : privacyPolicyEN
    }
}
