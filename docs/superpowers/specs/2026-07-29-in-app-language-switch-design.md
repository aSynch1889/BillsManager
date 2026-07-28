# In-App Language Switching — Design Spec

- **Date:** 2026-07-29
- **Project:** BillsManager (SwiftUI / SwiftData / iOS 17+)
- **Status:** Approved (awaiting implementation plan)
- **Approach chosen:** B — custom lookup helper + replace all `NSLocalizedString` call sites (pure Swift, no runtime hack)

## 1. Background & Problem

The app ships a String Catalog `BillsManager/Resources/Localizable.xcstrings` (source language `en`, 148 keys). Current state:

- **Incomplete translations:** only 24/148 keys are translated to `zh-Hans`; the remaining ~124 fall back to English. Under a Chinese system language the UI is a broken mix of Chinese and English.
- **Only 2 locales configured:** `project.pbxproj` `knownRegions` = `en, Base, zh-Hans`. No Traditional Chinese / Japanese / Korean.
- **No in-app control:** localization purely follows the iOS system preferred language. There is no `LocaleManager`, no Bundle override, no `.environment(\.locale)` injection. Switching language requires changing the iOS system language and (effectively) relaunching.

String access in code: 141 distinct `NSLocalizedString(_:comment:)` keys, plus `localizedName`/`localizedTitle` computed properties that wrap `NSLocalizedString`, plus ~3 bare `Text("literal")` / `Label` literals resolved via `LocalizedStringKey`.

## 2. Goals

1. Add a Settings entry → language list screen.
2. Support **6 choices:** Follow System, English, 简体中文, 繁體中文, 日本語, 한국어 (`system, en, zh-Hans, zh-Hant, ja, ko`).
3. Tapping a language **immediately updates the entire app** — no restart, no relaunch.
4. Default is **Follow System**; persists across launches.
5. Translate **all 148 keys** into Simplified Chinese (complete), Traditional Chinese, Japanese, Korean so each language is fully shown (no English bleed-through).
6. Dates / numbers / **currency** formatting follow the selected language.

## 3. Non-Goals

- Re-translating already-stored **data** (seed bill names like "Electricity Bill" stay as entered; only UI text switches).
- Re-wording already-scheduled **local notifications** when the language changes (a future enhancement; see §9).
- Localization of StoreKit product display names beyond what StoreKit provides.
- Adding languages beyond the 5 above.

## 4. Architecture & Components

### 4.1 `AppLanguage` enum

`BillsManager/Managers/AppLanguage.swift`

```swift
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case ja
    case ko

    var id: String { rawValue }

    /// Name shown in the picker, in the language's own script (does not require translation).
    var nativeName: String {
        switch self {
        case .system: return L10n.s("Follow System")   // only this one is localized
        case .en:     return "English"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .ja:     return "日本語"
        case .ko:     return "한국어"
        }
    }
}
```

### 4.2 `LanguageManager` (`@Observable`)

`BillsManager/Managers/LanguageManager.swift`

- `static let shared` singleton; also injected into SwiftUI environment (mirrors the existing `StoreManager` / `BiometricAuthManager` pattern: `.environment(languageManager)` + `@Environment(LanguageManager.self)`).
- `private(set) var effectiveCode: String` — a **tracked stored property** (this is what SwiftUI observes; mutating it is what triggers the re-render). Holds the concrete BCP-47 code in effect. Initialized at init from the persisted preference.
- `var selected: AppLanguage` — **computed** (read from `UserDefaults` key `"appLanguage"`, default `.system`); used only to render the ✅ in the picker. Computed properties are not tracked, which is intentional — display reads it on rebuild.
- `func setLanguage(_ lang: AppLanguage)` — writes `UserDefaults["appLanguage"]` **and** reassigns `effectiveCode` to the resolved code. Reassigning the tracked `effectiveCode` is what fires the UI update.
- `effectiveCode` resolution (used by both init and `setLanguage`):
  - If `lang == .system`: `Bundle.main.preferredLocalizations` intersected with the supported set; if none match, `"en"`.
  - Otherwise: `lang.rawValue`.
- `func string(_ key: String, table: String = "Localizable") -> String`:
  - Look up (and cache) the `Bundle` for `effectiveCode` via `Bundle(path: Bundle.main.path(forResource: code, ofType: "lproj")!)`; on missing path fall back to `Bundle.main`.
  - Return `bundle.localizedString(forKey: key, value: nil, table: table)`. (When absent, `localizedString` returns the key itself = English source.)

> Note: Because the String Catalog compiles to per-language `.lproj/Localizable.strings`, a language only becomes resolvable at runtime once it has translations **and** is listed in `knownRegions`. Both are in scope (§7).

### 4.3 `L10n` lookup façade

`BillsManager/Managers/L10n.swift`

```swift
enum L10n {
    /// Drop-in replacement for NSLocalizedString(_:comment:).
    static func s(_ key: String) -> String { LanguageManager.shared.string(key) }
}
```

Every former `NSLocalizedString("X", comment: …)` becomes `L10n.s("X")`.

## 5. Call-Site Migration (mechanical)

