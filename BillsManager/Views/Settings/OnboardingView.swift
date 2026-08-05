import SwiftUI
import SwiftData

struct OnboardingItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let gradientColors: [Color]
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var currentPage: Int = 0
    @State private var loadSampleData: Bool = false

    let items: [OnboardingItem] = [
        OnboardingItem(
            title: L10n.s("Track Bills Effortlessly"),
            description: L10n.s("Organize utilities, subscriptions, rent, and card payments in one unified place with automatic recurring dates."),
            iconName: "doc.text.fill",
            gradientColors: [.blue, .indigo]
        ),
        OnboardingItem(
            title: L10n.s("Never Miss a Payment"),
            description: L10n.s("Receive timely local notifications before due dates and view interactive monthly calendar indicator dots."),
            iconName: "bell.badge.fill",
            gradientColors: [.orange, .amber]
        ),
        OnboardingItem(
            title: L10n.s("Privacy & Professional Tools"),
            description: L10n.s("100% local storage protected with Face ID. Export data to CSV or JSON backup anytime."),
            iconName: "lock.shield.fill",
            gradientColors: [.emerald, .teal]
        )
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if currentPage < items.count - 1 {
                        Button(action: completeOnboarding) {
                            Text(L10n.s("Skip"))
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)

                TabView(selection: $currentPage) {
                    ForEach(0..<items.count, id: \.self) { index in
                        let item = items[index]
                        VStack(spacing: 32) {
                            Spacer()

                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: item.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 140, height: 140)
                                    .shadow(color: item.gradientColors.first?.opacity(0.3) ?? .clear, radius: 20, x: 0, y: 10)

                                Image(systemName: item.iconName)
                                    .font(.system(size: 64, weight: .semibold))
                                    .foregroundStyle(.white)
                            }

                            VStack(spacing: 12) {
                                Text(item.title)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)

                                Text(item.description)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }

                            if index == items.count - 1 {
                                Toggle(isOn: $loadSampleData) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(L10n.s("Load Sample Bills"))
                                            .font(.subheadline.bold())
                                        Text(L10n.s("Optional demo data you can remove later in Settings."))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 32)
                                .padding(.top, 8)
                            }

                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                VStack(spacing: 16) {
                    Button(action: {
                        if currentPage < items.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    }) {
                        Text(currentPage == items.count - 1 ? L10n.s("Get Started") : L10n.s("Next"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.blue.opacity(0.25), radius: 10, x: 0, y: 4)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)
            }
        }
    }

    private func completeOnboarding() {
        Task {
            _ = await NotificationManager.shared.requestAuthorization()
            await MainActor.run {
                if loadSampleData {
                    SampleDataSeeder.insertSamplesIfNeeded(context: modelContext)
                }
                withAnimation {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}

private extension Color {
    static let amber = Color(red: 0.95, green: 0.65, blue: 0.15)
    static let emerald = Color(red: 0.06, green: 0.73, blue: 0.5)
}
