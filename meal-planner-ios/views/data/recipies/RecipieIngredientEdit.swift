//
//  RecipieIngredientEdit.swift
//  meal-planner-ios
//

import SwiftUI

struct RecipieIngredientEdit: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FlowRouter.self) private var router

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
                Button {
                    router.showItemPicker(selectedID: value.itemID) { id in
                        value.itemID = id
                    }
                } label: {
                    Text("Item").badge(items.first(where: { $0.id == value.itemID })?.name ?? "")
                }
                Button {
                    router.showUnitPicker(selectedID: value.unitID) { id in
                        value.unitID = id
                    }
                } label: {
                    Text("Unit").badge(units.first(where: { $0.id == value.unitID })?.name ?? "")
                }
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
