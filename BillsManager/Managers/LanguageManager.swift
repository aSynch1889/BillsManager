import Foundation
import Observation

@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    private static let storageKey = "appLanguage"

    /// Tracked stored property — reassigning this is what triggers SwiftUI updates.
    private(set) var effectiveCode: String

    private var bundleCache: [String: Bundle] = [:]

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? AppLanguage.system.rawValue
        let selected = AppLanguage(rawValue: raw) ?? .system
        effectiveCode = AppLanguage.resolveEffectiveCode(
            selected: selected,
            preferredLocalizations: Bundle.main.preferredLocalizations
        )
    }

    /// The persisted choice, read fresh on each access (used to draw the picker's checkmark).
    var selected: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: raw) ?? .system
    }

    /// Persist the choice and flip the tracked `effectiveCode` → fires re-render.
    func setLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        effectiveCode = AppLanguage.resolveEffectiveCode(
            selected: language,
            preferredLocalizations: Bundle.main.preferredLocalizations
        )
    }

    /// Localized string for `key` in the currently effective language.
    func string(_ key: String, table: String = "Localizable") -> String {
        resolvedBundle(for: effectiveCode).localizedString(forKey: key, value: nil, table: table)
    }

    private func resolvedBundle(for code: String) -> Bundle {
        if let cached = bundleCache[code] { return cached }
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            bundleCache[code] = bundle
            return bundle
        }
        return .main   // fallback: English source / Base
    }
}
