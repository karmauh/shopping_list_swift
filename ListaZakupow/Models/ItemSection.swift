import SwiftUI

struct ItemSection: Identifiable {
    enum Kind {
        case category(ProductCategory)
        case uncategorized
        case purchased
    }

    let kind: Kind
    let items: [ShoppingItem]

    var id: String {
        switch kind {
        case .category(let category):
            return category.id.uuidString
        case .uncategorized:
            return "uncategorized"
        case .purchased:
            return "purchased"
        }
    }

    var title: String {
        switch kind {
        case .category(let category):
            return category.name
        case .uncategorized:
            return "Bez kategorii"
        case .purchased:
            return "Kupione"
        }
    }

    var symbolName: String {
        switch kind {
        case .category(let category):
            return category.symbolName
        case .uncategorized:
            return "tray.fill"
        case .purchased:
            return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch kind {
        case .category(let category):
            return category.categoryColor.color
        case .uncategorized, .purchased:
            return .gray
        }
    }

    static func build(from items: [ShoppingItem], categories: [ProductCategory]) -> [ItemSection] {
        let pending = items.filter { !$0.isPurchased }
        let purchased = items.filter { $0.isPurchased }

        var result: [ItemSection] = []

        for category in categories {
            let group = pending
                .filter { $0.category?.id == category.id }
                .sorted { $0.createdAt < $1.createdAt }
            if !group.isEmpty {
                result.append(ItemSection(kind: .category(category), items: group))
            }
        }

        let uncategorized = pending
            .filter { $0.category == nil }
            .sorted { $0.createdAt < $1.createdAt }
        if !uncategorized.isEmpty {
            result.append(ItemSection(kind: .uncategorized, items: uncategorized))
        }

        if !purchased.isEmpty {
            let sorted = purchased.sorted {
                ($0.purchasedAt ?? .distantPast) < ($1.purchasedAt ?? .distantPast)
            }
            result.append(ItemSection(kind: .purchased, items: sorted))
        }

        return result
    }
}
