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
                        Text(NSLocalizedString("Default", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    if !category.isSystem {
                        Button(role: .destructive) {
                            modelContext.delete(category)
                            try? modelContext.save()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("Categories", comment: ""))
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
                    Section(NSLocalizedString("Category Info", comment: "")) {
                        TextField(NSLocalizedString("Category Name", comment: ""), text: $categoryName)
                        
                        NavigationLink(destination: IconPickerView(selectedIcon: $iconName)) {
                            HStack {
                                Text(NSLocalizedString("Icon", comment: ""))
                                Spacer()
                                Image(systemName: iconName)
                                    .font(.title3)
                                    .foregroundStyle(categoryColor)
                            }
                        }
                        
                        ColorPicker(NSLocalizedString("Color", comment: ""), selection: $categoryColor)
                    }
                }
                .navigationTitle(NSLocalizedString("Add Category", comment: ""))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingAddCategorySheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard !categoryName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            let newCat = Category(
                                name: categoryName,
                                iconName: iconName,
                                hexColor: categoryColor.toHex(),
                                isSystem: false
                            )
                            modelContext.insert(newCat)
                            try? modelContext.save()
                            showingAddCategorySheet = false
                        }
                        .disabled(categoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }
}
