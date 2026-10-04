import Foundation

@MainActor
enum ListSharing {
    static func makeDocument(from list: ShoppingList) -> SharedListDocument {
        let items = list.items
            .sorted { $0.createdAt < $1.createdAt }
            .map { item in
                SharedItem(
                    id: item.id,
                    name: item.name,
                    quantity: item.quantity,
                    isPurchased: item.isPurchased,
                    purchasedAt: item.purchasedAt,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt,
                    deletedAt: item.deletedAt,
                    category: item.category.map { category in
                        SharedCategory(
                            name: category.name,
                            symbolName: category.symbolName,
                            colorName: category.colorName
                        )
                    }
                )
            }

        let sharedList = SharedList(
            id: list.id,
            name: list.name,
            createdAt: list.createdAt,
            updatedAt: list.updatedAt,
            items: items
        )

        let file = SharedListFile(
            version: SharedListFile.currentVersion,
            exportedAt: .now,
            list: sharedList
        )
        return SharedListDocument(file: file)
    }

    static func plainText(for list: ShoppingList, categories: [ProductCategory]) -> String {
        let sections = ItemSection.build(from: list.activeItems, categories: categories)

        var lines = [list.name]
        for section in sections {
            lines.append("")
            lines.append("\(section.title):")
            for item in section.items {
                let mark = item.isPurchased ? "[x]" : "[ ]"
                let quantity = item.quantity.isEmpty ? "" : " (\(item.quantity))"
                lines.append("\(mark) \(item.name)\(quantity)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
