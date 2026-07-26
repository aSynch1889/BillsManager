import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    
    let icons: [String] = [
        "bolt.fill", "house.fill", "play.tv.fill", "creditcard.fill", "shield.fill",
        "banknote.fill", "person.fill", "building.columns.fill", "cart.fill", "car.fill",
        "cross.case.fill", "book.fill", "airplane", "gamecontroller.fill", "wifi",
        "phone.fill", "drop.fill", "flame.fill", "leaf.fill", "heart.fill",
        "star.fill", "bell.fill", "briefcase.fill", "graduationcap.fill", "wrench.fill"
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                ForEach(icons, id: \.self) { icon in
                    Button(action: {
                        selectedIcon = icon
                        dismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(selectedIcon == icon ? Color.blue.opacity(0.2) : Color(.secondarySystemGroupedBackground))
                                .frame(width: 54, height: 54)
                            
                            Image(systemName: icon)
                                .font(.title3)
                                .foregroundStyle(selectedIcon == icon ? Color.blue : Color.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("Select Icon", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }
}
