import SwiftUI
import SwiftData

@main
struct ListaZakupowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ShoppingList.self, ShoppingItem.self, ProductCategory.self])
    }
}
