import Foundation
import SwiftData

/// Owns the reference policy for recipe ingredients and serialized substitutions.
@MainActor
struct IngredientDependencies {
    let recipeItemIDs: Set<UUID>
    let substitutionItemIDs: Set<UUID>
    let unitIDs: Set<UUID>

    init(context: ModelContext) throws {
        let ingredients = try context.fetch(FetchDescriptor<RecipieIngredient>())
        let components = try context.fetch(FetchDescriptor<MealComponent>())
        let overrides = components.flatMap { $0.ingredientOverrides ?? [] }
        recipeItemIDs = Set(ingredients.map { $0.item.id })
        substitutionItemIDs = Set(overrides.map(\.itemID))
        unitIDs = Set(ingredients.map { $0.unit.id })
            .union(components.compactMap { $0.unit?.id })
            .union(overrides.map(\.unitID))
    }

    func preventsItemKindChange(_ id: UUID, to kind: ItemKind) -> Bool {
        kind != .ingredient && (recipeItemIDs.contains(id) || substitutionItemIDs.contains(id))
    }

    static func retainSubstitutions(in recipe: Recipie, ingredientIDs: Set<UUID>) {
        for component in recipe.mealComponents {
            guard let overrides = component.ingredientOverrides else { continue }
            let retained = IngredientResolver.retaining(overrides, ingredientIDs: ingredientIDs)
            component.ingredientOverrides = retained.isEmpty ? nil : retained
        }
    }
}
