import SwiftUI
import SwiftData

struct ShoppingListsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ShoppingList.createdAt, order: .reverse)
    private var lists: [ShoppingList]

    @State private var formMode: ListFormMode?

    var body: some View {
        List {
            ForEach(lists) { list in
                NavigationLink(value: list) {
                    ShoppingListRow(list: list)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        delete(list)
                    } label: {
                        Label("Usuń", systemImage: "trash")
                    }
                    Button {
                        formMode = .rename(list)
                    } label: {
                        Label("Zmień nazwę", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
                .contextMenu {
                    Button {
                        formMode = .rename(list)
                    } label: {
                        Label("Zmień nazwę", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        delete(list)
                    } label: {
                        Label("Usuń", systemImage: "trash")
                    }
                }
            }
        }
        .overlay {
            if lists.isEmpty {
                ContentUnavailableView(
                    "Brak list zakupów",
                    systemImage: "cart",
                    description: Text("Utwórz pierwszą listę przyciskiem plus.")
                )
            }
        }
        .navigationTitle("Listy zakupów")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    formMode = .add
                } label: {
                    Label("Nowa lista", systemImage: "plus")
                }
            }
        }
        .navigationDestination(for: ShoppingList.self) { list in
            ShoppingListDetailView(list: list)
        }
        .sheet(item: $formMode) { mode in
            ListFormView(mode: mode)
        }
    }

    private func delete(_ list: ShoppingList) {
        withAnimation {
            modelContext.delete(list)
        }
    }
}
