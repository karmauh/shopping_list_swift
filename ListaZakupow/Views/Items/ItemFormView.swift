import SwiftUI
import SwiftData

enum ItemFormMode: Identifiable {
    case add
    case edit(ShoppingItem)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let item):
            return item.id.uuidString
        }
    }

    var existingItem: ShoppingItem? {
        if case .edit(let item) = self {
            return item
        }
        return nil
    }
}

struct ItemFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ProductCategory.sortOrder)
    private var categories: [ProductCategory]

    let list: ShoppingList
    private let item: ShoppingItem?

    @State private var name: String
    @State private var quantity: String
    @State private var categoryID: UUID?
    @FocusState private var isNameFocused: Bool

    init(list: ShoppingList, mode: ItemFormMode) {
        self.list = list
        let existing = mode.existingItem
        item = existing
        _name = State(initialValue: existing?.name ?? "")
        _quantity = State(initialValue: existing?.quantity ?? "")
        _categoryID = State(initialValue: existing?.category?.id)
    }

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var cleanQuantity: String {
        quantity.trimmingCharacters(in: .whitespaces)
    }

    private var duplicate: ShoppingItem? {
        list.activeItem(named: cleanName, excluding: item)
    }

    private var isValid: Bool {
        !cleanName.isEmpty && duplicate == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nazwa produktu", text: $name)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                    TextField("Ilość (np. 2 szt., 1 kg)", text: $quantity)
                } header: {
                    Text("Produkt")
                } footer: {
                    duplicateFooter
                }

                if let duplicate, duplicate.isPurchased, item == nil {
                    Section {
                        Button("Przywróć „\(duplicate.name)” na listę") {
                            restore(duplicate)
                        }
                    }
                }

                Section("Kategoria") {
                    Picker("Kategoria", selection: $categoryID) {
                        Text("Bez kategorii")
                            .tag(UUID?.none)
                        ForEach(categories) { category in
                            Label {
                                Text(category.name)
                            } icon: {
                                Image(systemName: category.symbolName)
                                    .foregroundStyle(category.categoryColor.color)
                            }
                            .tag(Optional(category.id))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                if item == nil {
                    Section {
                        Button("Zapisz i dodaj kolejny") {
                            persist()
                            name = ""
                            quantity = ""
                            isNameFocused = true
                        }
                        .disabled(!isValid)
                    }
                }
            }
            .navigationTitle(item == nil ? "Nowy produkt" : "Edycja produktu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        persist()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .task {
                if item == nil {
                    if categoryID == nil {
                        categoryID = categories.first(where: { $0.name == "Inne" })?.id
                            ?? categories.first?.id
                    }
                    isNameFocused = true
                }
            }
        }
    }

    @ViewBuilder
    private var duplicateFooter: some View {
        if let duplicate {
            Text(
                duplicate.isPurchased
                    ? "Ten produkt jest już na liście jako kupiony."
                    : "Ten produkt już jest na liście."
            )
            .foregroundStyle(.red)
        }
    }

    private func restore(_ existing: ShoppingItem) {
        existing.setPurchased(false)
        dismiss()
    }

    private func persist() {
        let category = categories.first { $0.id == categoryID }

        if let item {
            item.name = cleanName
            item.quantity = cleanQuantity
            item.category = category
            item.updatedAt = .now
        } else {
            let newItem = ShoppingItem(name: cleanName, quantity: cleanQuantity)
            modelContext.insert(newItem)
            newItem.list = list
            newItem.category = category
        }
        list.updatedAt = .now
    }
}
