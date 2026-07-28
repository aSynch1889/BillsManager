# In-App Language Switching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Settings → Language screen that switches the app between English / 简体中文 / 繁體中文 / 日本語 / 한국어 (+ Follow System) instantly, with no restart, plus full translations for all UI strings.

**Architecture:** Approach B — a `LanguageManager` (`@Observable`) resolves an `effectiveCode` and looks strings up from the matching `.lproj` bundle via a `L10n.s(_:)` façade that replaces every `NSLocalizedString` call site. A `RootContentView` wrapper applies `.id(effectiveCode)` (forces a full view-tree rebuild → every `Text` re-resolves) and `.environment(\.locale, …)` (dates/numbers/currency). All 148 catalog keys are translated into zh-Hans (completed), zh-Hant, ja, ko.

**Tech Stack:** SwiftUI, SwiftData, `@Observable` (Observation), String Catalog (`.xcstrings`), iOS 17+, Xcode classic project (`project.pbxproj`, hand-edited — no synchronized groups, no `xcodeproj` gem).

## Global Constraints

- **iOS deployment target:** 17.0 (`IPHONEOS_DEPLOYMENT_TARGET = 17.0`). Use `@Observable` (iOS 17+). Do NOT use `@Entry` (iOS 18+).
- **Swift version:** 5.0 (`SWIFT_VERSION = 5.0`).
- **No test target exists** in this project (single `PBXNativeTarget` = the app). Testing strategy is: (a) a `#if DEBUG` runtime self-check for the pure resolution logic, (b) `xcodebuild` compile, (c) manual smoke run in the simulator. Do NOT add an XCTest target (hand-editing risk is high and out of scope).
- **Build command:** `xcodebuild -project BillsManager.xcodeproj -scheme BillsManager -destination 'generic/platform=iOS Simulator' build` (scheme = target = `BillsManager`).
- **pbxproj ID scheme:** PBXBuildFile IDs start `0101…`, PBXFileReference IDs start `0102…`, PBXGroup IDs start `0104…`. New files use the unused range `0101003x` (build) / `0102003x` (ref). Preserve the `/* Name in Sources */` comment style and tab indentation exactly.
- **Languages:** `system, en, zh-Hans, zh-Hant, ja, ko`. Supported concrete codes: `["en", "zh-Hans", "zh-Hant", "ja", "ko"]`.
- **Translation rules:** preserve `%@` / `%d` / `%.2f` placeholders verbatim; keep the brand name **"Bills Manager"** untranslated (routed via `L10n.s` with no catalog entry → returns the key). Use positional `%1$@` only if a translation needs different argument order (none currently do).
- **Pre-existing limitation (do NOT fix here):** `String(format: "$%.2f", …)` (Dashboard "Total overdue") is C-printf, not locale-aware; `.environment(\.locale)` will not change its decimal separator. Out of scope — note only.
- **Source-language file:** `BillsManager/Resources/Localizable.xcstrings` (JSON; `sourceLanguage = "en"`).

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `BillsManager/Managers/AppLanguage.swift` | New | Enum of language choices; pure `resolveEffectiveCode` static. |
| `BillsManager/Managers/LanguageManager.swift` | New | `@Observable`; tracks `effectiveCode`, persists choice, looks up strings from per-language bundles. |
| `BillsManager/Managers/L10n.swift` | New | `L10n.s(_:)` façade + `#if DEBUG` self-check. |
| `BillsManager/Views/Main/RootContentView.swift` | New | Generic wrapper applying `.id(effectiveCode)` + `.environment(\.locale)`. |
| `BillsManager/Views/Settings/LanguageSelectionView.swift` | New | The 6-row language picker. |
| `BillsManager/App/BillsManagerApp.swift` | Modify | Hold + inject `LanguageManager`; render `RootContentView`. |
| `BillsManager/Views/Settings/SettingsView.swift` | Modify | Add Language section/row. |
| All `*.swift` with `NSLocalizedString` (28 files) | Modify | Migrate to `L10n.s`. |
| `BillsManager/Resources/Localizable.xcstrings` | Modify | Add 7 keys; translate all into zh-Hans/zh-Hant/ja/ko. |
| `BillsManager.xcodeproj/project.pbxproj` | Modify | Register 5 new Swift files; add `zh-Hant/ja/ko` to `knownRegions`. |

