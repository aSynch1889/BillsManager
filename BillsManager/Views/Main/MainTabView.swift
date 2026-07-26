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
        case .dashboard: return NSLocalizedString("Dashboard", comment: "")
        case .bills: return NSLocalizedString("Bills", comment: "")
        case .calendar: return NSLocalizedString("Calendar", comment: "")
        case .analytics: return NSLocalizedString("Analytics", comment: "")
        case .settings: return NSLocalizedString("Settings", comment: "")
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
