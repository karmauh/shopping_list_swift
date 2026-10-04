import SwiftUI
import SwiftData

struct ImportPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ImportCoordinator.self) private var coordinator

    let pending: ImportCoordinator.Pending

    private var summary: ImportSummary {
        pending.summary
    }

    private var introText: String {
        if summary.listIsNew {
            return "Lista „\(summary.listName)” nie istnieje jeszcze na tym urządzeniu."
        }
        return "Lista „\(summary.listName)” jest już na tym urządzeniu. Poniżej zmiany, które zostaną wprowadzone przy scalaniu."
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(introText)
                }
                nameSection("Nowe produkty", summary.addedItems)
                nameSection("Zmienione produkty", summary.updatedItems)
                nameSection("Usunięte produkty", summary.removedItems)
                nameSection("Nowe kategorie", summary.addedCategories)
            }
            .navigationTitle("Otrzymana lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") {
                        coordinator.cancel()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func nameSection(_ title: String, _ names: [String]) -> some View {
        if !names.isEmpty {
            Section("\(title) (\(names.count))") {
                ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                    Text(name)
                }
            }
        }
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            Button {
                coordinator.confirmMerge(context: modelContext)
            } label: {
                Text(summary.listIsNew ? "Dodaj listę" : "Scal ze swoją listą")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)

            Button {
                coordinator.confirmAsNew(context: modelContext)
            } label: {
                Text("Zapisz jako nową listę")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.regularMaterial)
    }
}
