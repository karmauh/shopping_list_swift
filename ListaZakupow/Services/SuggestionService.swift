import Foundation

struct Suggestion: Identifiable {
    let name: String
    let categoryID: UUID?

    var id: String { name.comparisonKey }
}

enum SuggestionService {
    private struct Entry {
        var name: String
        var count: Int
        var lastUsed: Date
        var categoryID: UUID?
        var categoryDate: Date
    }

    static func suggestions(
        typed: String,
        history: [ShoppingItem],
        excludingKeys: Set<String>,
        limit: Int = 5
    ) -> [Suggestion] {
        let typedKey = typed.comparisonKey
        var entries: [String: Entry] = [:]

        for item in history {
            let key = item.name.comparisonKey
            guard !key.isEmpty, !excludingKeys.contains(key), key != typedKey else { continue }

            var entry = entries[key] ?? Entry(
                name: item.name,
                count: 0,
                lastUsed: .distantPast,
                categoryID: nil,
                categoryDate: .distantPast
            )

            entry.count += 1
            if item.createdAt > entry.lastUsed {
                entry.lastUsed = item.createdAt
                entry.name = item.name
            }
            if let categoryID = item.category?.id, item.updatedAt >= entry.categoryDate {
                entry.categoryID = categoryID
                entry.categoryDate = item.updatedAt
            }
            entries[key] = entry
        }

        let matching = entries.filter { typedKey.isEmpty || $0.key.contains(typedKey) }

        let sorted = matching.sorted { lhs, rhs in
            let lhsPrefix = lhs.key.hasPrefix(typedKey)
            let rhsPrefix = rhs.key.hasPrefix(typedKey)
            if lhsPrefix != rhsPrefix {
                return lhsPrefix
            }
            if lhs.value.count != rhs.value.count {
                return lhs.value.count > rhs.value.count
            }
            if lhs.value.lastUsed != rhs.value.lastUsed {
                return lhs.value.lastUsed > rhs.value.lastUsed
            }
            return lhs.key < rhs.key
        }

        return sorted.prefix(limit).map {
            Suggestion(name: $0.value.name, categoryID: $0.value.categoryID)
        }
    }
}