---

## Task 1: Core localization infrastructure

**Files:**
- Create: `BillsManager/Managers/AppLanguage.swift`
- Create: `BillsManager/Managers/LanguageManager.swift`
- Create: `BillsManager/Managers/L10n.swift`
- Modify: `BillsManager.xcodeproj/project.pbxproj` (register the 3 files)

**Interfaces:**
- Produces: `AppLanguage` enum (+ `static func resolveEffectiveCode(selected:preferredLocalizations:) -> String`, `static let supportedCodes`, `var explicitCode: String?`, `var nativeName: String`); `LanguageManager` (`static let shared`, `var effectiveCode: String`, `var selected: AppLanguage`, `func setLanguage(_:)`, `func string(_:table:) -> String`); `L10n.s(_:)`.

- [ ] **Step 1: Write `AppLanguage.swift`**

```swift
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
    static let supportedCodes: [String] = ["en", "zh-Hans", "zh-Hant", "ja", "ko"]

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
        return "en"   // unsupported system language (e.g. French) → English fallback
    }
}
```

- [ ] **Step 2: Write `LanguageManager.swift`**

```swift
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
```

- [ ] **Step 3: Write `L10n.swift`** (resolution self-check only for now; lproj/coverage checks are added in Task 5 once translations exist)

```swift
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
    }
}
#endif
```

- [ ] **Step 4: Register the 3 files in `project.pbxproj`**

Three edits, matching the existing tab-indented comment style. IDs `01020030–32` (refs) and `01010030–32` (build files) are unused.

(a) Add 3 lines to the **PBXBuildFile** section, immediately before `/* End PBXBuildFile section */`:

```
		01010030 /* AppLanguage.swift in Sources */ = {isa = PBXBuildFile; fileRef = 01020030 /* AppLanguage.swift */; };
		01010031 /* LanguageManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = 01020031 /* LanguageManager.swift */; };
		01010032 /* L10n.swift in Sources */ = {isa = PBXBuildFile; fileRef = 01020032 /* L10n.swift */; };
```

(b) Add 3 lines to the **PBXFileReference** section, immediately before `/* End PBXFileReference section */`:

```
		01020030 /* AppLanguage.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppLanguage.swift; sourceTree = "<group>"; };
		01020031 /* LanguageManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LanguageManager.swift; sourceTree = "<group>"; };
		01020032 /* L10n.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = L10n.swift; sourceTree = "<group>"; };
```

(c) Add the 3 refs to the **Managers group** (`01040005`), as the first children:

```
		01040005 /* Managers */ = {
			isa = PBXGroup;
			children = (
				01020030 /* AppLanguage.swift */,
				01020031 /* LanguageManager.swift */,
				01020032 /* L10n.swift */,
				01020007 /* StoreManager.swift */,
				01020008 /* NotificationManager.swift */,
				01020009 /* BiometricAuthManager.swift */,
				0102000A /* ExportManager.swift */,
			);
			path = Managers;
			sourceTree = "<group>";
		};
```

(d) Add 3 lines to the **PBXSourcesBuildPhase** (`01070001`) `files = ( ... )`, e.g. right after the `01010001 /* BillsManagerApp.swift in Sources */` line:

```
				01010030 /* AppLanguage.swift in Sources */,
				01010031 /* LanguageManager.swift in Sources */,
				01010032 /* L10n.swift in Sources */,
```

- [ ] **Step 5: Build to verify it compiles**

Run: `xcodebuild -project BillsManager.xcodeproj -scheme BillsManager -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`. (The new symbols are unused so far — that is fine.)

