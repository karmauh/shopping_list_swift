import SwiftUI
import SwiftData

struct ShoppingListsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ShoppingList.createdAt, order: .reverse)
    private var lists: [ShoppingList]

    @State private var formMode: ListFormMode?
    @State private var listToDelete: ShoppingList?

    private var showsDeleteConfirmation: Binding<Bool> {
        Binding(
            get: { listToDelete != nil },
            set: { isPresented in
                if !isPresented {
                    listToDelete = nil
                }
            }
        )
    }

    var body: some View {
        List {
            ForEach(lists) { list in
                NavigationLink(value: list) {
                    ShoppingListRow(list: list)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        listToDelete = list
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
                        listToDelete = list
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
        .confirmationDialog(
            "Usunąć listę?",
            isPresented: showsDeleteConfirmation,
            titleVisibility: .visible,
            presenting: listToDelete
        ) { list in
            Button("Usuń listę i jej produkty", role: .destructive) {
                modelContext.delete(list)
            }
        } message: { list in
            Text("Lista \(list.name) zostanie usunięta razem ze wszystkimi produktami (liczba produktów: \(list.totalCount)).")
        }
    }
}
