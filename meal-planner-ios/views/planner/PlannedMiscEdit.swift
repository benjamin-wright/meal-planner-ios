import SwiftUI
import SwiftData

struct PlannedMiscEdit: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let id: UUID?
    @Query private var entries: [PlannedMiscEntry]
    @Query(sort: \Item.name) private var items: [Item]
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \Unit.name) private var units: [Unit]
    @State private var draft = CatalogEntryDraft()
    @State private var isLoading = false
    @State private var saveError: String?

    init(id: UUID? = nil) { self.id = id }

    private func load() {
        guard let id else {
            draft.categoryID = categories.first?.id
            draft.unitID = Unit.defaultForNewObject(in: units)?.id
            return
        }
        guard let entry = entries.first(where: { $0.id == id }) else {
            saveError = PlannedMiscStore.Error.notFound.localizedDescription
            return
        }
        draft = CatalogEntryDraft(
            kind: entry.item == nil ? .note : .item,
            itemID: entry.item?.id, note: entry.noteText ?? "",
            categoryID: entry.category?.id, unitID: entry.unit?.id, quantity: entry.quantity
        )
    }

    private func save() {
        guard let unitID = draft.unitID else { return }
        do {
            let store = PlannedMiscStore(context: context)
            switch draft.kind {
            case .item:
                guard let itemID = draft.itemID else { return }
                try store.saveItem(itemID, unitID: unitID, quantity: draft.quantity, id: id)
            case .note:
                guard let categoryID = draft.categoryID else { return }
                try store.saveNote(draft.note, categoryID: categoryID, unitID: unitID, quantity: draft.quantity, id: id)
            }
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    var body: some View {
        GlassForm {
            CatalogEntryFields(draft: $draft, items: items, categories: categories, units: units)
            Section {
                Button(draft.kind == .item ? "Save Item" : "Save Note", action: save)
                    .disabled(!draft.isValid(items: items, categories: categories, units: units))
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
