import SwiftUI

struct CatalogEntryFields: View {
    @Environment(FlowRouter.self) private var router
    @Binding var draft: CatalogEntryDraft
    let items: [Item]
    let categories: [Category]
    let units: [Unit]
    var noteTitle = "One-off Note"
    var noteLabel = "Note"

    private var selectedUnit: Unit? { units.first { $0.id == draft.unitID } }

    var body: some View {
        Picker("Type", selection: $draft.kind) {
            Text("Saved Item").tag(CatalogEntryDraft.Kind.item)
            Text(noteTitle).tag(CatalogEntryDraft.Kind.note)
        }
        .pickerStyle(.segmented)

        Section(draft.kind == .item ? "Saved Item" : noteTitle) {
            switch draft.kind {
            case .item:
                Button {
                    router.showItemPicker(selectedID: draft.itemID ?? UUID()) { draft.itemID = $0 }
                } label: {
                    Text("Item").badge(items.first { $0.id == draft.itemID }?.name ?? "Choose item")
                }
            case .note:
                TextInput(text: $draft.note, label: noteLabel, placeholder: "e.g. birthday candles")
                Button {
                    router.showCategoryPicker(selectedID: draft.categoryID ?? UUID()) { draft.categoryID = $0 }
                } label: {
                    Text("Category").badge(categories.first { $0.id == draft.categoryID }?.name ?? "Choose category")
                }
            }
        }

        Section("Quantity") {
            QuantityFields(unit: selectedUnit, quantity: $draft.quantity) {
                router.showUnitPicker(selectedID: draft.unitID ?? UUID()) { draft.unitID = $0 }
            }
        }
    }
}
