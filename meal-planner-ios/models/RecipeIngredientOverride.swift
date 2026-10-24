import Foundation

struct RecipeIngredientOverride: Identifiable, Codable, Hashable {
    /// The source recipe ingredient, not the substituted catalogue item.
    var id: UUID
    var itemID: UUID
    var unitID: UUID
    /// Quantity for the recipe's original yield, scaled by the planner at generation time.
    var quantity: Double

    init(ingredient: RecipieIngredientDraft) {
        id = ingredient.id
        itemID = ingredient.itemID
        unitID = ingredient.unitID
        quantity = ingredient.quantity
    }

    var draft: RecipieIngredientDraft {
        RecipieIngredientDraft(id: id, itemID: itemID, unitID: unitID, quantity: quantity)
    }
}
