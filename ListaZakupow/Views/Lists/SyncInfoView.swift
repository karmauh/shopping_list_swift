import SwiftUI
import SwiftData
import UIKit

struct SyncInfoView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let list: ShoppingList

    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showsStopConfirmation = false
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Form {
                if let code = list.shareCode {
                    Section {
                        Text(code)
                            .font(.system(.title2, design: .monospaced).bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .textSelection(.enabled)
                        Button {
                            copy(code)
                        } label: {
                            Label(
                                copied ? "Skopiowano" : "Kopiuj kod",
                                systemImage: copied ? "checkmark" : "doc.on.doc"
                            )
                        }
                        ShareLink(item: message(for: code)) {
                            Label("Wyślij kod", systemImage: "square.and.arrow.up")
                        }
                    } header: {
                        Text("Kod listy")
                    } footer: {
                        Text("Druga osoba wpisuje ten kod w aplikacji: ikona dołączania na ekranie list.")
                    }

                    Section {
                        Button("Przestań synchronizować", role: .destructive) {
                            showsStopConfirmation = true
                        }
                    } footer: {
                        Text("Lista zostaje na tym telefonie, ale przestaje wymieniać zmiany. Dane w chmurze i na drugim telefonie nie są usuwane.")
                    }
                } else {
                    Section {
                        Button {
                            enable()
                        } label: {
                            HStack(spacing: 12) {
                                Text("Włącz synchronizację")
                                if isWorking {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isWorking)
                    } footer: {
                        Text("Lista i jej produkty zostaną wysłane do chmury. Dostęp ma każdy, kto zna kod listy.")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Synchronizacja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Przestać synchronizować tę listę?",
                isPresented: $showsStopConfirmation,
                titleVisibility: .visible
            ) {
                Button("Przestań synchronizować", role: .destructive) {
                    SyncService.shared.stopSharing(list, in: modelContext)
                }
            } message: {
                Text("Zmiany na tej liście nie będą już wysyłane ani odbierane.")
            }
        }
    }

    private func message(for code: String) -> String {
        "Dołącz do mojej listy „\(list.name)” w aplikacji Lista Zakupów. Kod listy: \(code)"
    }

    private func copy(_ code: String) {
        UIPasteboard.general.string = code
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }

    private func enable() {
        errorMessage = nil
        isWorking = true
        Task {
            do {
                _ = try await SyncService.shared.startSharing(list, in: modelContext)
            } catch {
                errorMessage = "Nie udało się włączyć synchronizacji: \(error.localizedDescription)"
            }
            isWorking = false
        }
    }
}
