import Foundation
import SwiftData

struct ImportSummary {
    var listName: String
    var listIsNew: Bool
    var addedItems: [String] = []
    var updatedItems: [String] = []
    var removedItems: [String] = []
    var addedCategories: [String] = []

    var hasChanges: Bool {
        listIsNew || !addedItems.isEmpty || !updatedItems.isEmpty || !removedItems.isEmpty
    }

    var message: String {
        guard hasChanges else {
            return "Lista „\(listName)” jest już aktualna: nie ma nowych zmian."
        }

        var details: [String] = []
        if !addedItems.isEmpty {
            details.append("nowe produkty: \(addedItems.count)")
        }
        if !updatedItems.isEmpty {
            details.append("zmienione: \(updatedItems.count)")
        }
        if !removedItems.isEmpty {
            details.append("usunięte: \(removedItems.count)")
        }
        if !addedCategories.isEmpty {
            details.append("nowe kategorie: \(addedCategories.count)")
        }

        let prefix = listIsNew ? "Dodano listę „\(listName)”" : "Zaktualizowano listę „\(listName)”"
        if details.isEmpty {
            return "\(prefix)."
        }
        return "\(prefix) (\(details.joined(separator: ", ")))."
    }
}

enum ImportError: LocalizedError {
    case unreadable
    case invalidFormat
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "Nie można odczytać wybranego pliku."
        case .invalidFormat:
            return "Plik ma nieprawidłowy format lub nie pochodzi z tej aplikacji."
        case .unsupportedVersion(let version):
            return "Plik pochodzi z nowszej wersji aplikacji (wersja formatu: \(version))."
        }
    }
}

@MainActor
private struct Merger {
    let context: ModelContext
    let commit: Bool
    var summary: ImportSummary
    var categoryCache: [String: ProductCategory]
    var itemsByID: [UUID: ShoppingItem]

    private static let newerThreshold: TimeInterval = 1

