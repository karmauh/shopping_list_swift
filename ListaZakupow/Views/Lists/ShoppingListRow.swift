import SwiftUI

struct ShoppingListRow: View {
    let list: ShoppingList

    private var summary: String {
        if list.totalCount == 0 {
            return "Brak produktów"
        }
        return "Kupione: \(list.purchasedCount) z \(list.totalCount)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(list.name)
                .font(.headline)
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