1. `NSLocalizedString("X", comment: …)` → `L10n.s("X")` across all `.swift` files (~141 sites).
2. `String(format: NSLocalizedString("X", comment: …), args)` → `String(format: L10n.s("X"), args)`.
3. Bare `Text("literal")` / `Label("literal", …)` relying on `LocalizedStringKey` auto-lookup (≈3 sites) → `Text(L10n.s("literal"))` so they route through `L10n` instead of `Bundle.main` system resolution.
4. `localizedName` / `localizedTitle` computed properties: replace their internal `NSLocalizedString` calls with `L10n.s` (they already re-evaluate on rebuild).

Replacement is automated (scripted find/replace), then reviewed manually for the `String(format:)` and literal cases.

## 6. Instant Switch & Re-render

In `BillsManager/App/BillsManagerApp.swift`:

- Hold `@State private var languageManager = LanguageManager.shared` and inject via `.environment(languageManager)` (same pattern as the existing `storeManager`/`authManager`).
- Apply the rebuild/locale modifiers via a **dedicated wrapper view `RootContentView`** (`BillsManager/Views/Main/RootContentView.swift`) rather than directly on `App.body`. `RootContentView` declares `@Environment(LanguageManager.self) var languageManager` and wraps the existing gated `ZStack` (splash → onboarding → main+lock) with:
  - `.id(languageManager.effectiveCode)` — when the tracked `effectiveCode` changes, SwiftUI observes the read inside the View body, discards and rebuilds the whole subtree, so every `Text` / `L10n.s` re-resolves against the new language. (Using a View body — not the `App` body — guarantees reliable `@Observable` tracking.)
  - `.environment(\.locale, Locale(identifier: languageManager.effectiveCode))` — dates, numbers, currency formatting follow.

State safety: `ModelContainer`, `authManager`, `storeManager` live at the `App` level and survive the `.id` rebuild. The `NavigationStack` returns to root on switch (standard behavior for a language change). `seedInitialDataIfNeeded` runs once in `init()` and does not re-run on rebuild.

## 7. Settings Entry & Language Picker UI

### 7.1 Settings row

In `SettingsView`, add a `NavigationLink(L10n.s("Language")) { LanguageSelectionView() }`. Placement: a **new headerless `Section`** inserted immediately **before the "About" section**, containing only this single Language row. The keys `"Language"` and `"Follow System"` are added to the catalog in all 5 languages.

### 7.2 `LanguageSelectionView`

`BillsManager/Views/Settings/LanguageSelectionView.swift`

- `List` over `AppLanguage.allCases` (6 rows).
- Each row: `nativeName` (self-script) + a ✅ on the currently selected row (`languageManager.selected`).
- On tap: `languageManager.setLanguage(lang)` → reassigns the tracked `effectiveCode` → `RootContentView` `.id` changes → app rebuilds in the new language immediately. No navigation step, no restart.
- Navigation title: `L10n.s("Language")`.

## 8. Translations & Project Config

- **Translations:** all 148 keys translated into `zh-Hans` (complete 24→148), `zh-Hant`, `ja`, `ko`, written back into `Localizable.xcstrings` (edited as JSON; state `"translated"`). New UI keys added by this feature (`"Language"`, `"Follow System"`) are included.
- **`project.pbxproj`:** add `"zh-Hant"`, `"ja"`, `"ko"` to `knownRegions` so each compiles to a `.lproj` inside the app bundle.
- **Format strings:** preserve `%@` / `%d` placeholders in translations; use positional `%1$@` where a language needs different argument order.

## 9. Known Boundaries (non-defects)

- **Seed data names** are data, not UI — switching language does not rewrite stored bill names. New installs seed using the current language.
- **Already-scheduled local notifications** keep their original-language text until rescheduled. Out of scope for this iteration; can add "reschedule on language change" later if desired.

## 10. Testing / Verification

- Build succeeds with no warnings about missing localizations.
- For each of the 5 languages: open Settings → tap language → verify Settings / Dashboard / Bills / Calendar / Analytics screens switch **immediately** without relaunch.
- Date / currency formatting updates with the language (`.environment(\.locale)`).
- `Follow System`: with iOS system language set to Japanese/Korean/Chinese, the app matches on launch; with an unsupported language (e.g. French), it falls back to English.
- Persistence: kill & relaunch → chosen language retained.
- No English bleed-through in any of the 5 languages (all 148 keys covered).

## 11. Files Touched (summary)

- **New:** `Managers/AppLanguage.swift`, `Managers/LanguageManager.swift`, `Managers/L10n.swift`, `Views/Main/RootContentView.swift`, `Views/Settings/LanguageSelectionView.swift`
- **Modified:** `App/BillsManagerApp.swift` (hold + inject `languageManager`; render `RootContentView`), `Views/Settings/SettingsView.swift` (language row), all view/model files carrying `NSLocalizedString` (call-site migration), `Resources/Localizable.xcstrings` (translations + new keys), `BillsManager.xcodeproj/project.pbxproj` (`knownRegions`), and the new `.swift` files added to the build phase / file references.
