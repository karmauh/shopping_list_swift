import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class ConnectionTester: ObservableObject {
    @Published var status = "Test nie był uruchomiony"
    @Published var isRunning = false

    func run() async {
        isRunning = true
        defer { isRunning = false }
        do {
            let user: User
            if let current = Auth.auth().currentUser {
                user = current
            } else {
                user = try await Auth.auth().signInAnonymously().user
            }
            let reference = Firestore.firestore()
                .collection("connectionTests")
                .document(user.uid)
            let bundleID = Bundle.main.bundleIdentifier ?? "brak"
            try await reference.setData([
                "checkedAt": FieldValue.serverTimestamp(),
                "bundleID": bundleID
            ])
            let snapshot = try await reference.getDocument(source: .server)
            let saved = snapshot.data()?["bundleID"] as? String ?? "brak"
            status = "OK. Użytkownik: \(user.uid.prefix(6)), identyfikator: \(saved)"
        } catch {
            status = "Błąd: \(error.localizedDescription)"
        }
    }
}
