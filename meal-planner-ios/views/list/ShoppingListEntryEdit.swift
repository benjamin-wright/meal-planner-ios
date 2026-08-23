import SwiftUI
import SwiftData

struct ShoppingListEntryEdit: View {
    private enum EntryKind: String, CaseIterable, Identifiable {
        case item = "Saved Item"
        case note = "Quick Note"

        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Item.name) private var items: [Item]
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \Unit.name) private var units: [Unit]

    @State private var kind: EntryKind = .item
    @State private var selectedItemID = UUID()
    @State private var selectedCategoryID = UUID()
    @State private var selectedUnitID = UUID()
    @State private var name = ""
    @State private var quantity = 1.0
    @State private var saveError: String?

    private var selectedUnit: Unit? {
        units.first { $0.id == selectedUnitID }
    }

    private var canSave: Bool {
        guard selectedUnit != nil, quantity > 0, quantity.isFinite else { return false }
        switch kind {
        case .item:
            return items.contains { $0.id == selectedItemID }
        case .note:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && categories.contains { $0.id == selectedCategoryID }
        }
    }

    private func prepareDefaults() {
        if !items.contains(where: { $0.id == selectedItemID }) {
            selectedItemID = items.first?.id ?? UUID()
        }
        if !categories.contains(where: { $0.id == selectedCategoryID }) {
            selectedCategoryID = categories.first?.id ?? UUID()
        }
        if !units.contains(where: { $0.id == selectedUnitID }) {
            selectedUnitID = units.first(where: { $0.unitType == .count })?.id ?? units.first?.id ?? UUID()
        }
    }

    private func save() {
        do {
            let store = ShoppingListStore(context: context)
            switch kind {
            case .item:
                try store.addItem(itemID: selectedItemID, unitID: selectedUnitID, quantity: quantity)
            case .note:
                try store.addNote(
                    name,
                    categoryID: selectedCategoryID,
                    unitID: selectedUnitID,
                    quantity: quantity
                )
            }
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) {
                    ForEach(EntryKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                Section(kind.rawValue) {
                    switch kind {
                    case .item:
                        Picker("Item", selection: $selectedItemID) {
                            ForEach(items) { item in
                                Text(item.name).tag(item.id)
                            }
                        }
                    case .note:
                        TextInput(text: $name, label: "Name", placeholder: "e.g. birthday candles")
                        Picker("Category", selection: $selectedCategoryID) {
                            ForEach(categories) { category in
                                Text(category.name).tag(category.id)
                            }
                        }
                    }
                }

                Section("Quantity") {
                    Picker("Unit", selection: $selectedUnitID) {
                        ForEach(units) { unit in
                            Text(unit.name).tag(unit.id)
                        }
                    }
                    if let selectedUnit {
                        UnitInput(label: "Quantity", unit: .constant(selectedUnit), value: $quantity)
                    }
                }
            }
            .navigationTitle("Add to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: save).disabled(!canSave)
                }
            }
            .onAppear(perform: prepareDefaults)
            .alert("Shopping List", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
    }
}

#Preview {
    ShoppingListEntryEdit()
        .modelContainer(Models.testing.modelContainer)
}
