import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore

enum SyncError: LocalizedError {
    case codeUnavailable

    var errorDescription: String? {
        switch self {
        case .codeUnavailable:
            return "Nie udało się wygenerować unikalnego kodu. Spróbuj ponownie."
        }
    }
}

@MainActor
final class SyncService {
    static let shared = SyncService()

    private static let codeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    private var database: Firestore {
        Firestore.firestore()
    }

    private var pushTask: Task<Void, Never>?
    private var pushRequested = false

    private init() {}

    func startSharing(_ list: ShoppingList, in context: ModelContext) async throws -> String {
        if let existing = list.shareCode {
            return existing
        }
        try await ensureSignedIn()

        var code = Self.makeCode()
        var attempts = 0
        while try await database.collection("lists").document(code).getDocument().exists {
            attempts += 1
            if attempts >= 5 {
                throw SyncError.codeUnavailable
            }
            code = Self.makeCode()
        }

        if list.nameUpdatedAt == nil {
            list.nameUpdatedAt = .now
        }
        try await database.collection("lists").document(code).setData([
            "name": list.name,
            "nameUpdatedAt": Timestamp(date: list.nameUpdatedAt ?? .now),
            "createdAt": Timestamp(date: list.createdAt)
        ])

        list.shareCode = code
        await pushPending(in: context)
        return code
    }

    func requestPush(in context: ModelContext) {
        pushRequested = true
        guard pushTask == nil else { return }
        pushTask = Task { [self] in
            while pushRequested {
                pushRequested = false
                try? await Task.sleep(for: .milliseconds(800))
                await pushPending(in: context)
            }
            pushTask = nil
        }
    }

    func pushListName(of list: ShoppingList) async {
        guard let code = list.shareCode else { return }
        do {
            try await ensureSignedIn()
            try await database.collection("lists").document(code).setData([
                "name": list.name,
                "nameUpdatedAt": Timestamp(date: list.nameUpdatedAt ?? .now)
            ], merge: true)
        } catch {
            return
        }
    }

    func pushPending(in context: ModelContext) async {
        do {
            try await ensureSignedIn()
        } catch {
            return
        }
        let descriptor = FetchDescriptor<ShoppingList>(
            predicate: #Predicate { $0.shareCode != nil }
        )
        let lists = (try? context.fetch(descriptor)) ?? []
        for list in lists {
            guard let code = list.shareCode else { continue }
            let pending = list.items.filter { $0.needsSync }
            if pending.isEmpty { continue }
            await push(pending, toList: code)
        }
    }

    private func push(_ items: [ShoppingItem], toList code: String) async {
        let collection = database.collection("lists").document(code).collection("items")
        var start = 0
        while start < items.count {
            let end = min(start + 400, items.count)
            let chunk = Array(items[start..<end])
            start = end

            let batch = database.batch()
            var versions: [(ShoppingItem, Date)] = []
            for item in chunk {
                batch.setData(fields(for: item), forDocument: collection.document(item.id.uuidString))
                versions.append((item, item.updatedAt))
            }
            do {
                try await batch.commit()
                for (item, version) in versions {
                    item.syncedUpdatedAt = version
                }
            } catch {
                continue
            }
        }
    }

    private func ensureSignedIn() async throws {
        if Auth.auth().currentUser == nil {
            _ = try await Auth.auth().signInAnonymously()
        }
    }

    private func fields(for item: ShoppingItem) -> [String: Any] {
        [
            "name": item.name,
            "quantity": item.quantity,
            "isPurchased": item.isPurchased,
            "createdAt": Timestamp(date: item.createdAt),
            "updatedAt": Timestamp(date: item.updatedAt),
            "purchasedAt": optionalValue(item.purchasedAt),
            "deletedAt": optionalValue(item.deletedAt),
            "categoryName": optionalValue(item.category?.name),
            "categorySymbol": optionalValue(item.category?.symbolName),
            "categoryColor": optionalValue(item.category?.colorName)
        ]
    }

    private func optionalValue(_ date: Date?) -> Any {
        if let date {
            return Timestamp(date: date)
        }
        return NSNull()
    }

    private func optionalValue(_ text: String?) -> Any {
        if let text {
            return text
        }
        return NSNull()
    }

    private static func makeCode() -> String {
        let characters = (0..<10).map { _ in
            codeAlphabet.randomElement() ?? "A"
        }
        return String(characters.prefix(5)) + "-" + String(characters.suffix(5))
    }
}
