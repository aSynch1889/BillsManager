import Foundation

extension Notification.Name {
    static let screenshotSelectScreen = Notification.Name("billsmanager.screenshotSelectScreen")
}

/// Launch-argument helpers used only when capturing App Store screenshots.
enum ScreenshotDemo {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-screenshotDemo")
    }

    /// `Dashboard`, `Bills`, `Calendar`, `Analytics`, `Settings`, or `Paywall`.
    static var requestedScreen: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-screenshotTab"), args.indices.contains(index + 1) else {
            return isActive ? "Dashboard" : nil
        }
        return args[index + 1]
    }

    static var initialTab: NavigationTab {
        tab(for: requestedScreen)
    }

    static var showsPaywall: Bool {
        requestedScreen == "Paywall"
    }

    static func tab(for screen: String?) -> NavigationTab {
        switch screen {
        case "Bills": return .bills
        case "Calendar": return .calendar
        case "Analytics": return .analytics
        case "Settings", "Paywall": return .settings
        default: return .dashboard
        }
    }

    static func handleOpenURL(_ url: URL) {
        guard url.scheme == "billsmanager" else { return }
        let screen = url.host ?? url.pathComponents.dropFirst().first
        NotificationCenter.default.post(name: .screenshotSelectScreen, object: screen)
    }
}