    init(context: ModelContext, commit: Bool, listName: String, listIsNew: Bool) throws {
        self.context = context
        self.commit = commit
        self.summary = ImportSummary(listName: listName, listIsNew: listIsNew)

        let categories = try context.fetch(FetchDescriptor<ProductCategory>())
        self.categoryCache = Dictionary(
            categories.map { ($0.name.comparisonKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let items = try context.fetch(FetchDescriptor<ShoppingItem>())
        self.itemsByID = Dictionary(
            items.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    mutating func resolveCategory(_ shared: SharedCategory?) -> ProductCategory? {
        guard let shared else { return nil }
        let key = shared.name.comparisonKey

        if let existing = categoryCache[key] {
            return existing
        }

        if !summary.addedCategories.contains(shared.name) {
            summary.addedCategories.append(shared.name)
        }

        guard commit else { return nil }

        let created = CategoryService.insert(
            name: shared.name,
            symbolName: shared.symbolName,
            colorName: shared.colorName,
            in: context
        )
        categoryCache[key] = created
        return created
    }

    mutating func createItem(
        from shared: SharedItem,
        in list: ShoppingList,
        category: ProductCategory?,
        keepID: Bool
    ) {
        let id = (keepID && itemsByID[shared.id] == nil) ? shared.id : UUID()
        let item = ShoppingItem(
            id: id,
            name: shared.name,
            quantity: shared.quantity,
            isPurchased: shared.isPurchased,
            purchasedAt: shared.purchasedAt,
            createdAt: shared.createdAt,
            updatedAt: shared.updatedAt
        )
        context.insert(item)
        item.list = list
        item.category = category
        itemsByID[id] = item
    }

    mutating func mergeItems(_ sharedItems: [SharedItem], into list: ShoppingList) {
        for shared in sharedItems {
            var match: ShoppingItem?
            if let byID = itemsByID[shared.id], byID.list?.id == list.id {
                match = byID
            } else if shared.deletedAt == nil {
                match = list.activeItem(named: shared.name)
            }

            guard let local = match else {
                if shared.deletedAt == nil {
                    summary.addedItems.append(shared.name)
                    let category = resolveCategory(shared.category)
                    if commit {
                        createItem(from: shared, in: list, category: category, keepID: true)
                    }
                }
                continue
            }

            if commit, local.id != shared.id, itemsByID[shared.id] == nil {
                itemsByID[local.id] = nil
                local.id = shared.id
                itemsByID[shared.id] = local
            }

            guard shared.updatedAt.timeIntervalSince(local.updatedAt) > Self.newerThreshold else {
                continue
            }

            let sharedActive = shared.deletedAt == nil
            let localActive = local.deletedAt == nil

            if sharedActive, !localActive,
               list.activeItem(named: shared.name, excluding: local) != nil {
                continue
            }

            let sameName = shared.name.comparisonKey == local.name.comparisonKey
            let renameAllowed = sameName
                || list.activeItem(named: shared.name, excluding: local) == nil
            let newName = renameAllowed ? shared.name : local.name
            let categoryChanged = shared.category?.name.comparisonKey != local.category?.name.comparisonKey

            let changed = newName != local.name
                || shared.quantity != local.quantity
                || shared.isPurchased != local.isPurchased
                || sharedActive != localActive
                || categoryChanged

            guard changed else { continue }

            if !sharedActive && localActive {
                summary.removedItems.append(local.name)
            } else if sharedActive && !localActive {
                summary.addedItems.append(shared.name)
            } else {
                summary.updatedItems.append(newName)
            }

            let category = resolveCategory(shared.category)
            if commit {
                local.name = newName
                local.quantity = shared.quantity
                local.isPurchased = shared.isPurchased
                local.purchasedAt = shared.purchasedAt
                local.deletedAt = shared.deletedAt
                local.category = category
                local.updatedAt = shared.updatedAt
            }
        }
    }
}

@MainActor
enum ListImporter {
    static func load(from url: URL) throws -> SharedListFile {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.unreadable
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file: SharedListFile
        do {
            file = try decoder.decode(SharedListFile.self, from: data)
        } catch {
            throw ImportError.invalidFormat
        }

        guard file.version <= SharedListFile.currentVersion else {
            throw ImportError.unsupportedVersion(file.version)
        }
        return file
    }

    static func preview(_ file: SharedListFile, in context: ModelContext) throws -> ImportSummary {
        try run(file, in: context, commit: false)
    }

    static func merge(_ file: SharedListFile, in context: ModelContext) throws -> ImportSummary {
        let summary = try run(file, in: context, commit: true)
        try context.save()
        return summary
    }

    static func importAsNew(_ file: SharedListFile, in context: ModelContext) throws -> ImportSummary {
        let lists = try context.fetch(FetchDescriptor<ShoppingList>())
        let existingKeys = Set(lists.map { $0.name.comparisonKey })
        let name = uniqueName(file.list.name, existingKeys: existingKeys)

        var merger = try Merger(context: context, commit: true, listName: name, listIsNew: true)

        let list = ShoppingList(name: name)
        context.insert(list)

        for shared in file.list.items where shared.deletedAt == nil {
            merger.summary.addedItems.append(shared.name)
            let category = merger.resolveCategory(shared.category)
            merger.createItem(from: shared, in: list, category: category, keepID: false)
        }

        try context.save()
        return merger.summary
    }

    private static func run(
        _ file: SharedListFile,
        in context: ModelContext,
        commit: Bool
    ) throws -> ImportSummary {
        let lists = try context.fetch(FetchDescriptor<ShoppingList>())
        let existing = lists.first { $0.id == file.list.id }

        var merger = try Merger(
            context: context,
            commit: commit,
            listName: file.list.name,
            listIsNew: existing == nil
        )

        if let existing {
            merger.mergeItems(file.list.items, into: existing)
            if commit && merger.summary.hasChanges {
                existing.updatedAt = .now
            }
        } else {
            var newList: ShoppingList?
            if commit {
                let created = ShoppingList(
                    id: file.list.id,
                    name: file.list.name,
                    createdAt: .now,
                    updatedAt: file.list.updatedAt
                )
                context.insert(created)
                newList = created
            }

            for shared in file.list.items where shared.deletedAt == nil {
                merger.summary.addedItems.append(shared.name)
                let category = merger.resolveCategory(shared.category)
                if let newList {
                    merger.createItem(from: shared, in: newList, category: category, keepID: true)
                }
            }
        }

        return merger.summary
    }

    private static func uniqueName(_ base: String, existingKeys: Set<String>) -> String {
        if !existingKeys.contains(base.comparisonKey) {
            return base
        }
        let imported = "\(base) (import)"
        if !existingKeys.contains(imported.comparisonKey) {
            return imported
        }
        var number = 2
        while existingKeys.contains("\(imported) \(number)".comparisonKey) {
            number += 1
        }
        return "\(imported) \(number)"
    }
}
