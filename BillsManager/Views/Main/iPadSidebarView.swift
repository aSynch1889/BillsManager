import SwiftUI
import SwiftData

struct iPadSidebarView: View {
    @Binding var selectedTab: NavigationTab
    @Binding var showingAddBill: Bool
    @State private var selectedBillID: PersistentIdentifier?

    var body: some View {
        Group {
            if selectedTab == .bills {
                billsSplitView
            } else {
                sectionSplitView
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingAddBill) {
            NavigationStack {
                AddEditBillView(billToEdit: nil)
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab != .bills {
                selectedBillID = nil
            }
        }
    }

    /// Bills: sidebar → list → detail (true master-detail).
    private var billsSplitView: some View {
        NavigationSplitView {
            sidebarList
        } content: {
            BillListView(showingAddBill: $showingAddBill, selectedBillID: $selectedBillID)
        } detail: {
            BillsDetailColumn(selectedBillID: $selectedBillID)
        }
    }

    /// Other tabs: sidebar → full-width content (no empty third column).
    private var sectionSplitView: some View {
        NavigationSplitView {
            sidebarList
        } detail: {
            NavigationStack {
                switch selectedTab {
                case .dashboard:
                    DashboardView(showingAddBill: $showingAddBill)
                case .calendar:
                    BillCalendarView()
                case .analytics:
                    AnalyticsView()
                case .settings:
                    SettingsView()
                case .bills:
                    EmptyView()
                }
            }
        }
    }

    private var sidebarList: some View {
        List {
            ForEach(NavigationTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Label(tab.localizedTitle, systemImage: tab.icon)
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary)
                }
                .listRowBackground(selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
            }
        }
        .navigationTitle(L10n.s("Bills Manager"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddBill = true }) {
                    Label(L10n.s("Add Bill"), systemImage: "plus")
                }
            }
        }
    }
}

private struct BillsDetailColumn: View {
    @Binding var selectedBillID: PersistentIdentifier?
    @Query(sort: \Bill.dueDate) private var bills: [Bill]

    var body: some View {
        if let selectedBillID,
           let bill = bills.first(where: { $0.persistentModelID == selectedBillID }) {
            BillDetailView(bill: bill)
        } else {
            ContentUnavailableView(
                L10n.s("Select a Bill"),
                systemImage: "doc.text",
                description: Text(L10n.s("Choose a bill from the list to see details."))
            )
        }
    }
}
