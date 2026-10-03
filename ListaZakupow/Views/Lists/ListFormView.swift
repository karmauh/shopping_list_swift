import SwiftUI
import SwiftData

enum ListFormMode: Identifiable {
    case add
    case rename(ShoppingList)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .rename(let list):
            return list.id.uuidString
        }
    }

    var existingList: ShoppingList? {
        if case .rename(let list) = self {
            return list
        }
        return nil
    }
}

struct ListFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let list: ShoppingList?

    @State private var name: String

    init(mode: ListFormMode) {
        let existing = mode.existingList
        list = existing
        _name = State(initialValue: existing?.name ?? "")
    }

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nazwa listy") {
                    TextField("np. Zakupy tygodniowe", text: $name)
                        .submitLabel(.done)
                        .onSubmit {
                            if !cleanName.isEmpty {
                                save()
                            }
                        }
                }
            }
            .navigationTitle(list == nil ? "Nowa lista" : "Zmiana nazwy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        save()
                    }
                    .disabled(cleanName.isEmpty)
                }
            }
        }
    }

    private func save() {
        if let list {
            list.name = cleanName
            list.updatedAt = .now
        } else {
            modelContext.insert(ShoppingList(name: cleanName))
        }
        dismiss()
    }
}
