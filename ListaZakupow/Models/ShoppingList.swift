import Foundation
import SwiftData

@Model
final class ShoppingList {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ShoppingItem.list)
    var items: [ShoppingItem] = []

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var activeItems: [ShoppingItem] {
        items.filter { $0.deletedAt == nil }
    }

    var totalCount: Int {
        activeItems.count
    }

    var purchasedCount: Int {
        activeItems.filter { $0.isPurchased }.count
    }
}

extension ShoppingList {
    func activeItem(named name: String, excluding excluded: ShoppingItem? = nil) -> ShoppingItem? {
        let key = name.comparisonKey
        guard !key.isEmpty else { return nil }
        return activeItems.first {
            $0.id != excluded?.id && $0.name.comparisonKey == key
        }
    }
}
