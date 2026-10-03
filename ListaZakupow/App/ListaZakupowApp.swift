import SwiftUI
import SwiftData

@main
struct ListaZakupowApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ShoppingList.self, ShoppingItem.self, ProductCategory.self])
    }
}
