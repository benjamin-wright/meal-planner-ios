import SwiftUI
import SwiftData

struct PlannedMiscEdit: View {
    private enum EntryKind: String, CaseIterable, Identifiable {
        case item = "Saved Item"
        case note = "One-off Note"

        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(FlowRouter.self) private var router

    private let id: UUID?
    @Query private var entries: [PlannedMiscEntry]
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \Unit.name) private var units: [Unit]
    @State private var kind: EntryKind = .item
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
            selectedUnitID = Unit.defaultForNewObject(in: units)?.id ?? UUID()
            return
        }
        guard let entry = entries.first(where: { $0.id == id }) else {
            saveError = PlannedMiscStore.Error.notFound.localizedDescription
            return
        }
        kind = entry.item == nil ? .note : .item
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
                    Button(action: chooseItem) {
                        HStack {
                            Text("Item")
                            Spacer()
                            Text(selectedItem?.name ?? "Choose item")
                                .foregroundStyle(selectedItem == nil ? .secondary : .primary)
                        }
                    }
                case .note:
                    TextInput(text: $note, label: "Note", placeholder: "e.g. birthday candles")
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
                    Text("Unit").badge(units.first(where: { $0.id == selectedUnitID })?.name ?? "Choose unit")
                }
                if let unit = units.first(where: { $0.id == selectedUnitID }) {
                    UnitInput(label: "Quantity", unit: .constant(unit), value: $quantity)
                }
            }

            Section {
                switch kind {
                case .item:
                    Button("Save Item", action: saveItem)
                        .disabled(
                            selectedItem == nil
                                || !units.contains { $0.id == selectedUnitID }
                                || quantity <= 0
                        )
                case .note:
                    Button("Save Note", action: saveNote)
                        .disabled(
                            note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || !categories.contains { $0.id == selectedCategoryID }
                                || !units.contains { $0.id == selectedUnitID }
                                || quantity <= 0
                        )
                }
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
