import SwiftUI
import SwiftData

struct ShoppingListDetailView: View {
    let list: ShoppingList

    @Query private var categories: [ProductCategory]

    var body: some View {
        List {
            Section("Informacje o liście") {
                LabeledContent("Nazwa", value: list.name)
                LabeledContent("Produkty", value: "\(list.totalCount)")
            }

            Section("Baza danych") {
                LabeledContent("Kategorie w bazie", value: "\(categories.count)")
            }

            Section("Produkty") {
                Text("Dodawanie produktów pojawi się w następnej części.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
