import SwiftUI

struct ImportedRecipieIngredientsSection: View {
    @Binding var ingredients: [ImportedRecipieIngredient]
    let items: [Item]
    let units: [Unit]
    let categories: [Category]
    @State private var editing: ImportedRecipieIngredient?

    var body: some View {
        Section {
            ForEach(ingredients) { ingredient in
                Button {
                    editing = ingredient
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ingredient.sourceText)
                            .foregroundStyle(.primary)
                        if ingredient.isResolved(items: items, units: units, categories: categories) {
                            let name = ingredient.newItem?.name ?? items.first { $0.id == ingredient.itemID }?.name ?? ingredient.name
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
                editing = ImportedRecipieIngredient(sourceText: "", name: "", quantityText: "")
            }
        } header: {
            Text("Ingredients")
        } footer: {
            Text("Tap an ingredient to review it. New items are saved with the recipe. Resolve highlighted ingredients before saving.")
        }
        .sheet(item: $editing) { ingredient in
            ImportedRecipieIngredientEdit(ingredient: ingredient, items: items, units: units, categories: categories) { updated in
                if let index = ingredients.firstIndex(where: { $0.id == updated.id }) {
                    ingredients[index] = updated
                } else {
                    ingredients.append(updated)
                }
            }
        }
    }
}

private struct ImportedRecipieIngredientEdit: View {
    @Environment(\.dismiss) private var dismiss
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
        NavigationStack {
            Form {
                Section("Original ingredient") {
                    TextField("Ingredient line and preparation notes", text: $ingredient.sourceText, axis: .vertical)
                }
                Section("Item") {
                    if let newItem = Binding($ingredient.newItem) {
                        NewImportedItemFields(item: newItem, categories: categories)
                        Button("Use Existing Item") { ingredient.newItem = nil }
                    } else {
                        Picker("Item", selection: $ingredient.itemID) {
                            Text("Choose an item").tag(nil as UUID?)
                            ForEach(items) { item in Text(item.name).tag(Optional(item.id)) }
                        }
                        Button("Create New Item") {
                            ingredient.itemID = nil
                            ingredient.newItem = NewRecipieItemDraft(name: ingredient.name)
                        }
                    }
                }
                ImportedQuantityFields(ingredient: $ingredient, units: units)
            }
            .navigationTitle("Review Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if ingredient.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ingredient.sourceText = ingredient.newItem?.name ?? items.first { $0.id == ingredient.itemID }?.name ?? ""
                        }
                        onSave(ingredient)
                        dismiss()
                    }
                    .disabled(!ingredient.isResolved(items: items, units: units, categories: categories))
                }
            }
        }
    }
}

private struct NewImportedItemFields: View {
    @Binding var item: NewRecipieItemDraft
    let categories: [Category]

    var body: some View {
        TextField("Item name", text: $item.name)
        Picker("Category", selection: $item.categoryID) {
            Text("Choose a category").tag(nil as UUID?)
            ForEach(categories) { category in Text(category.name).tag(Optional(category.id)) }
        }
        ForEach(Dietary.allCases) { dietary in
            Toggle(dietary.label, isOn: Binding(
                get: { item.dietary.contains(dietary) },
                set: { if $0 { item.dietary.insert(dietary) } else { item.dietary.remove(dietary) } }
            ))
        }
        Text("Check the category and dietary details before tapping Done.")
            .font(.caption).foregroundStyle(.secondary)
    }
}

private struct ImportedQuantityFields: View {
    @Binding var ingredient: ImportedRecipieIngredient
    let units: [Unit]

    var body: some View {
        Section {
            TextField("Quantity, e.g. 1 1/2", text: $ingredient.quantityText)
                .keyboardType(.numbersAndPunctuation)
            Picker("Unit", selection: $ingredient.unitID) {
                Text("Choose a unit").tag(nil as UUID?)
                ForEach(units) { unit in Text(unit.name).tag(Optional(unit.id)) }
            }
            .onChange(of: ingredient.unitID) { _, _ in ingredient.magnitudeID = nil }
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
