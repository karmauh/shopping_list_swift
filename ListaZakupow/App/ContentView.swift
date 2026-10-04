import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var coordinator = ImportCoordinator()

    private var pendingBinding: Binding<ImportCoordinator.Pending?> {
        Binding(
            get: { coordinator.pending },
            set: { coordinator.pending = $0 }
        )
    }

    private var resultBinding: Binding<Bool> {
        Binding(
            get: { coordinator.resultMessage != nil },
            set: { isPresented in
                if !isPresented {
                    coordinator.resultMessage = nil
                }
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { coordinator.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    coordinator.errorMessage = nil
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            ShoppingListsView()
        }
        .environment(coordinator)
        .task {
            DefaultCategories.seedIfNeeded(in: modelContext)
        }
        .onOpenURL { url in
            coordinator.handle(url: url, context: modelContext)
        }
        .sheet(item: pendingBinding) { pending in
            ImportPreviewView(pending: pending)
                .environment(coordinator)
        }
        .alert("Import", isPresented: resultBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(coordinator.resultMessage ?? "")
        }
        .alert("Nie udało się zaimportować", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(coordinator.errorMessage ?? "")
        }
    }
}
