import Foundation
import SwiftData

enum CategoryService {
    static func fallbackCategory(in context: ModelContext) -> ProductCategory {
        let all = fetchSorted(in: context)
        if let existing = all.first(where: { $0.isFallback }) {
            return existing
        }
        let created = ProductCategory(
            name: "Inne",
            symbolName: "ellipsis.circle.fill",
            colorName: CategoryColor.gray.rawValue,
            sortOrder: (all.last?.sortOrder ?? -1) + 1,
            isDefault: true
        )
        context.insert(created)
        return created
    }

    static func insert(
        name: String,
        symbolName: String,
        colorName: String,
        in context: ModelContext
    ) {
        var ordered = fetchSorted(in: context)
        let category = ProductCategory(
            name: name,
            symbolName: symbolName,
            colorName: colorName,
            sortOrder: 0
        )
        context.insert(category)

        let index = ordered.firstIndex(where: { $0.isFallback }) ?? ordered.count
        ordered.insert(category, at: index)
        for (position, item) in ordered.enumerated() {
            item.sortOrder = position
        }
    }

    static func delete(_ category: ProductCategory, in context: ModelContext) {
        guard !category.isFallback else { return }

        let fallback = fallbackCategory(in: context)
        let items = category.items
        for item in items {
            item.category = fallback
            item.updatedAt = .now
        }
        context.delete(category)
    }

    private static func fetchSorted(in context: ModelContext) -> [ProductCategory] {
        let descriptor = FetchDescriptor<ProductCategory>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
