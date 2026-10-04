import Foundation

enum SuggestionService {
    private struct Entry {
        var name: String
        var count: Int
        var lastUsed: Date
    }

    static func suggestions(
        typed: String,
        history: [ShoppingItem],
        excludingKeys: Set<String>,
        limit: Int = 5
    ) -> [String] {
        let typedKey = typed.comparisonKey
        var entries: [String: Entry] = [:]

        for item in history {
            let key = item.name.comparisonKey
            guard !key.isEmpty, !excludingKeys.contains(key), key != typedKey else { continue }

            if var entry = entries[key] {
                entry.count += 1
                if item.createdAt > entry.lastUsed {
                    entry.lastUsed = item.createdAt
                    entry.name = item.name
                }
                entries[key] = entry
            } else {
                entries[key] = Entry(name: item.name, count: 1, lastUsed: item.createdAt)
            }
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

        return sorted.prefix(limit).map { $0.value.name }
    }
}
