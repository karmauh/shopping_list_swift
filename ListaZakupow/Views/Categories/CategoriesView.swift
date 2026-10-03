import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ProductCategory.sortOrder)
    private var categories: [ProductCategory]

    @State private var formMode: CategoryFormMode?
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            Section {
                ForEach(categories) { category in
                    CategoryRow(category: category)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !category.isFallback {
                                formMode = .edit(category)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if !category.isFallback {
                                Button(role: .destructive) {
                                    delete(category)
                                } label: {
                                    Label("Usuń", systemImage: "trash")
                                }
                                Button {
                                    formMode = .edit(category)
                                } label: {
                                    Label("Edytuj", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                }
                .onMove(perform: move)
            } footer: {
                Text("Kategoria „Inne” jest systemowa: przejmuje produkty usuniętych kategorii i nie można jej edytować ani usunąć. Aby zmienić kolejność kategorii, dotknij Edytuj i przeciągnij wiersze.")
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("Kategorie")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(editMode.isEditing ? "Gotowe" : "Edytuj") {
                    withAnimation {
                        editMode = editMode.isEditing ? .inactive : .active
                    }
                }
                Button {
                    formMode = .add
                } label: {
                    Label("Nowa kategoria", systemImage: "plus")
                }
            }
        }
        .sheet(item: $formMode) { mode in
            CategoryFormView(mode: mode)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)
        for (position, category) in reordered.enumerated() {
            category.sortOrder = position
        }
    }

    private func delete(_ category: ProductCategory) {
        withAnimation {
            CategoryService.delete(category, in: modelContext)
        }
    }
}

struct CategoryRow: View {
    let category: ProductCategory

    private var itemCount: Int {
        category.items.filter { $0.deletedAt == nil }.count
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbolName)
                .foregroundStyle(category.categoryColor.color)
                .frame(width: 28)
            Text(category.name)
            Spacer()
            if category.isFallback {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(itemCount)")
                .foregroundStyle(.secondary)
        }
    }
}
