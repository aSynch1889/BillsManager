import SwiftUI
import SwiftData

enum BillFilterTab: String, CaseIterable, Identifiable {
    case all = "All"
    case overdue = "Overdue"
    case unpaid = "Unpaid"
    case paid = "Paid"
    
    var id: String { rawValue }
    
    var localizedTitle: String {
        switch self {
        case .all: return L10n.s("All")
        case .overdue: return L10n.s("Overdue")
        case .unpaid: return L10n.s("Unpaid")
        case .paid: return L10n.s("Paid")
        }
    }
}

struct BillListView: View {
    @Binding var showingAddBill: Bool
    
    @Query(sort: \Bill.dueDate) private var allBills: [Bill]
    @Query private var categories: [Category]
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedFilter: BillFilterTab = .all
    @State private var selectedCategory: Category? = nil
    @State private var searchText: String = ""
    @State private var editingBill: Bill? = nil
    
    private var filteredBills: [Bill] {
        allBills.filter { bill in
            // Filter by Tab
            switch selectedFilter {
            case .all:
                break
            case .overdue:
                guard bill.status == .overdue else { return false }
            case .unpaid:
                guard !bill.isPaid else { return false }
            case .paid:
                guard bill.isPaid else { return false }
            }
            
            // Filter by Category
            if let selectedCategory = selectedCategory {
                guard bill.category?.id == selectedCategory.id else { return false }
            }
            
            // Filter by Search Text
            if !searchText.isEmpty {
                let textMatch = bill.name.localizedCaseInsensitiveContains(searchText) ||
                (bill.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
                guard textMatch else { return false }
            }
            
            return true
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar & Filter Picker
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(L10n.s("Search bills..."), text: $searchText)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                Picker(L10n.s("Filter"), selection: $selectedFilter) {
                    ForEach(BillFilterTab.allCases) { tab in
                        Text(tab.localizedTitle).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                
                // Category Filter Scroll View
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button(action: { selectedCategory = nil }) {
                            Text(L10n.s("All Categories"))
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedCategory == nil ? Color.blue : Color(.secondarySystemGroupedBackground))
                                .foregroundStyle(selectedCategory == nil ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        
                        ForEach(categories) { category in
                            Button(action: { selectedCategory = category }) {
                                HStack(spacing: 4) {
                                    Image(systemName: category.iconName)
                                    Text(category.name)
                                }
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedCategory?.id == category.id ? category.color : Color(.secondarySystemGroupedBackground))
                                .foregroundStyle(selectedCategory?.id == category.id ? .white : .primary)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            
            // List View
            if filteredBills.isEmpty {
                ContentUnavailableView(
                    L10n.s("No Bills Found"),
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(L10n.s("Tap '+' to create your first bill or change your search filter."))
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredBills) { bill in
                        NavigationLink(destination: BillDetailView(bill: bill)) {
                            BillRowView(bill: bill)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteBill(bill)
                            } label: {
                                Label(L10n.s("Delete"), systemImage: "trash")
                            }
                            
                            Button {
                                editingBill = bill
                            } label: {
                                Label(L10n.s("Edit"), systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                togglePaid(bill)
                            } label: {
                                Label(bill.isPaid ? L10n.s("Unpay") : L10n.s("Pay"), systemImage: bill.isPaid ? "xmark.circle" : "checkmark.circle")
                            }
                            .tint(bill.isPaid ? .gray : .green)
                        }
                    }
                }
                .listStyle(.plain)
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle(L10n.s("Bills"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddBill = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(item: $editingBill) { bill in
            NavigationStack {
                AddEditBillView(billToEdit: bill)
            }
        }
    }
    
    private func deleteBill(_ bill: Bill) {
        NotificationManager.shared.cancelNotification(for: bill)
        modelContext.delete(bill)
        try? modelContext.save()
    }
    
    private func togglePaid(_ bill: Bill) {
        withAnimation {
            if bill.isPaid {
                bill.markAsUnpaid()
                NotificationManager.shared.scheduleNotification(for: bill)
            } else {
                bill.markAsPaid()
                NotificationManager.shared.cancelNotification(for: bill)
            }
            try? modelContext.save()
        }
    }
}
