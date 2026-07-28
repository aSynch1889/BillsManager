import SwiftUI

struct iPadSidebarView: View {
    @Binding var selectedTab: NavigationTab
    @Binding var showingAddBill: Bool
    
    var body: some View {
        NavigationSplitView {
            List {
                ForEach(NavigationTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack {
                            Label(tab.localizedTitle, systemImage: tab.icon)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Bills Manager")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddBill = true }) {
                        Label(L10n.s("Add Bill"), systemImage: "plus")
                    }
                }
            }
        } detail: {
            switch selectedTab {
            case .dashboard:
                NavigationStack {
                    DashboardView(showingAddBill: $showingAddBill)
                }
            case .bills:
                NavigationStack {
                    BillListView(showingAddBill: $showingAddBill)
                }
            case .calendar:
                NavigationStack {
                    BillCalendarView()
                }
            case .analytics:
                NavigationStack {
                    AnalyticsView()
                }
            case .settings:
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .sheet(isPresented: $showingAddBill) {
            NavigationStack {
                AddEditBillView(billToEdit: nil)
            }
        }
    }
}
