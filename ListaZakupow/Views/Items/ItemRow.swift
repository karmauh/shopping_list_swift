import SwiftUI

struct ItemRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void

    private var tint: Color {
        if item.isPurchased {
            return .secondary
        }
        return item.category?.categoryColor.color ?? .gray
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .strikethrough(item.isPurchased)
                        .foregroundStyle(item.isPurchased ? .secondary : .primary)
                    if !item.quantity.isEmpty {
                        Text(item.quantity)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
