import SwiftUI

struct ImportedRecipieIngredientsSection: View {
    @Environment(FlowRouter.self) private var router
    @Binding var ingredients: [ImportedRecipieIngredient]
    let items: [Item]
    let units: [Unit]
    let categories: [Category]

    private func review(_ ingredient: ImportedRecipieIngredient) {
        router.showImportedRecipieIngredient(ingredient) { updated in
            if let index = ingredients.firstIndex(where: { $0.id == updated.id }) {
                ingredients[index] = updated
            } else {
                ingredients.append(updated)
            }
        }
    }

    var body: some View {
        Section {
            ForEach(ingredients) { ingredient in
                Button {
                    review(ingredient)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ingredient.sourceText)
                            .foregroundStyle(.primary)
                        if ingredient.isResolved(items: items, units: units, categories: categories) {
                            let name = items.first { $0.id == ingredient.itemID }?.name ?? ingredient.name
                            let unit = units.first { $0.id == ingredient.unitID }
                            let quantity = ingredient.quantity(units: units) ?? 0
                            Text("\(name): \(unit?.toString(forValue: quantity) ?? "")")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Label("Review item, unit or quantity", systemImage: "exclamationmark.circle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                }
            }
            .onDelete { ingredients.remove(atOffsets: $0) }
            Button("Add Ingredient", systemImage: "plus") {
                review(ImportedRecipieIngredient(sourceText: "", name: "", quantityText: ""))
            }
        } header: {
            Text("Ingredients")
        } footer: {
            Text("Tap an ingredient to review it. Add new items from the item picker, then select them. Resolve highlighted ingredients before saving.")
        }
    }
}

struct ImportedRecipieIngredientEdit: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FlowRouter.self) private var router
    @State private var ingredient: ImportedRecipieIngredient
    private let items: [Item]
    private let units: [Unit]
    private let categories: [Category]
    private let onSave: (ImportedRecipieIngredient) -> Void

    init(ingredient: ImportedRecipieIngredient, items: [Item], units: [Unit], categories: [Category],
         onSave: @escaping (ImportedRecipieIngredient) -> Void) {
        _ingredient = State(initialValue: ingredient)
        self.items = items.filter { $0.itemKind == .ingredient }
        self.units = units
        self.categories = categories
        self.onSave = onSave
    }

    var body: some View {
        GlassForm {
            Section("Original ingredient") {
                TextField("Ingredient line and preparation notes", text: $ingredient.sourceText, axis: .vertical)
            }
            Section("Item") {
                Button {
                    router.showItemPicker(selectedID: ingredient.itemID ?? UUID()) { id in
                        ingredient.itemID = id
                    }
                } label: {
                    Text("Item").badge(items.first { $0.id == ingredient.itemID }?.name ?? "Choose an item")
                }
            }
            ImportedQuantityFields(ingredient: $ingredient, units: units)
            Button("Done") {
                if ingredient.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ingredient.sourceText = items.first { $0.id == ingredient.itemID }?.name ?? ""
                }
                onSave(ingredient)
                dismiss()
            }
            .disabled(!ingredient.isResolved(items: items, units: units, categories: categories))
        }
        .navigationTitle("Review Ingredient")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ImportedQuantityFields: View {
    @Environment(FlowRouter.self) private var router
    @Binding var ingredient: ImportedRecipieIngredient
    let units: [Unit]

    var body: some View {
        Section {
            TextField("Quantity, e.g. 1 1/2", text: $ingredient.quantityText)
                .keyboardType(.numbersAndPunctuation)
            Button {
                router.showUnitPicker(selectedID: ingredient.unitID ?? UUID()) { id in
                    ingredient.unitID = id
                    ingredient.magnitudeID = nil
                }
            } label: {
                Text("Unit").badge(units.first { $0.id == ingredient.unitID }?.name ?? "Choose a unit")
            }
            if let unit = units.first(where: { $0.id == ingredient.unitID }), !unit.magnitudes.isEmpty {
                Picker("Measure", selection: $ingredient.magnitudeID) {
                    Text(unit.name).tag(nil as UUID?)
                    ForEach(unit.magnitudes) { magnitude in Text(magnitude.plural).tag(Optional(magnitude.id)) }
                }
            }
        } header: {
            Text("Quantity")
        } footer: {
            Text("For ranges or unspecified amounts, choose the quantity you want to use. Fractions such as ½ and 1/2 are supported.")
        }
    }
}
