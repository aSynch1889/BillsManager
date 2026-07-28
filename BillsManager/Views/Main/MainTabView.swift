import SwiftUI

enum NavigationTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case bills = "Bills"
    case calendar = "Calendar"
    case analytics = "Analytics"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .bills: return "doc.text.fill"
        case .calendar: return "calendar"
        case .analytics: return "chart.pie.fill"
        case .settings: return "gearshape.fill"
        }
    }
    
    var localizedTitle: String {
        switch self {
        case .dashboard: return L10n.s("Dashboard")
        case .bills: return L10n.s("Bills")
        case .calendar: return L10n.s("Calendar")
        case .analytics: return L10n.s("Analytics")
        case .settings: return L10n.s("Settings")
        }
    }
}

struct MainTabView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: NavigationTab = .dashboard
    @State private var showingAddBill: Bool = false
    
    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad Layout
            iPadSidebarView(selectedTab: $selectedTab, showingAddBill: $showingAddBill)
        } else {
            // iPhone Layout
            TabView(selection: $selectedTab) {
                NavigationStack {
                    DashboardView(showingAddBill: $showingAddBill)
                }
                .tabItem {
                    Label(NavigationTab.dashboard.localizedTitle, systemImage: NavigationTab.dashboard.icon)
                }
                .tag(NavigationTab.dashboard)
                
                NavigationStack {
                    BillListView(showingAddBill: $showingAddBill)
                }
                .tabItem {
                    Label(NavigationTab.bills.localizedTitle, systemImage: NavigationTab.bills.icon)
                }
                .tag(NavigationTab.bills)
                
                NavigationStack {
                    BillCalendarView()
                }
                .tabItem {
                    Label(NavigationTab.calendar.localizedTitle, systemImage: NavigationTab.calendar.icon)
                }
                .tag(NavigationTab.calendar)
                
                NavigationStack {
                    AnalyticsView()
                }
                .tabItem {
                    Label(NavigationTab.analytics.localizedTitle, systemImage: NavigationTab.analytics.icon)
                }
                .tag(NavigationTab.analytics)
                
                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label(NavigationTab.settings.localizedTitle, systemImage: NavigationTab.settings.icon)
                }
                .tag(NavigationTab.settings)
            }
            .sheet(isPresented: $showingAddBill) {
                NavigationStack {
                    AddEditBillView(billToEdit: nil)
                }
            }
        }
    }
}
