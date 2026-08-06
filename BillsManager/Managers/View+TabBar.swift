import SwiftUI

extension View {
    /// Hide the tab bar while this screen is pushed on a `NavigationStack` inside `TabView`.
    func hidesTabBarWhenPushed() -> some View {
        toolbar(.hidden, for: .tabBar)
    }
}
