import Foundation
import SwiftData

enum DefaultCategories {
    struct Definition {
        let name: String
        let symbolName: String
        let color: CategoryColor
    }

    static let definitions: [Definition] = [
        Definition(name: "Warzywa", symbolName: "leaf.fill", color: .green),
        Definition(name: "Owoce", symbolName: "basket.fill", color: .red),
        Definition(name: "Pieczywo", symbolName: "oven.fill", color: .brown),
        Definition(name: "Nabiał", symbolName: "drop.fill", color: .blue),
        Definition(name: "Mięso i ryby", symbolName: "flame.fill", color: .orange),
        Definition(name: "Napoje", symbolName: "cup.and.saucer.fill", color: .teal),
        Definition(name: "Słodycze i przekąski", symbolName: "birthday.cake.fill", color: .pink),
        Definition(name: "Mrożonki", symbolName: "snowflake", color: .indigo),
        Definition(name: "Chemia domowa", symbolName: "sparkles", color: .purple),
        Definition(name: "Inne", symbolName: "ellipsis.circle.fill", color: .gray)
    ]

    private static let seedFlagKey = "didSeedDefaultCategories"

    static func seedIfNeeded(in context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seedFlagKey) else { return }

        let existing = (try? context.fetchCount(FetchDescriptor<ProductCategory>())) ?? 0
        if existing == 0 {
            for (index, definition) in definitions.enumerated() {
                let category = ProductCategory(
                    name: definition.name,
                    symbolName: definition.symbolName,
                    colorName: definition.color.rawValue,
                    sortOrder: index,
                    isDefault: true
                )
                context.insert(category)
            }
            try? context.save()
        }

        UserDefaults.standard.set(true, forKey: seedFlagKey)
    }
}
