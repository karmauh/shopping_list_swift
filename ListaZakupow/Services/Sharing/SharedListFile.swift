import Foundation
import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    nonisolated static let shoppingList = UTType(exportedAs: "pl.mikolajbozko.listazakupow.list")
}

nonisolated struct SharedListFile: Codable, Sendable {
    static let currentVersion = 1

    let version: Int
    let exportedAt: Date
    let list: SharedList
}

nonisolated struct SharedList: Codable, Sendable {
    let id: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let items: [SharedItem]
}

nonisolated struct SharedItem: Codable, Sendable {
    let id: UUID
    let name: String
    let quantity: String
    let isPurchased: Bool
    let purchasedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let category: SharedCategory?
}

nonisolated struct SharedCategory: Codable, Sendable {
    let name: String
    let symbolName: String
    let colorName: String
}

nonisolated struct SharedListDocument: Transferable, Sendable {
    let file: SharedListFile

    var listName: String {
        file.list.name
    }

    var fileName: String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = file.list.name
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = cleaned.isEmpty ? "Lista" : cleaned
        return "\(base).listazakupow"
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .shoppingList) { document in
            SentTransferredFile(try document.writeTemporaryFile())
        }
    }

    func writeTemporaryFile() throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }
}
