import SwiftUI
import SwiftData

struct iPadSidebarView: View {
    @Binding var selectedTab: NavigationTab
    @Binding var showingAddBill: Bool
    @State private var selectedBillID: PersistentIdentifier?

    var body: some View {
        NavigationSplitView {
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
        } content: {
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView(showingAddBill: $showingAddBill)
                case .bills:
                    BillListView(showingAddBill: $showingAddBill, selectedBillID: $selectedBillID)
                case .calendar:
                    BillCalendarView()
                case .analytics:
                    AnalyticsView()
                case .settings:
                    SettingsView()
                }
            }
            .navigationTitle(selectedTab.localizedTitle)
        } detail: {
            if selectedTab == .bills {
                BillsDetailColumn(selectedBillID: $selectedBillID)
            } else {
                ContentUnavailableView(
                    L10n.s("Select a section"),
                    systemImage: "sidebar.left",
                    description: Text(L10n.s("Choose an item from the sidebar to get started."))
                )
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
