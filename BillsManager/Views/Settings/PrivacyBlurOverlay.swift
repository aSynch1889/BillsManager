import SwiftUI

/// Full-screen blur used while the scene is inactive/background so App Switcher
/// does not reveal bill amounts or names.
struct PrivacyBlurOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Bills Manager")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)
        }
        .allowsHitTesting(true)
    }
}
