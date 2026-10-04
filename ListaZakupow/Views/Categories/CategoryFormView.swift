import SwiftUI
import SwiftData

enum CategoryFormMode: Identifiable {
    case add
    case edit(ProductCategory)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let category):
            return category.id.uuidString
        }
    }

    var existingCategory: ProductCategory? {
        if case .edit(let category) = self {
            return category
        }
        return nil
    }
}

struct CategoryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var categories: [ProductCategory]

    private let category: ProductCategory?

    @State private var name: String
    @State private var symbolName: String
    @State private var colorName: String

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    static let symbols: [String] = [
        "leaf.fill", "basket.fill", "oven.fill", "drop.fill", "flame.fill", "cup.and.saucer.fill",
        "birthday.cake.fill", "snowflake", "sparkles", "fork.knife", "cart.fill", "bag.fill",
        "gift.fill", "pawprint.fill", "pills.fill", "cross.case.fill", "tshirt.fill", "house.fill",
        "lightbulb.fill", "wrench.and.screwdriver.fill", "book.fill", "tag.fill", "heart.fill",
        "star.fill", "bolt.fill", "sun.max.fill", "moon.fill"
    ]

    init(mode: CategoryFormMode) {
        let existing = mode.existingCategory
        category = existing
        _name = State(initialValue: existing?.name ?? "")
        _symbolName = State(initialValue: existing?.symbolName ?? "tag.fill")
        _colorName = State(initialValue: existing?.colorName ?? CategoryColor.blue.rawValue)
    }

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var isDuplicate: Bool {
        let key = cleanName.comparisonKey
        return categories.contains { other in
            other.id != category?.id && other.name.comparisonKey == key
        }
    }

    private var isValid: Bool {
        !cleanName.isEmpty && !isDuplicate
    }

    private var selectedColor: Color {
        CategoryColor(rawValue: colorName)?.color ?? .gray
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Podgląd") {
                    HStack(spacing: 12) {
                        Image(systemName: symbolName)
                            .font(.title2)
                            .foregroundStyle(selectedColor)
                            .frame(width: 32)
                        Text(cleanName.isEmpty ? "Nazwa kategorii" : cleanName)
                            .foregroundStyle(cleanName.isEmpty ? .secondary : .primary)
                    }
                }

                Section {
                    TextField("Nazwa kategorii", text: $name)
                } header: {
                    Text("Nazwa")
                } footer: {
                    if isDuplicate {
                        Text("Kategoria o tej nazwie już istnieje.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Ikona") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Self.symbols, id: \.self) { symbol in
                            Button {
                                symbolName = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .foregroundStyle(.primary)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        symbolName == symbol ? selectedColor.opacity(0.2) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10)
                                    )
                                    .overlay {
                                        if symbolName == symbol {
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedColor, lineWidth: 2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Kolor") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(CategoryColor.allCases) { option in
                            Button {
                                colorName = option.rawValue
                            } label: {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if colorName == option.rawValue {
                                            Image(systemName: "checkmark")
                                                .font(.footnote.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(category == nil ? "Nowa kategoria" : "Edycja kategorii")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        if let category {
            category.name = cleanName
            category.symbolName = symbolName
            category.colorName = colorName
        } else {
            CategoryService.insert(
                name: cleanName,
                symbolName: symbolName,
                colorName: colorName,
                in: modelContext
            )
        }
        dismiss()
    }
}
