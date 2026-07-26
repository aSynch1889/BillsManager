import SwiftUI
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    var iconName: String
    var hexColor: String
    var isSystem: Bool
    
    @Relationship(deleteRule: .nullify, inverse: \Bill.category)
    var bills: [Bill]?
    
    init(id: UUID = UUID(), name: String, iconName: String, hexColor: String, isSystem: Bool = false) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.hexColor = hexColor
        self.isSystem = isSystem
        self.bills = []
    }
    
    var color: Color {
        Color(hex: hexColor) ?? .blue
    }
}

extension Category {
    static var defaults: [Category] {
        [
            Category(name: "Utilities", iconName: "bolt.fill", hexColor: "#F59E0B", isSystem: true),
            Category(name: "Housing", iconName: "house.fill", hexColor: "#3B82F6", isSystem: true),
            Category(name: "Subscriptions", iconName: "play.tv.fill", hexColor: "#8B5CF6", isSystem: true),
            Category(name: "Credit Card", iconName: "creditcard.fill", hexColor: "#EF4444", isSystem: true),
            Category(name: "Insurance", iconName: "shield.fill", hexColor: "#10B981", isSystem: true),
            Category(name: "Loans", iconName: "banknote.fill", hexColor: "#6B7280", isSystem: true),
            Category(name: "Personal", iconName: "person.fill", hexColor: "#EC4899", isSystem: true)
        ]
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "#3B82F6"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
