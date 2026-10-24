import Foundation

/// Read-only recipe content, adjusted for a particular meal occurrence.
struct RecipeDisplayData {
    struct Ingredient: Identifiable {
        let id: UUID
        let name: String
        let quantity: String
    }

    let name: String
    let summary: String
    let servings: Int
    let time: Int
    let hasSubstitutions: Bool
    let ingredients: [Ingredient]
    let steps: [String]

    init(
        recipe: Recipie, component: MealComponentDraft? = nil, servings: Int? = nil,
        items: [Item], units: [Unit]
    ) {
        name = recipe.name
        summary = recipe.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "" : recipe.summary
        let displayedServings = max(1, servings ?? recipe.serves)
        self.servings = displayedServings
        time = recipe.time
        hasSubstitutions = component?.ingredientOverrides.isEmpty == false
        steps = recipe.steps.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let scale = recipe.serves > 0 ? Double(displayedServings) / Double(recipe.serves) : 1
        let effectiveIngredients = component?.ingredients(for: recipe)
            ?? recipe.ingredients.map(RecipieIngredientDraft.init)
        ingredients = effectiveIngredients.map { ingredient in
            let name = items.first { $0.id == ingredient.itemID }?.name
                ?? recipe.ingredients.first { $0.item.id == ingredient.itemID }?.item.name
                ?? "Missing ingredient"
            let scaledQuantity = ingredient.quantity * scale
            let quantity: String
            if scaledQuantity.isFinite && scaledQuantity > 0 {
                let unit = units.first { $0.id == ingredient.unitID }
                    ?? recipe.ingredients.first { $0.unit.id == ingredient.unitID }?.unit
                quantity = unit?.toString(forValue: scaledQuantity) ?? "Missing unit"
            } else {
                quantity = "Quantity unavailable"
            }
            return Ingredient(id: ingredient.id, name: name, quantity: quantity)
        }
    }
}
