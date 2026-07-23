//
//  RecipieIngredientEdit.swift
//  meal-planner-ios
//

import SwiftUI

struct RecipieIngredientEdit: View {
    @Environment(\.dismiss) private var dismiss

    let edit: Bool
    @State private var value: RecipieIngredientDraft
    private let items: [Item]
    private let units: [Unit]
    private let action: (RecipieIngredientDraft) -> Void

    init(edit: Bool, value: RecipieIngredientDraft, items: [Item], units: [Unit], action: @escaping (RecipieIngredientDraft) -> Void) {
        self.edit = edit
        self._value = State(initialValue: value)
        self.items = items
        self.units = units
        self.action = action
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    ItemPicker(
                        items: items,
                        selected: Binding(
                            get: { items.first(where: { $0.id == value.itemID }) ?? items[0] },
                            set: { value.itemID = $0.id }
                        )
                    )
                } label: {
                    Text("Item").badge(items.first(where: { $0.id == value.itemID })?.name ?? "")
                }
                UnitPicker(label: "Unit", selectedID: $value.unitID)
                if let unit = units.first(where: { $0.id == value.unitID }) {
                    UnitInput(
                        label: "Quantity",
                        unit: .constant(unit),
                        value: $value.quantity
                    )
                }
            }
            Button(edit ? "Save" : "Add") {
                action(value)
                dismiss()
            }
        }
        .navigationTitle("Ingredient")
    }
}
