import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case ja
    case ko

    var id: String { rawValue }

    /// Concrete (non-system) language codes the app ships translations for.
    /// Derived from the cases so it can't drift from the enum definition.
    static let supportedCodes: [String] = allCases.filter { $0 != .system }.map(\.rawValue)

    /// Concrete code for this choice; `nil` means "resolve from system".
    var explicitCode: String? { self == .system ? nil : rawValue }

    /// Name shown in the picker, written in the language's own script.
    var nativeName: String {
        switch self {
        case .system: return L10n.s("Follow System")
        case .en:     return "English"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .ja:     return "日本語"
        case .ko:     return "한국어"
        }
    }

    /// Pure resolution — deterministic, no bundle needed, so it is self-checkable.
    /// `preferredLocalizations` is normally `Bundle.main.preferredLocalizations`,
    /// which the OS already orders by system preference and intersects with knownRegions.
    static func resolveEffectiveCode(
        selected: AppLanguage,
        preferredLocalizations: [String]
    ) -> String {
        if let code = selected.explicitCode { return code }
        if let first = preferredLocalizations.first, supportedCodes.contains(first) {
            return first
        }
        return AppLanguage.en.rawValue   // unsupported system language (e.g. French) → English fallback
    }
}
