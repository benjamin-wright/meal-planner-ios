import SwiftUI
import SwiftData

struct ShoppingListEntryEdit: View {
    private enum EntryKind: String, CaseIterable, Identifiable {
        case item = "Saved Item"
        case note = "Quick Note"

        var id: Self { self }
    }

    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(FlowRouter.self) private var router
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
            onClose()
        } catch {
            saveError = error.localizedDescription
        }
    }

    var body: some View {
        GlassForm {
            Picker("Type", selection: $kind) {
                ForEach(EntryKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            Section(kind.rawValue) {
                switch kind {
                case .item:
                    Button {
                        router.showItemPicker(selectedID: selectedItemID) { selectedItemID = $0 }
                    } label: {
                        Text("Item").badge(items.first(where: { $0.id == selectedItemID })?.name ?? "Choose item")
                    }
                case .note:
                    TextInput(text: $name, label: "Name", placeholder: "e.g. birthday candles")
                    Button {
                        router.showCategoryPicker(selectedID: selectedCategoryID) { selectedCategoryID = $0 }
                    } label: {
                        Text("Category").badge(categories.first(where: { $0.id == selectedCategoryID })?.name ?? "Choose category")
                    }
                }
            }

            Section("Quantity") {
                Button {
                    router.showUnitPicker(selectedID: selectedUnitID) { selectedUnitID = $0 }
                } label: {
                    Text("Unit").badge(selectedUnit?.name ?? "Choose unit")
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
                Button("Cancel", action: onClose)
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

#Preview {
    FlowContainer {
        ShoppingListEntryEdit(onClose: {})
    }
    .modelContainer(Models.testing.modelContainer)
}
