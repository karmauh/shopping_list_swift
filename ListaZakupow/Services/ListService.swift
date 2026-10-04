import Foundation
import SwiftData

enum ListService {
    @discardableResult
    static func duplicate(_ list: ShoppingList, in context: ModelContext) -> ShoppingList {
        let existingKeys = ((try? context.fetch(FetchDescriptor<ShoppingList>())) ?? [])
            .map { $0.name.comparisonKey }
        let name = uniqueCopyName(for: list.name, existingKeys: existingKeys)

        let copy = ShoppingList(name: name)
        context.insert(copy)

        for item in list.activeItems {
            let newItem = ShoppingItem(
                name: item.name,
                quantity: item.quantity,
                createdAt: item.createdAt
            )
            context.insert(newItem)
            newItem.list = copy
            newItem.category = item.category
        }

        return copy
    }

    private static func uniqueCopyName(for name: String, existingKeys: [String]) -> String {
        let base = "\(name) (kopia)"
        if !existingKeys.contains(base.comparisonKey) {
            return base
        }
        var number = 2
        while existingKeys.contains("\(base) \(number)".comparisonKey) {
            number += 1
        }
        return "\(base) \(number)"
    }
}