- [ ] **Step 6: Commit**

```bash
git add BillsManager/Managers/AppLanguage.swift BillsManager/Managers/LanguageManager.swift BillsManager/Managers/L10n.swift BillsManager.xcodeproj/project.pbxproj
git commit -m "feat(l10n): add AppLanguage, LanguageManager, L10n lookup façade"
```

---

## Task 2: Wire LanguageManager into the app

**Files:**
- Create: `BillsManager/Views/Main/RootContentView.swift`
- Modify: `BillsManager/App/BillsManagerApp.swift`
- Modify: `BillsManager.xcodeproj/project.pbxproj` (register `RootContentView.swift`)

**Interfaces:**
- Consumes: `LanguageManager` (from Task 1).
- Produces: `RootContentView<Content>` that forces a rebuild on language change.

- [ ] **Step 1: Write `RootContentView.swift`**

```swift
import SwiftUI

/// Wraps app content so a language change rebuilds the whole subtree and
/// updates Locale for date/number/currency formatting.
struct RootContentView<Content: View>: View {
    @Environment(LanguageManager.self) private var languageManager
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .id(languageManager.effectiveCode)
            .environment(\.locale, Locale(identifier: languageManager.effectiveCode))
    }
}
```

- [ ] **Step 2: Register `RootContentView.swift` in `project.pbxproj`**

IDs `01020033` (ref) / `01010033` (build). Group: **Views/Main** (`01040008`).

(a) PBXBuildFile (before `/* End PBXBuildFile section */`):
```
		01010033 /* RootContentView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 01020033 /* RootContentView.swift */; };
```
(b) PBXFileReference (before `/* End PBXFileReference section */`):
```
		01020033 /* RootContentView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RootContentView.swift; sourceTree = "<group>"; };
```
(c) Views/Main group (`01040008`) — add as first child:
```
		01040008 /* Main */ = {
			isa = PBXGroup;
			children = (
				01020033 /* RootContentView.swift */,
				0102000B /* MainTabView.swift */,
				0102000C /* iPadSidebarView.swift */,
				01020022 /* SplashView.swift */,
			);
			path = Main;
			sourceTree = "<group>";
		};
```
(d) PBXSourcesBuildPhase (`01070001`) — add to `files`:
```
				01010033 /* RootContentView.swift in Sources */,
```

- [ ] **Step 3: Modify `BillsManagerApp.swift`**

(a) Add the manager state property after the other `@State` managers (around line 7):
```swift
    @State private var languageManager = LanguageManager.shared
```

(b) Replace the entire `WindowGroup { … }` body in `var body: some Scene` with the version below — the existing gated `ZStack` content moves unchanged into the `RootContentView` trailing closure, and the environment + self-check are attached:

```swift
        WindowGroup {
            RootContentView {
                ZStack {
                    if showingSplash {
                        SplashView {
                            showingSplash = false
                        }
                        .transition(.opacity)
                    } else if !hasCompletedOnboarding {
                        OnboardingView()
                            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading)))
                    } else {
                        ZStack {
                            MainTabView()
                                .environment(authManager)
                                .environment(storeManager)

                            if authManager.isAppLockEnabled && !authManager.isUnlocked {
                                PasscodeLockView()
                                    .environment(authManager)
                                    .transition(.opacity)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.default, value: showingSplash)
                .animation(.default, value: hasCompletedOnboarding)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .background {
                        authManager.lockApp()
                    }
                }
            }
            .environment(languageManager)
            #if DEBUG
            .onAppear { LocalizationSelfCheck.run() }
            #endif
        }
        .modelContainer(container)
```

- [ ] **Step 4: Build + run the self-check**

