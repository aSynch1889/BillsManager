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
