import SwiftUI
import SwiftData

struct ShoppingListsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ShoppingList.createdAt, order: .reverse)
    private var lists: [ShoppingList]

    @State private var formMode: ListFormMode?
    @State private var showsCategories = false
    @State private var showsSettings = false
    @State private var selectedList: ShoppingList?
    @State private var highlightedID: UUID?
    @State private var removingIDs: Set<UUID> = []
    @State private var openRowID: UUID?
    @State private var isAtTop = true

    private var visibleLists: [ShoppingList] {
        lists.filter { !removingIDs.contains($0.id) }
    }

    private var visibleIDs: [UUID] {
        visibleLists.map(\.id)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(visibleLists) { list in
                        card(for: list, proxy: proxy)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .animation(.smooth, value: visibleIDs)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top <= 1
            } action: { _, newValue in
                isAtTop = newValue
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
            ToolbarItemGroup(placement: .topBarLeading) {
                Button {
                    showsCategories = true
                } label: {
                    Label("Kategorie", systemImage: "tag")
                }
                Button {
                    showsSettings = true
                } label: {
                    Label("Ustawienia", systemImage: "gearshape")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    formMode = .add
                } label: {
                    Label("Nowa lista", systemImage: "plus")
                }
            }
        }
        .navigationDestination(item: $selectedList) { list in
            ShoppingListDetailView(list: list)
        }
        .navigationDestination(isPresented: $showsCategories) {
            CategoriesView()
        }
        .navigationDestination(isPresented: $showsSettings) {
            SettingsView()
        }
        .sheet(item: $formMode) { mode in
            ListFormView(mode: mode)
        }
        .onAppear {
            openRowID = nil
        }
    }

    private func card(for list: ShoppingList, proxy: ScrollViewProxy) -> some View {
        SwipeActionRow(
            rowID: list.id,
            openRowID: $openRowID,
            actions: [
                SwipeAction(title: "Duplikuj", systemImage: "doc.on.doc", tint: .blue) {
                    duplicate(list, using: proxy)
                },
                SwipeAction(title: "Zmień nazwę", systemImage: "pencil", tint: .orange) {
                    formMode = .rename(list)
                },
                SwipeAction(title: "Usuń", systemImage: "trash", tint: .red) {
                    delete(list)
                }
            ],
            onTap: {
                selectedList = list
            }
        ) {
            HStack(spacing: 8) {
                ShoppingListRow(list: list)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        highlightedID == list.id
                            ? Color.accentColor.opacity(0.22)
                            : Color(.secondarySystemGroupedBackground)
                    )
                    .animation(.easeOut(duration: 0.5), value: highlightedID)
            }
        }
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu {
            Button {
                formMode = .rename(list)
            } label: {
                Label("Zmień nazwę", systemImage: "pencil")
            }
            Button {
                duplicate(list, using: proxy)
            } label: {
                Label("Duplikuj", systemImage: "doc.on.doc")
            }
            Button(role: .destructive) {
                delete(list)
            } label: {
                Label("Usuń", systemImage: "trash")
            }
        }
        .id(list.id)
        .transition(
            .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity.combined(with: .scale(scale: 0.96))
            )
        )
        .accessibilityAddTraits(.isButton)
    }

    private func delete(_ list: ShoppingList) {
        let id = list.id
        withAnimation(.smooth) {
            _ = removingIDs.insert(id)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            if let target = lists.first(where: { $0.id == id }) {
                modelContext.delete(target)
            }
            removingIDs.remove(id)
        }
    }

    private func duplicate(_ list: ShoppingList, using proxy: ScrollViewProxy) {
        let sourceID = list.id

        Task {
            if isAtTop {
                try? await Task.sleep(for: .milliseconds(250))
            } else if let firstID = visibleLists.first?.id {
                withAnimation(.smooth) {
                    proxy.scrollTo(firstID, anchor: .top)
                }
                try? await Task.sleep(for: .milliseconds(450))
            }

            guard let source = lists.first(where: { $0.id == sourceID }) else { return }

            let copyID = ListService.duplicate(source, in: modelContext).id
            highlightedID = copyID

            try? await Task.sleep(for: .seconds(1.6))
            if highlightedID == copyID {
                highlightedID = nil
            }
        }
    }
}
