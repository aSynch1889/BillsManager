import Foundation

/// Drop-in replacement for `NSLocalizedString(_:comment:)`.
enum L10n {
    static func s(_ key: String) -> String { LanguageManager.shared.string(key) }
}

#if DEBUG
enum LocalizationSelfCheck {
    static func run() {
        // Explicit choice always wins, regardless of system preference.
        assert(AppLanguage.resolveEffectiveCode(selected: .en,
               preferredLocalizations: ["zh-Hans", "en"]) == "en")
        // System choice honors the first supported preferred localization.
        assert(AppLanguage.resolveEffectiveCode(selected: .system,
               preferredLocalizations: ["ja"]) == "ja")
        assert(AppLanguage.resolveEffectiveCode(selected: .system,
               preferredLocalizations: ["zh-Hans"]) == "zh-Hans")
        // Unsupported system language falls back to English.
        assert(AppLanguage.resolveEffectiveCode(selected: .system,
               preferredLocalizations: ["fr"]) == "en")
        // Empty preference list falls back to English.
        assert(AppLanguage.resolveEffectiveCode(selected: .system,
               preferredLocalizations: []) == "en")
        print("[L10n] resolution self-check passed")

        // Every non-English supported language compiles to an .lproj in the bundle.
        for code in AppLanguage.supportedCodes where code != "en" {
            assert(Bundle.main.path(forResource: code, ofType: "lproj") != nil,
                   "Missing .lproj for \(code) — check knownRegions and translations")
        }
        print("[L10n] lproj coverage self-check passed")
    }
}
#endif
