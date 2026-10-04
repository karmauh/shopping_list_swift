import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class ImportCoordinator {
    struct Pending: Identifiable {
        let id = UUID()
        let file: SharedListFile
        let summary: ImportSummary
    }

    var pending: Pending?
    var resultMessage: String?
    var errorMessage: String?

    func handle(url: URL, context: ModelContext) {
        do {
            let file = try ListImporter.load(from: url)
            let summary = try ListImporter.preview(file, in: context)

            guard summary.hasChanges else {
                resultMessage = summary.message
                return
            }

            if UserDefaults.standard.bool(forKey: AppSettings.mergeWithoutAskingKey) {
                let result = try ListImporter.merge(file, in: context)
                resultMessage = result.message
            } else {
                pending = Pending(file: file, summary: summary)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmMerge(context: ModelContext) {
        guard let current = pending else { return }
        pending = nil
        do {
            let result = try ListImporter.merge(current.file, in: context)
            announce(result.message)
        } catch {
            announceError(error.localizedDescription)
        }
    }

    func confirmAsNew(context: ModelContext) {
        guard let current = pending else { return }
        pending = nil
        do {
            let result = try ListImporter.importAsNew(current.file, in: context)
            announce(result.message)
        } catch {
            announceError(error.localizedDescription)
        }
    }

    func cancel() {
        pending = nil
    }

    private func announce(_ message: String) {
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            resultMessage = message
        }
    }

    private func announceError(_ message: String) {
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            errorMessage = message
        }
    }
}
