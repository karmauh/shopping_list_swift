import Foundation
import SwiftData

@Model
final class ShoppingItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: String
    var isPurchased: Bool
    var purchasedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    var list: ShoppingList?
    var category: ProductCategory?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: String = "",
        isPurchased: Bool = false,
        purchasedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        list: ShoppingList? = nil,
        category: ProductCategory? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.isPurchased = isPurchased
        self.purchasedAt = purchasedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.list = list
        self.category = category
    }
}

extension ShoppingItem {
    func setPurchased(_ purchased: Bool) {
        isPurchased = purchased
        purchasedAt = purchased ? .now : nil
        touch()
    }

    func markDeleted() {
        deletedAt = .now
        touch()
    }

    private func touch() {
        updatedAt = .now
        list?.updatedAt = .now
    }
}
