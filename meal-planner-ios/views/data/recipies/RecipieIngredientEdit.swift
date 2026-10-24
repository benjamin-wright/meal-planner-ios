//
//  RecipieIngredientEdit.swift
//  meal-planner-ios
//

import SwiftUI

struct RecipieIngredientEdit: View {
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

    private var validationMessage: String? {
        do {
            _ = try IngredientResolver(items: items, units: units).resolve(value)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    var body: some View {
        GlassForm {
            if let sourceText = value.sourceText, !sourceText.isEmpty {
                Section("Original ingredient") {
                    Text(sourceText)
                }
            }
            Section {
                Button {
                    router.showItemPicker(selectedID: value.itemID, kindFilter: .ingredient) { id in
                        value.itemID = id
                    }
                } label: {
                    Text("Item").badge(items.first(where: { $0.id == value.itemID })?.name ?? "")
                }
                QuantityFields(
                    unit: units.first { $0.id == value.unitID },
                    quantity: $value.quantity,
                    unitPlaceholder: ""
                ) {
                    router.showUnitPicker(selectedID: value.unitID) { id in
                        value.unitID = id
                    }
                }
            }
            if let validationMessage {
                Text(validationMessage)
                    .foregroundStyle(.red)
            }
            Button(edit ? "Save" : "Add") {
                action(value)
            }
            .disabled(validationMessage != nil)
        }
        .navigationTitle("Ingredient")
    }
}
