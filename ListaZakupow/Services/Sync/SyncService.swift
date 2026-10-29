import Foundation
import SwiftData
import FirebaseAuth
import FirebaseFirestore

enum SyncError: LocalizedError {
    case codeUnavailable
    case invalidCode
    case listNotFound
    case alreadyJoined

    var errorDescription: String? {
        switch self {
        case .codeUnavailable:
            return "Nie udało się wygenerować unikalnego kodu. Spróbuj ponownie."
        case .invalidCode:
            return "Kod ma nieprawidłowy format. Wpisz go w postaci XXXXX-XXXXX."
        case .listNotFound:
            return "Nie znaleziono listy o podanym kodzie."
        case .alreadyJoined:
            return "Ta lista jest już na tym telefonie."
        }
    }
}

private struct RemoteList: Sendable {
    let name: String
    let nameUpdatedAt: Date?
    let createdAt: Date?

    init?(data: [String: Any]) {
        guard let name = data["name"] as? String else { return nil }
        self.name = name
        self.nameUpdatedAt = (data["nameUpdatedAt"] as? Timestamp)?.dateValue()
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
    }
}

private struct RemoteItem: Sendable {
    let id: UUID
    let name: String
    let quantity: String
    let isPurchased: Bool
    let createdAt: Date
    let updatedAt: Date
    let purchasedAt: Date?
    let deletedAt: Date?
    let categoryName: String?
    let categorySymbol: String?
    let categoryColor: String?

    init?(id: String, data: [String: Any]) {
        guard
            let uuid = UUID(uuidString: id),
            let name = data["name"] as? String,
            let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        else {
            return nil
        }
        self.id = uuid
        self.name = name
        self.quantity = data["quantity"] as? String ?? ""
        self.isPurchased = data["isPurchased"] as? Bool ?? false
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? updatedAt
        self.updatedAt = updatedAt
        self.purchasedAt = (data["purchasedAt"] as? Timestamp)?.dateValue()
        self.deletedAt = (data["deletedAt"] as? Timestamp)?.dateValue()
        self.categoryName = data["categoryName"] as? String
        self.categorySymbol = data["categorySymbol"] as? String
        self.categoryColor = data["categoryColor"] as? String
    }
}

@MainActor
final class SyncService {
    static let shared = SyncService()

    private static let codeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    private static let timeTolerance: TimeInterval = 0.001

    private var database: Firestore {
        Firestore.firestore()
    }

    private var context: ModelContext?
    private var listeners: [String: [ListenerRegistration]] = [:]
    private var pushTask: Task<Void, Never>?
    private var pushRequested = false

    private init() {}

    static func normalize(_ text: String) -> String? {
        let cleaned = text.uppercased().filter { codeAlphabet.contains($0) }
        guard cleaned.count == 10 else { return nil }
        return String(cleaned.prefix(5)) + "-" + String(cleaned.suffix(5))
    }

    func start(in context: ModelContext) async {
        self.context = context
        do {
            try await ensureSignedIn()
        } catch {
            return
        }
        let lists = (try? context.fetch(FetchDescriptor<ShoppingList>())) ?? []
        for list in lists {
            if let code = list.shareCode {
                listen(to: code)
            }
        }
        await pushPending(in: context)
    }

    func stopListening(code: String) {
        listeners[code]?.forEach { $0.remove() }
        listeners[code] = nil
    }

    func startSharing(_ list: ShoppingList, in context: ModelContext) async throws -> String {
        if let existing = list.shareCode {
            return existing
        }
        self.context = context
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
        listen(to: code)
        await pushPending(in: context)
        return code
    }

    @discardableResult
    func join(code rawCode: String, in context: ModelContext) async throws -> ShoppingList {
        guard let code = Self.normalize(rawCode) else {
            throw SyncError.invalidCode
        }
        let existing = (try? context.fetch(FetchDescriptor<ShoppingList>())) ?? []
        if existing.contains(where: { $0.shareCode == code }) {
            throw SyncError.alreadyJoined
        }
        try await ensureSignedIn()

        let snapshot = try await database.collection("lists").document(code).getDocument(source: .server)
        guard
            snapshot.exists,
            let data = snapshot.data(),
            let remote = RemoteList(data: data)
        else {
            throw SyncError.listNotFound
        }

        self.context = context
        let list = ShoppingList(name: remote.name, createdAt: remote.createdAt ?? .now)
        list.shareCode = code
        list.nameUpdatedAt = remote.nameUpdatedAt ?? .now
        context.insert(list)
        try? context.save()
        listen(to: code)
        return list
    }