Run: `xcodebuild -project BillsManager.xcodeproj -scheme BillsManager -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.
Then run in a simulator (or via Xcode) and watch the console for `[L10n] resolution self-check passed` on launch (fires from `RootContentView.onAppear`).

- [ ] **Step 5: Commit**

```bash
git add BillsManager/Views/Main/RootContentView.swift BillsManager/App/BillsManagerApp.swift BillsManager.xcodeproj/project.pbxproj
git commit -m "feat(l10n): wire LanguageManager via RootContentView (id + locale)"
```

---

## Task 3: Migrate all `NSLocalizedString` call sites to `L10n.s`

**Files:**
- Modify: every `*.swift` under `BillsManager/` that contains `NSLocalizedString(` (28 files) and the 8 bare-literal sites listed below.

**Interfaces:**
- Consumes: `L10n.s(_:)` (Task 1).

- [ ] **Step 1: Bulk-replace `NSLocalizedString("KEY", comment: …)` → `L10n.s("KEY")`**

Run from the repo root (BSD `sed` on macOS; `-i ''` for in-place with no backup suffix):
```bash
cd BillsManager
find . -name "*.swift" -print0 | xargs -0 sed -i '' -E 's/NSLocalizedString\(("[^"]*"), comment:[^)]*\)/L10n.s(\1)/g'
```
This also rewrites the inner `NSLocalizedString(...)` of all 10 `String(format: NSLocalizedString(...), …)` sites into `String(format: L10n.s("…"), …)`.

Verify none remain: `grep -rn "NSLocalizedString(" --include="*.swift" .` → expected: **no output**.

- [ ] **Step 2: Convert the 8 bare `Text`/`Label` literals (they use `LocalizedStringKey` auto-lookup, which bypasses `L10n`)**

Apply each exact replacement:

`Views/CategoriesAccounts/CategoryManagerView.swift:45`
```
Label("Delete", systemImage: "trash")   →   Label(L10n.s("Delete"), systemImage: "trash")
```
`Views/CategoriesAccounts/AccountManagerView.swift:51`
```
Label("Delete", systemImage: "trash")   →   Label(L10n.s("Delete"), systemImage: "trash")
```
`Views/Bills/BillListView.swift:144`
```
Label("Delete", systemImage: "trash")   →   Label(L10n.s("Delete"), systemImage: "trash")
```
`Views/Bills/BillListView.swift:150`
```
Label("Edit", systemImage: "pencil")   →   Label(L10n.s("Edit"), systemImage: "pencil")
```
`Views/Main/iPadSidebarView.swift:25`
```
Label("Add Bill", systemImage: "plus")   →   Label(L10n.s("Add Bill"), systemImage: "plus")
```
`Views/Main/SplashView.swift:30`
```
Text("Bills Manager")   →   Text(L10n.s("Bills Manager"))
```
`Views/Bills/BillDetailView.swift:171`
```
Label("Edit Bill", systemImage: "pencil")   →   Label(L10n.s("Edit Bill"), systemImage: "pencil")
```
`Views/Bills/BillDetailView.swift:174`
```
Label("Delete Bill", systemImage: "trash")   →   Label(L10n.s("Delete Bill"), systemImage: "trash")
```

(The `localizedName`/`localizedTitle` computed properties in `BillFrequency.swift`, `MainTabView.swift`, `BillListView.swift`, `AnalyticsView.swift` were already rewritten by Step 1 — they only contained `NSLocalizedString` calls internally.)

- [ ] **Step 3: Build to verify everything still compiles**

Run: `xcodebuild -project BillsManager.xcodeproj -scheme BillsManager -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`. UI still renders in English (no translations wired yet beyond the existing zh-Hans); behavior unchanged.

- [ ] **Step 4: Commit**

```bash
git add BillsManager
git commit -m "refactor(l10n): route all strings through L10n.s (NSLocalizedString + literals)"
```

---

## Task 4: Settings language entry + picker UI

**Files:**
- Create: `BillsManager/Views/Settings/LanguageSelectionView.swift`
- Modify: `BillsManager/Views/Settings/SettingsView.swift`
- Modify: `BillsManager.xcodeproj/project.pbxproj` (register `LanguageSelectionView.swift`)

**Interfaces:**
- Consumes: `LanguageManager` (Task 1), `L10n.s` (Task 1).
- Produces: `LanguageSelectionView`.

- [ ] **Step 1: Write `LanguageSelectionView.swift`**

```swift
import SwiftUI

struct LanguageSelectionView: View {
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        List {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    languageManager.setLanguage(language)
                } label: {
                    HStack {
                        Text(language.nativeName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if languageManager.selected == language {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(L10n.s("Language"))
    }
}
```

- [ ] **Step 2: Register `LanguageSelectionView.swift` in `project.pbxproj`**

IDs `01020034` (ref) / `01010034` (build). Group: **Views/Settings** (`0104000E`).

(a) PBXBuildFile (before `/* End PBXBuildFile section */`):
```
		01010034 /* LanguageSelectionView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 01020034 /* LanguageSelectionView.swift */; };
```
(b) PBXFileReference (before `/* End PBXFileReference section */`):
```
		01020034 /* LanguageSelectionView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LanguageSelectionView.swift; sourceTree = "<group>"; };
```
(c) Views/Settings group (`0104000E`) — add as first child:
```
		0104000E /* Settings */ = {
			isa = PBXGroup;
			children = (
				01020034 /* LanguageSelectionView.swift */,
				01020019 /* PaywallView.swift */,
				0102001A /* PasscodeLockView.swift */,
				0102001B /* SettingsView.swift */,
				01020021 /* OnboardingView.swift */,
			);
			path = Settings;
			sourceTree = "<group>";
		};
```
(d) PBXSourcesBuildPhase (`01070001`) — add to `files`:
```
				01010034 /* LanguageSelectionView.swift in Sources */,
```

- [ ] **Step 3: Add the Language row to `SettingsView.swift`**

Insert a **new headerless `Section`** immediately **before** the existing `// App Info Section` block (before the line `Section(header: Text(L10n.s("About"))) {`). The row text uses `L10n.s("Language")`:

```swift
            // Language Section
            Section {
                NavigationLink {
                    LanguageSelectionView()
                } label: {
                    Label(L10n.s("Language"), systemImage: "globe")
                }
            }
```

- [ ] **Step 4: Build + run, smoke-test the switch**

Run: `xcodebuild -project BillsManager.xcodeproj -scheme BillsManager -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

Run in the simulator → Settings → Language. Tap **简体中文**: the app must rebuild into Chinese instantly (uses the existing zh-Hans translations). Tap **English / 繁體中文 / 日本語 / 한국어**: the app rebuilds but strings fall back to English for the not-yet-translated languages (fixed in Task 5). Tap **Follow System**: returns to the system language. The whole tree updates without relaunch; the checkmark follows the selection.

- [ ] **Step 5: Commit**

```bash
git add BillsManager/Views/Settings/LanguageSelectionView.swift BillsManager/Views/Settings/SettingsView.swift BillsManager.xcodeproj/project.pbxproj
git commit -m "feat(l10n): add Settings → Language picker (instant switch)"
```

---

## Task 5: Translations + `knownRegions`

**Files:**
- Modify: `BillsManager/Resources/Localizable.xcstrings`
- Modify: `BillsManager.xcodeproj/project.pbxproj` (`knownRegions`)
- Modify: `BillsManager/Managers/L10n.swift` (extend self-check)

**Goal:** every key in the catalog has `translated` values in `zh-Hans` (complete the existing 24 → all), `zh-Hant`, `ja`, `ko`; add the 7 new keys; make the OS build `.lproj` bundles for the new languages.

- [ ] **Step 1: Add `zh-Hant`, `ja`, `ko` to `knownRegions`**

In `project.pbxproj`, replace:
```
			knownRegions = (
				en,
				Base,
				"zh-Hans",
			);
```
with:
```
			knownRegions = (
				en,
				Base,
				"zh-Hans",
				"zh-Hant",
				ja,
				ko,
			);
```

- [ ] **Step 2: Author all translations in `Localizable.xcstrings`**

`Localizable.xcstrings` is JSON. Each key's entry looks like:
```json
"Settings": {
  "localizations": {
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "设置" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "設定" } },
    "ja":      { "stringUnit": { "state": "translated", "value": "設定" } },
    "ko":      { "stringUnit": { "state": "translated", "value": "설정" } }
  }
}
```

Rules (apply to **every** key):
1. Provide `zh-Hans`, `zh-Hant`, `ja`, `ko` with `"state": "translated"`.
2. Preserve `%@`, `%d`, `%.2f` placeholders verbatim in the same order.
3. For `"%@ is due today (%@)!"` / `"%@ (%@) is due in %d days."` / `"Bills Due on %@"` / `"Continue with %@"` / `"Unlock with %@"` / `"Lock with %@"` / `"Overdue Bills (%d)"` / `"Total overdue: $%.2f"` / `"%d days before"` / `"Ref: %@"` — keep all placeholders.
4. `"Bills Manager"` (brand) — leave **out** of the catalog (no entry); `L10n.s` returns the key unchanged in every language.

**The 7 new keys to add** (with their translations — these are the only values specified inline; reproduce this exact shape):

| key | zh-Hans | zh-Hant | ja | ko |
|---|---|---|---|---|
| `Language` | 语言 | 語言 | 言語 | 언어 |
| `Follow System` | 跟随系统 | 跟隨系統 | システムに従う | 시스템 설정 |
| `Delete` | 删除 | 刪除 | 削除 | 삭제 |
| `Edit` | 编辑 | 編輯 | 編集 | 편집 |
| `Add Bill` | 添加账单 | 新增帳單 | 請求を追加 | 청구서 추가 |
| `Edit Bill` | 编辑账单 | 編輯帳單 | 請求を編集 | 청구서 편집 |
| `Delete Bill` | 删除账单 | 刪除帳單 | 請求を削除 | 청구서 삭제 |

**Worked example for an existing key with a placeholder** (`"%@ is due today (%@)!"`):
```json
"%@ is due today (%@)!": {
  "localizations": {
    "zh-Hans": { "stringUnit": { "state": "translated", "value": "%@ 今天到期（%@）！" } },
    "zh-Hant": { "stringUnit": { "state": "translated", "value": "%@ 今天到期（%@）！" } },
    "ja":      { "stringUnit": { "state": "translated", "value": "%@ は本日支払い期日です（%@）！" } },
    "ko":      { "stringUnit": { "state": "translated", "value": "%@ 오늘 결제일입니다(%@)!" } }
  }
}
```
Translate the remaining existing keys following the same shape. Use the full key list: every key currently in the catalog (run the command in Step 3 to enumerate them) — these are the same 141 `NSLocalizedString` keys plus a few auto-extracted format keys (e.g. `"%@"`).

- [ ] **Step 3: Verify completeness programmatically**

Run (from repo root) to list every key and confirm each language is covered:
```bash
python3 - <<'PY'
import json
d = json.load(open("BillsManager/Resources/Localizable.xcstrings"))
langs = ["zh-Hans","zh-Hant","ja","ko"]
missing = []
for k, v in d["strings"].items():
    locs = v.get("localizations", {})
    for lg in langs:
        st = locs.get(lg, {}).get("stringUnit", {})
        if st.get("state") != "translated" or not st.get("value"):
            missing.append((k, lg))
print("total keys:", len(d["strings"]))
print("missing translations:", len(missing))
for k, lg in missing[:20]:
    print("  -", repr(k), lg)
PY
```
Expected: `missing translations: 0`. If any are listed, fill them and re-run.

- [ ] **Step 4: Extend the DEBUG self-check to assert `.lproj` bundles ship**

In `BillsManager/Managers/L10n.swift`, add to `LocalizationSelfCheck.run()` (inside the `#if DEBUG` block, after the existing asserts):

```swift
        // Every non-English supported language compiles to an .lproj in the bundle.
        for code in AppLanguage.supportedCodes where code != "en" {
            assert(Bundle.main.path(forResource: code, ofType: "lproj") != nil,
                   "Missing .lproj for \(code) — check knownRegions and translations")
        }
        print("[L10n] lproj coverage self-check passed")
```

- [ ] **Step 5: Build + run, verify full coverage**

Run: `xcodebuild -project BillsManager.xcodeproj -scheme BillsManager -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`, and on launch the console prints both `[L10n] resolution self-check passed` and `[L10n] lproj coverage self-check passed`.

Run in the simulator → Settings → Language → tap each of **English / 简体中文 / 繁體中文 / 日本語 / 한국어**. Each must show a fully-translated UI with **no English bleed-through** (Dashboard, Bills, Calendar, Analytics, Settings).

- [ ] **Step 6: Commit**

```bash
git add BillsManager/Resources/Localizable.xcstrings BillsManager.xcodeproj/project.pbxproj BillsManager/Managers/L10n.swift
git commit -m "feat(l10n): add zh-Hant/ja/ko + complete translations, register knownRegions"
```

---

## Task 6: Final verification & polish

**Files:** none mandatory (fix-ups only, as found).

- [ ] **Step 1: Persistence check**

In the simulator, pick 日本語, then kill and relaunch the app. Expected: app launches in Japanese (choice persisted via `UserDefaults`).

- [ ] **Step 2: Follow-System check**

Set the simulator/Preview language to Korean (`ko`) via the scheme's Run options (or Simulator Settings). Relaunch with the in-app choice set to **Follow System**. Expected: app matches Korean. Then set the system language to French (`fr`) — expected: app falls back to English.

- [ ] **Step 3: Formatting check**

In 日本語 and 한국어, confirm date and currency fields (e.g. due dates, amounts rendered via SwiftUI `Text` + `.currency`/`Date.FormatStyle`) follow the locale. (Note the known limitation: the Dashboard "Total overdue" `String(format: "$%.2f")` string does not change decimal separator — pre-existing, out of scope.)

- [ ] **Step 4: Sweep for English bleed-through**

Visit every screen (Dashboard, Bills list/detail/add-edit, Calendar, Analytics, Categories, Accounts, Settings, Paywall, Onboarding, Passcode/Lock, Splash). Any English string under a non-English language = a missing translation or a string not routed through `L10n.s`. Fix by adding the translation or wrapping the literal in `L10n.s(…)`.

- [ ] **Step 5: Commit any fix-ups**

```bash
git add -A
git commit -m "fix(l10n): close remaining English bleed-through"
```
(Skip if nothing changed.)

---

## Self-Review Notes (plan author)

- **Spec coverage:** §4 components → Tasks 1–2; §5 migration → Task 3; §6 re-render → Task 2; §7 UI → Task 4; §8 translations/knownRegions → Task 5; §10 testing → Tasks 1/2/5 self-checks + Task 6 manual. §3 non-goals (data, notifications) intentionally unaddressed.
- **Type/name consistency:** `LanguageManager.shared`, `effectiveCode`, `selected`, `setLanguage(_:)`, `string(_:table:)`, `L10n.s(_:)`, `AppLanguage.resolveEffectiveCode(selected:preferredLocalizations:)`, `AppLanguage.supportedCodes` — used identically across tasks.
- **Testing deviation:** no XCTest target exists and none is added (high hand-edit risk, out of scope). Verification = DEBUG self-check (resolution + lproj coverage) + `xcodebuild` + manual simulator smoke, matching spec §10. This is documented in Global Constraints.
- **pbxproj IDs `01010030–34` / `01020030–34` confirmed unused** (max existing build-file `01010022`, file-ref `01020022`, group `0104000E`).
