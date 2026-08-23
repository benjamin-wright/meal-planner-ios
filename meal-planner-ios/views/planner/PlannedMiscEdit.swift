import SwiftUI
import SwiftData

struct PlannedMiscEdit: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(FlowRouter.self) private var router

    private let id: UUID?
    @Query private var entries: [PlannedMiscEntry]
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \Unit.name) private var units: [Unit]
    @State private var note = ""
    @State private var selectedItem: Item?
    @State private var selectedCategoryID = UUID()
    @State private var selectedUnitID = UUID()
    @State private var quantity = 1.0
    @State private var isLoading = false
    @State private var saveError: String?

    init(id: UUID? = nil) {
        self.id = id
    }

    private func load() {
        guard let id else {
            selectedCategoryID = categories.first?.id ?? UUID()
            selectedUnitID = units.first(where: { $0.unitType == .count })?.id ?? units.first?.id ?? UUID()
            return
        }
        guard let entry = entries.first(where: { $0.id == id }) else {
            saveError = PlannedMiscStore.Error.notFound.localizedDescription
            return
        }
        note = entry.noteText ?? ""
        selectedItem = entry.item
        selectedCategoryID = entry.category?.id ?? categories.first?.id ?? UUID()
        selectedUnitID = entry.unit?.id ?? units.first(where: { $0.unitType == .count })?.id ?? UUID()
        quantity = entry.quantity
    }

    private func chooseItem() {
        router.showItemPicker(selectedID: selectedItem?.id ?? UUID()) { itemID in
            guard let item = try? context.fetch(Item.descriptor(id: itemID)).first else { return }
            selectedItem = item
            note = ""
        }
    }

    private func saveNote() {
        do {
            try PlannedMiscStore(context: context).saveNote(
                note,
                categoryID: selectedCategoryID,
                unitID: selectedUnitID,
                quantity: quantity,
                id: id
            )
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func saveItem() {
        guard let selectedItem else { return }
        do {
            try PlannedMiscStore(context: context).saveItem(
                selectedItem.id,
                unitID: selectedUnitID,
                quantity: quantity,
                id: id
            )
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    var body: some View {
        Form {
            Section("Quantity") {
                Button {
                    router.showUnitPicker(selectedID: selectedUnitID) { selectedUnitID = $0 }
                } label: {
                    Text("Unit").badge(units.first(where: { $0.id == selectedUnitID })?.name ?? "Choose unit")
                }
                if let unit = units.first(where: { $0.id == selectedUnitID }) {
                    UnitInput(label: "Quantity", unit: .constant(unit), value: $quantity)
                }
            }

            Section("Saved item") {
                Button(action: chooseItem) {
                    HStack {
                        Text("Item")
                        Spacer()
                        Text(selectedItem?.name ?? "Choose item")
                            .foregroundStyle(selectedItem == nil ? .secondary : .primary)
                    }
                }
                if selectedItem != nil {
                    Button("Save Item", action: saveItem)
                        .disabled(!units.contains { $0.id == selectedUnitID } || quantity <= 0)
                }
            }

            Section("One-off note") {
                TextInput(text: $note, label: "Note", placeholder: "e.g. birthday candles")
                Button {
                    router.showCategoryPicker(selectedID: selectedCategoryID) { selectedCategoryID = $0 }
                } label: {
                    Text("Category").badge(categories.first(where: { $0.id == selectedCategoryID })?.name ?? "Choose category")
                }
                Button("Save Note", action: saveNote)
                    .disabled(
                        note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || !categories.contains { $0.id == selectedCategoryID }
                            || !units.contains { $0.id == selectedUnitID }
                            || quantity <= 0
                    )
            }
        }
        .navigationTitle("Misc Entry")
        .onFirstAppear(perform: load, loading: $isLoading)
        .alert("Misc Entry", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }
}
