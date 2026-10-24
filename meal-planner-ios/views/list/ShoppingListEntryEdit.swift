import SwiftUI
import SwiftData

struct ShoppingListEntryEdit: View {
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \Item.name) private var items: [Item]
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \Unit.name) private var units: [Unit]
    @State private var draft = CatalogEntryDraft()
    @State private var saveError: String?
    @State private var isLoading = false

    private func prepareDefaults() {
        draft.itemID = items.first?.id
        draft.categoryID = categories.first?.id
        draft.unitID = Unit.defaultForNewObject(in: units)?.id
    }

    private func save() {
        guard let unitID = draft.unitID else { return }
        do {
            let store = ShoppingListStore(context: context)
            switch draft.kind {
            case .item:
                guard let itemID = draft.itemID else { return }
                try store.addItem(itemID: itemID, unitID: unitID, quantity: draft.quantity)
            case .note:
                guard let categoryID = draft.categoryID else { return }
                try store.addNote(draft.note, categoryID: categoryID, unitID: unitID, quantity: draft.quantity)
            }
            onClose()
        } catch {
            saveError = error.localizedDescription
        }
    }

    var body: some View {
        GlassForm {
            CatalogEntryFields(draft: $draft, items: items, categories: categories, units: units,
                               noteTitle: "Quick Note", noteLabel: "Name")
        }
        .navigationTitle("Add to List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onClose)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add", action: save)
                    .disabled(!draft.isValid(items: items, categories: categories, units: units))
            }
        }
        .onFirstAppear(perform: prepareDefaults, loading: $isLoading)
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
