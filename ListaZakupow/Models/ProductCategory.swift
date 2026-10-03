import Foundation
import SwiftData

@Model
final class ProductCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var symbolName: String
    var colorName: String
    var sortOrder: Int
    var isDefault: Bool

    @Relationship(deleteRule: .nullify, inverse: \ShoppingItem.category)
    var items: [ShoppingItem] = []

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        colorName: String,
        sortOrder: Int,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.colorName = colorName
        self.sortOrder = sortOrder
        self.isDefault = isDefault
    }

    var categoryColor: CategoryColor {
        CategoryColor(rawValue: colorName) ?? .gray
    }
}

extension ProductCategory {
    var isFallback: Bool {
        isDefault && name == "Inne" && symbolName == "ellipsis.circle.fill"
    }
}
