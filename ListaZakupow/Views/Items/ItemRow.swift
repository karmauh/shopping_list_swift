import SwiftUI

struct ItemRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void
    let onEdit: () -> Void

    private var tint: Color {
        if item.isPurchased {
            return .secondary
        }
        return item.category?.categoryColor.color ?? .gray
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(tint)
            }
            .buttonStyle(.borderless)

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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)
        }
        .padding(.vertical, 2)
    }
}
