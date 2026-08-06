import SwiftUI
import SwiftData

@Model
final class Account {
    var id: UUID
    var name: String
    var accountNumberLast4: String?
    var iconName: String
    var hexColor: String
    var isDefault: Bool
    
    @Relationship(deleteRule: .nullify, inverse: \Bill.account)
    var bills: [Bill]?
    
    init(id: UUID = UUID(), name: String, accountNumberLast4: String? = nil, iconName: String = "creditcard.fill", hexColor: String = "#3B82F6", isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.accountNumberLast4 = accountNumberLast4
        self.iconName = iconName
        self.hexColor = hexColor
        self.isDefault = isDefault
        self.bills = []
    }
    
    var color: Color {
        Color(hex: hexColor) ?? .blue
    }

    /// Default seed accounts keep English storage keys; UI resolves via L10n.
    var localizedDisplayName: String {
        Self.defaultEnglishNames.contains(name) ? L10n.s(name) : name
    }

    private static let defaultEnglishNames: Set<String> = [
        "Checking Account", "Credit Card", "Cash"
    ]
}

extension Account {
    static var defaults: [Account] {
        [
            Account(name: "Checking Account", accountNumberLast4: "4321", iconName: "building.columns.fill", hexColor: "#3B82F6", isDefault: true),
            Account(name: "Credit Card", accountNumberLast4: "8899", iconName: "creditcard.fill", hexColor: "#EF4444"),
            Account(name: "Cash", iconName: "dollarsign.circle.fill", hexColor: "#10B981")
        ]
    }
}
