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
