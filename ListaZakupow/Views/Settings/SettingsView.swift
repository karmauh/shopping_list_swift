import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ImportCoordinator.self) private var coordinator

    @AppStorage(AppSettings.mergeWithoutAskingKey)
    private var mergeWithoutAsking = false

    @State private var showsImporter = false

    var body: some View {
        List {
            Section {
                Toggle("Scalaj bez pytania", isOn: $mergeWithoutAsking)
            } header: {
                Text("Odbieranie list")
            } footer: {
                Text("Gdy opcja jest włączona, otrzymana lista jest od razu scalana z Twoją, a po zakończeniu zobaczysz podsumowanie. Gdy jest wyłączona, przed scaleniem zobaczysz podgląd zmian i możesz zapisać listę jako nową.")
            }

            Section {
                Button {
                    showsImporter = true
                } label: {
                    Label("Importuj listę z pliku", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Import")
            } footer: {
                Text("Plik otrzymany przez AirDrop, Wiadomości lub Pocztę możesz też otworzyć dotknięciem: aplikacja sama zaproponuje scalenie.")
            }
        }
        .navigationTitle("Ustawienia")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.shoppingList, .json]
        ) { result in
            switch result {
            case .success(let url):
                coordinator.handle(url: url, context: modelContext)
            case .failure(let error):
                coordinator.errorMessage = error.localizedDescription
            }
        }
    }
}
