import SwiftUI
import SwiftData

struct JoinListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        SyncService.normalize(code) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("XXXXX-XXXXX", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            join()
                        }
                } header: {
                    Text("Kod listy")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else {
                        Text("Kod znajdziesz na drugim telefonie: menu listy, Kod synchronizacji.")
                    }
                }

                if isWorking {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Dołączanie do listy")
                        }
                    }
                }
            }
            .navigationTitle("Dołącz do listy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Dołącz") {
                        join()
                    }
                    .disabled(!isValid || isWorking)
                }
            }
        }
    }

    private func join() {
        guard isValid, !isWorking else { return }
        errorMessage = nil
        isWorking = true
        Task {
            do {
                try await SyncService.shared.join(code: code, in: modelContext)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}
