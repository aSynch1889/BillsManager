import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    @Query private var categories: [Category]
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingAddCategorySheet: Bool = false
    @State private var editingCategory: Category? = nil
    
    @State private var categoryName: String = ""
    @State private var iconName: String = "folder.fill"
    @State private var categoryColor: Color = .blue
    @State private var persistenceError: String?
    
    var body: some View {
        List {
            ForEach(categories) { category in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(category.color)
                            .frame(width: 36, height: 36)
                        Image(systemName: category.iconName)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    
                    Text(category.name)
                        .font(.body.weight(.medium))
                    
                    Spacer()
                    
                    if category.isSystem {
                        Text(L10n.s("Default"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    if !category.isSystem {
                        Button(role: .destructive) {
                            modelContext.delete(category)
                            if let message = Persistence.saveReturningMessage(modelContext) {
                                persistenceError = message
                            }
                        } label: {
                            Label(L10n.s("Delete"), systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.s("Categories"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    categoryName = ""
                    iconName = "folder.fill"
                    categoryColor = .blue
                    showingAddCategorySheet = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCategorySheet) {
            NavigationStack {
                Form {
                    Section(L10n.s("Category Info")) {
                        TextField(L10n.s("Category Name"), text: $categoryName)
                        
                        NavigationLink(destination: IconPickerView(selectedIcon: $iconName)) {
                            HStack {
                                Text(L10n.s("Icon"))
                                Spacer()
                                Image(systemName: iconName)
                                    .font(.title3)
                                    .foregroundStyle(categoryColor)
                            }
                        }
                        
                        ColorPicker(L10n.s("Color"), selection: $categoryColor)
                    }
                }
                .navigationTitle(L10n.s("Add Category"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.s("Cancel")) { showingAddCategorySheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.s("Save")) {
                            guard !categoryName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            let newCat = Category(
                                name: categoryName,
                                iconName: iconName,
                                hexColor: categoryColor.toHex(),
                                isSystem: false
                            )
                            modelContext.insert(newCat)
                            if let message = Persistence.saveReturningMessage(modelContext) {
                                persistenceError = message
                                return
                            }
                            showingAddCategorySheet = false
                        }
                        .disabled(categoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .persistenceAlert($persistenceError)
    }
}
