import SwiftUI
import SwiftData

struct ShoppingListDetailView: View {
    let list: ShoppingList

    @Query(sort: \ProductCategory.sortOrder)
    private var categories: [ProductCategory]

    @State private var formMode: ItemFormMode?
    @State private var showsClearConfirmation = false

    private var sections: [ItemSection] {
        ItemSection.build(from: list.activeItems, categories: categories)
    }

    var body: some View {
        List {
            if list.totalCount > 0 {
                Section {
                    progressView
                }
            }

            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        ItemRow(
                            item: item,
                            onToggle: {
                                withAnimation {
                                    item.setPurchased(!item.isPurchased)
                                }
                            },
                            onEdit: {
                                formMode = .edit(item)
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    item.markDeleted()
                                }
                            } label: {
                                Label("Usuń", systemImage: "trash")
                            }
                            Button {
                                formMode = .edit(item)
                            } label: {
                                Label("Edytuj", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                } header: {
                    header(for: section)
                }
            }
        }
        .overlay {
            if list.totalCount == 0 {
                ContentUnavailableView {
                    Label("Lista jest pusta", systemImage: "cart")
                } description: {
                    Text("Dodaj pierwszy produkt przyciskiem plus.")
                } actions: {
                    Button("Dodaj produkt") {
                        formMode = .add
                    }
                }
            }
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    formMode = .add
                } label: {
                    Label("Dodaj produkt", systemImage: "plus")
                }
                Menu {
                    Button("Odznacz wszystkie kupione", systemImage: "arrow.uturn.backward.circle") {
                        withAnimation {
                            for item in list.activeItems where item.isPurchased {
                                item.setPurchased(false)
                            }
                        }
                    }
                    .disabled(list.purchasedCount == 0)

                    Button("Usuń kupione", systemImage: "trash", role: .destructive) {
                        showsClearConfirmation = true
                    }
                    .disabled(list.purchasedCount == 0)
                } label: {
                    Label("Menu", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $formMode) { mode in
            ItemFormView(list: list, mode: mode)
        }
        .confirmationDialog(
            "Usunąć kupione produkty?",
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Usuń kupione (\(list.purchasedCount))", role: .destructive) {
                withAnimation {
                    for item in list.activeItems where item.isPurchased {
                        item.markDeleted()
                    }
                }
            }
        } message: {
            Text("Kupione produkty zostaną usunięte z listy.")
        }
    }

    private var progressView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kupione: \(list.purchasedCount) z \(list.totalCount)")
                .font(.subheadline.bold())
            ProgressView(
                value: Double(list.purchasedCount),
                total: Double(max(list.totalCount, 1))
            )
            .tint(.green)
        }
        .padding(.vertical, 4)
    }

    private func header(for section: ItemSection) -> some View {
        HStack(spacing: 8) {
            Image(systemName: section.symbolName)
                .foregroundStyle(section.color)
            Text(section.title)
            Spacer()
            Text("\(section.items.count)")
                .foregroundStyle(.secondary)
        }
        .font(.headline)
        .foregroundStyle(.primary)
        .textCase(nil)
    }
}
