import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var categories: [ProductCategory]

    var body: some View {
        VStack(spacing: 12) {
            Text("Lista zakupów")
                .font(.largeTitle.bold())
            Text("Kategorie w bazie: \(categories.count)")
                .foregroundStyle(.secondary)
        }
        .task {
            DefaultCategories.seedIfNeeded(in: modelContext)
        }
    }
}
