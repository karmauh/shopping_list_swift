import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ShoppingListsView()
        }
        .task {
            DefaultCategories.seedIfNeeded(in: modelContext)
        }
    }
}
