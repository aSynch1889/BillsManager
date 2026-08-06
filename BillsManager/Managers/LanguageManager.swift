import Foundation
import Observation
import os

@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    private static let storageKey = "appLanguage"

    /// Tracked stored property — reassigning this is what triggers SwiftUI updates.
    private(set) var effectiveCode: String

    /// Thread-safe cache of resolved bundles; guarded so a future background
    /// caller can't trigger concurrent dictionary mutation. `effectiveCode`
    /// stays a plain tracked stored property (mutated only by `setLanguage`).
    private let bundleCache = OSAllocatedUnfairLock(initialState: [String: Bundle]())

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
        bundleCache.withLock { $0.removeAll() }
        effectiveCode = AppLanguage.resolveEffectiveCode(
            selected: language,
            preferredLocalizations: Bundle.main.preferredLocalizations
        )
    }

    /// Localized string for `key` in the currently effective language.
    func string(_ key: String, table: String = "Localizable") -> String {
        let bundle = resolvedBundle(for: effectiveCode)
        let value = bundle.localizedString(forKey: key, value: nil, table: table)
        // If the key is missing from the table, Foundation returns the key itself.
        // Fall back to English catalog / main bundle so UI never shows a raw missing key
        // when a translation file lags behind.
        if value == key, effectiveCode != "en" {
            let english = resolvedBundle(for: "en").localizedString(forKey: key, value: nil, table: table)
            if english != key { return english }
            return Bundle.main.localizedString(forKey: key, value: key, table: table)
        }
        return value
    }

    private func resolvedBundle(for code: String) -> Bundle {
        bundleCache.withLock { cache -> Bundle in
            if let cached = cache[code] { return cached }
            if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                cache[code] = bundle
                return bundle
            }
            return .main   // fallback: English source / Base
        }
    }
}