    func requestPush(in context: ModelContext) {
        self.context = context
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

    private func listen(to code: String) {
        guard listeners[code] == nil else { return }
        let reference = database.collection("lists").document(code)

        let listRegistration = reference.addSnapshotListener { [weak self] snapshot, _ in
            guard
                let data = snapshot?.data(),
                let remote = RemoteList(data: data)
            else {
                return
            }
            Task { @MainActor in
                self?.applyRemoteList(remote, code: code)
            }
        }

        let itemsRegistration = reference.collection("items").addSnapshotListener { [weak self] snapshot, _ in
            guard let snapshot else { return }
            let remoteItems = snapshot.documentChanges
                .filter { $0.type != .removed }
                .compactMap { RemoteItem(id: $0.document.documentID, data: $0.document.data()) }
            guard !remoteItems.isEmpty else { return }
            Task { @MainActor in
                self?.applyRemoteItems(remoteItems, code: code)
            }
        }

        listeners[code] = [listRegistration, itemsRegistration]
    }

    private func localList(code: String, in context: ModelContext) -> ShoppingList? {
        let lists = (try? context.fetch(FetchDescriptor<ShoppingList>())) ?? []
        return lists.first { $0.shareCode == code }
    }

    private func applyRemoteList(_ remote: RemoteList, code: String) {
        guard let context, let list = localList(code: code, in: context) else { return }
        guard let remoteDate = remote.nameUpdatedAt else { return }
        let localDate = list.nameUpdatedAt ?? .distantPast
        guard remoteDate.timeIntervalSince(localDate) > Self.timeTolerance else { return }
        list.name = remote.name
        list.nameUpdatedAt = remoteDate
        try? context.save()
    }

    private func applyRemoteItems(_ remoteItems: [RemoteItem], code: String) {
        guard let context, let list = localList(code: code, in: context) else { return }

        let allItems = (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []
        var itemsByID = Dictionary(
            allItems.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let categories = (try? context.fetch(FetchDescriptor<ProductCategory>())) ?? []
        var categoryCache = Dictionary(
            categories.map { ($0.name.comparisonKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for remote in remoteItems {
            if let local = itemsByID[remote.id] {
                guard local.list?.id == list.id else { continue }
                guard remote.updatedAt.timeIntervalSince(local.updatedAt) > Self.timeTolerance else { continue }
                local.name = remote.name
                local.quantity = remote.quantity
                local.isPurchased = remote.isPurchased
                local.purchasedAt = remote.purchasedAt
                local.deletedAt = remote.deletedAt
                local.category = resolveCategory(for: remote, in: context, cache: &categoryCache)
                local.updatedAt = remote.updatedAt
                local.syncedUpdatedAt = remote.updatedAt
            } else {
                guard remote.deletedAt == nil else { continue }
                let item = ShoppingItem(
                    id: remote.id,
                    name: remote.name,
                    quantity: remote.quantity,
                    isPurchased: remote.isPurchased,
                    purchasedAt: remote.purchasedAt,
                    createdAt: remote.createdAt,
                    updatedAt: remote.updatedAt
                )
                context.insert(item)
                item.list = list
                item.category = resolveCategory(for: remote, in: context, cache: &categoryCache)
                item.syncedUpdatedAt = remote.updatedAt
                itemsByID[remote.id] = item
            }
        }

        try? context.save()
    }

    private func resolveCategory(
        for remote: RemoteItem,
        in context: ModelContext,
        cache: inout [String: ProductCategory]
    ) -> ProductCategory? {
        guard let name = remote.categoryName else { return nil }
        let key = name.comparisonKey
        if let existing = cache[key] {
            return existing
        }
        let created = CategoryService.insert(
            name: name,
            symbolName: remote.categorySymbol ?? "tag.fill",
            colorName: remote.categoryColor ?? CategoryColor.gray.rawValue,
            in: context
        )
        cache[key] = created
        return created
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
