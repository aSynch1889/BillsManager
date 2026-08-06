import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    @Query private var categories: [Category]
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var storeManager

    @State private var showingAddCategorySheet: Bool = false
    @State private var editingCategory: Category? = nil
    @State private var showingPaywall: Bool = false

    @State private var categoryName: String = ""
    @State private var iconName: String = "folder.fill"
    @State private var categoryColor: Color = .blue
    @State private var persistenceError: String?
    @State private var categoryPendingDelete: Category?

    private var customCategoryCount: Int {
        categories.filter { !$0.isSystem }.count
    }

    var body: some View {
        List {
            if !storeManager.canAccess(.unlimitedCategories) {
                Section {
                    Text(String(format: L10n.s("Free plan: %d / %d custom categories"), customCategoryCount, ProFeature.freeCustomCategoryLimit))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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

                    Text(category.localizedDisplayName)
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
                            categoryPendingDelete = category
                        } label: {
                            Label(L10n.s("Delete"), systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.s("Categories"))
        .confirmationDialog(
            deleteCategoryTitle,
            isPresented: Binding(
                get: { categoryPendingDelete != nil },
                set: { if !$0 { categoryPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.s("Delete"), role: .destructive) {
                guard let category = categoryPendingDelete else { return }
                modelContext.delete(category)
                if let message = Persistence.saveReturningMessage(modelContext) {
                    persistenceError = message
                }
                categoryPendingDelete = nil
            }
            Button(L10n.s("Cancel"), role: .cancel) {
                categoryPendingDelete = nil
            }
        } message: {
            if let category = categoryPendingDelete {
                let count = category.bills?.count ?? 0
                Text(String(format: L10n.s("%d linked bills will keep their data but lose this category."), count))
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: attemptAddCategory) {
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
        .sheet(isPresented: $showingPaywall) {
            NavigationStack {
                PaywallView()
            }
        }
        .persistenceAlert($persistenceError)
    }

    private var deleteCategoryTitle: String {
        guard let category = categoryPendingDelete else { return L10n.s("Delete") }
        return String(format: L10n.s("Delete category “%@”?"), category.localizedDisplayName)
    }

    private func attemptAddCategory() {
        guard storeManager.canAddCustomCategory(currentCustomCount: customCategoryCount) else {
            showingPaywall = true
            return
        }
        categoryName = ""
        iconName = "folder.fill"
        categoryColor = .blue
        showingAddCategorySheet = true
    }
}
