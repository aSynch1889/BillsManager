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
    @Environment(CloudSyncManager.self) private var cloudSyncManager
    @State private var selectedTab: NavigationTab = ScreenshotDemo.isActive ? ScreenshotDemo.initialTab : .dashboard
    @State private var showingAddBill: Bool = false
    @State private var showingScreenshotPaywall: Bool = ScreenshotDemo.showsPaywall
    
    var body: some View {
        VStack(spacing: 0) {
            if cloudSyncManager.restartRequired {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundStyle(.orange)
                    Text(syncRestartBannerText)
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
            }

            if horizontalSizeClass == .regular {
                iPadSidebarView(selectedTab: $selectedTab, showingAddBill: $showingAddBill)
            } else {
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
        .sheet(isPresented: $showingScreenshotPaywall) {
            NavigationStack {
                PaywallView()
            }
        }
        .onOpenURL { url in
            ScreenshotDemo.handleOpenURL(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .screenshotSelectScreen)) { note in
            guard let screen = note.object as? String else { return }
            selectedTab = ScreenshotDemo.tab(for: screen)
            showingScreenshotPaywall = (screen == "Paywall")
        }
    }

    private var syncRestartBannerText: String {
        if cloudSyncManager.disabledDueToProExpiration {
            return L10n.s("Your PRO subscription ended. iCloud sync was turned off. Force-quit the app from the app switcher, then open it again to keep your data on this device.")
        }
        return L10n.s("Force-quit the app from the app switcher, then open it again to apply iCloud sync changes.")
    }
}
