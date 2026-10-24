import SwiftUI

/// A read-only preview, including any substitutions made for this occurrence.
struct RecipePreview: View {
    let recipe: Recipie
    let component: MealComponentDraft?
    let servings: Int?
    let items: [Item]
    let units: [Unit]

    init(
        recipe: Recipie, component: MealComponentDraft? = nil, servings: Int? = nil,
        items: [Item], units: [Unit]
    ) {
        self.recipe = recipe
        self.component = component
        self.servings = servings
        self.items = items
        self.units = units
    }

    private var displayedServings: Int { max(1, servings ?? recipe.serves) }

    private var ingredients: [RecipieIngredientDraft] {
        component?.ingredients(for: recipe) ?? recipe.ingredients.map(RecipieIngredientDraft.init)
    }

    private var steps: [String] {
        recipe.steps.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func ingredientName(_ ingredient: RecipieIngredientDraft) -> String {
        items.first { $0.id == ingredient.itemID }?.name
            ?? recipe.ingredients.first { $0.item.id == ingredient.itemID }?.item.name
            ?? "Missing ingredient"
    }

    private func ingredientQuantity(_ ingredient: RecipieIngredientDraft) -> String {
        let scale = recipe.serves > 0 ? Double(displayedServings) / Double(recipe.serves) : 1
        let quantity = ingredient.quantity * scale
        guard quantity.isFinite && quantity > 0 else { return "Quantity unavailable" }
        let unit = units.first { $0.id == ingredient.unitID }
            ?? recipe.ingredients.first { $0.unit.id == ingredient.unitID }?.unit
        return unit?.toString(forValue: quantity) ?? "Missing unit"
    }

    var body: some View {
        GlassForm {
            Section {
                if !recipe.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(recipe.summary)
                }
                LabeledContent("Cooking time", value: recipe.time >= 0 ? "\(recipe.time) minutes" : "Not recorded")
                LabeledContent("Servings", value: "\(displayedServings)")
                if component?.ingredientOverrides.isEmpty == false {
                    Label("Includes your ingredient substitutions", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(ingredients) { ingredient in
                    ItemQuantityRow(
                        name: ingredientName(ingredient),
                        quantity: ingredientQuantity(ingredient)
                    )
                    .accessibilityIdentifier("recipePreviewIngredient-\(ingredient.id)")
                }
                if ingredients.isEmpty {
                    Text("No ingredients recorded.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                GlassSectionHeader(title: "Ingredients")
            } footer: {
                Text("Quantities are for \(displayedServings) servings.")
            }

            Section {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text(step)
                    }
                    .accessibilityElement(children: .combine)
                }
                if steps.isEmpty {
                    Text("No method has been recorded for this recipe.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                GlassSectionHeader(title: "Method")
            }
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
