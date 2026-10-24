import Foundation

/// A value snapshot of the inputs required to generate a shopping list.
/// Creating it is the persistence boundary; calculation never reads or mutates models.
struct ShoppingListInput {
    struct Category {
        var id: UUID
        var order: Int
    }

    struct Item {
        var name: String
        var kind: ItemKind
        var category: Category
        var servings: Int? = nil
    }

    struct Recipe {
        var name: String
        var servings: Int
        var ingredients: [RecipieIngredientDraft]
    }

    struct Meal {
        var servings: Int
        var components: [MealComponentDraft]
    }

    struct Miscellaneous {
        var name: String
        var itemID: UUID?
        var category: Category?
        var unitID: UUID?
        var quantity: Double
    }

    var units: [UUID: UnitDefinition]
    var items: [UUID: Item]
    var recipes: [UUID: Recipe] = [:]
    var meals: [Meal] = []
    var miscellaneous: [Miscellaneous] = []
    var preferredWeightID: UUID
    var preferredVolumeID: UUID
}

struct GeneratedShoppingEntry: Equatable {
    var name: String
    var quantity: Double
    var itemID: UUID?
    var categoryID: UUID
    var categoryOrder: Int
    var unitID: UUID
}

enum ShoppingListCalculator {
    private struct AggregationKey: Hashable {
        let itemID: UUID
        let unitID: UUID
    }

    static func generate(from input: ShoppingListInput) throws -> [GeneratedShoppingEntry] {
        typealias Failure = ShoppingListError
        let resolver = IngredientResolver(itemKinds: input.items.mapValues(\.kind), units: input.units)
        let countUnit = input.units.values.first { $0.isBaseUnit && $0.type == .count && $0.isValid }
        var aggregated: [AggregationKey: GeneratedShoppingEntry] = [:]
        var standalone: [GeneratedShoppingEntry] = []

        func add(itemID: UUID, unit source: UnitDefinition, quantity: Double) throws {
            guard let item = input.items[itemID] else { throw Failure.missingMealComponentReference }
            guard DomainValidation.isPositiveFinite(quantity) else { throw Failure.invalidQuantity }
            guard source.isValid else { throw Failure.incompatibleUnits }
            let output: UnitDefinition
            let amount: Double
            if source.type == .count {
                output = source
                amount = quantity
            } else {
                let preferredID = source.type == .weight ? input.preferredWeightID : input.preferredVolumeID
                guard let preferred = input.units[preferredID], preferred.type == source.type,
                      let converted = source.convert(quantity, to: preferred) else {
                    throw Failure.incompatibleUnits
                }
                output = preferred
                amount = converted
            }
            guard DomainValidation.isPositiveFinite(amount) else { throw Failure.invalidQuantity }
            let key = AggregationKey(itemID: itemID, unitID: output.id)
            if var entry = aggregated[key] {
                entry.quantity += amount
                guard DomainValidation.isPositiveFinite(entry.quantity) else { throw Failure.invalidQuantity }
                aggregated[key] = entry
            } else {
                aggregated[key] = GeneratedShoppingEntry(
                    name: item.name, quantity: amount, itemID: itemID,
                    categoryID: item.category.id, categoryOrder: item.category.order, unitID: output.id
                )
            }
        }

        for meal in input.meals {
            guard meal.servings > 0 else { throw Failure.invalidQuantity }
            for component in meal.components {
                switch component.source {
                case .recipe(let id):
                    guard let recipe = input.recipes[id] else { throw Failure.missingMealComponentReference }
                    guard recipe.servings > 0 else { throw Failure.invalidRecipe(recipe.name) }
                    guard component.hasValidPortion else { throw Failure.invalidRecipeIngredient(recipe.name) }
                    let ingredients: [IngredientResolver.ResolvedIngredient]
                    do {
                        ingredients = try resolver.resolve(recipe.ingredients, overrides: component.ingredientOverrides)
                    } catch IngredientResolver.Error.invalidQuantity {
                        throw Failure.invalidRecipeIngredient(recipe.name)
                    } catch {
                        throw Failure.missingMealComponentReference
                    }
                    let scale = Double(meal.servings) / Double(recipe.servings)
                    for ingredient in ingredients {
                        try add(itemID: ingredient.itemID, unit: ingredient.unit, quantity: ingredient.quantity * scale)
                    }
                case .readymeal(let id):
                    guard let item = input.items[id], item.kind == .readymeal else {
                        throw Failure.missingMealComponentReference
                    }
                    guard component.hasValidPortion else { throw Failure.invalidQuantity }
                    guard let servings = item.servings, servings > 0 else { throw Failure.invalidRecipe(item.name) }
                    guard let countUnit else { throw Failure.missingCountUnit }
                    try add(itemID: id, unit: countUnit, quantity: ceil(Double(meal.servings) / Double(servings)))
                case .ingredient(let id):
                    guard let item = input.items[id], let unitID = component.unitID,
                          let unit = input.units[unitID], unit.isValid else {
                        throw Failure.missingMealComponentReference
                    }
                    guard item.kind == .ingredient else { throw Failure.invalidMealIngredientItem(item.name) }
                    guard component.hasValidPortion, let quantity = component.quantity else {
                        throw Failure.invalidMealIngredient(item.name)
                    }
                    let scaled = quantity * Double(meal.servings)
                    guard DomainValidation.isPositiveFinite(scaled) else { throw Failure.invalidMealIngredient(item.name) }
                    try add(itemID: id, unit: unit, quantity: scaled)
                }
            }
        }

        for entry in input.miscellaneous {
            guard let category = entry.category, let unitID = entry.unitID,
                  let unit = input.units[unitID], unit.isValid,
                  DomainValidation.isPositiveFinite(entry.quantity) else {
                throw Failure.incompleteMiscEntry(entry.name.isEmpty ? "A miscellaneous entry" : entry.name)
            }
            if let itemID = entry.itemID {
                try add(itemID: itemID, unit: unit, quantity: entry.quantity)
            } else {
                standalone.append(GeneratedShoppingEntry(name: entry.name, quantity: entry.quantity, itemID: nil,
                    categoryID: category.id, categoryOrder: category.order, unitID: unit.id))
            }
        }

        return (Array(aggregated.values) + standalone).sorted {
            if $0.categoryOrder != $1.categoryOrder { return $0.categoryOrder < $1.categoryOrder }
            let comparison = $0.name.localizedCaseInsensitiveCompare($1.name)
            if comparison != .orderedSame { return comparison == .orderedAscending }
            // Equal labels must not inherit dictionary iteration order.
            if $0.unitID != $1.unitID { return $0.unitID.uuidString < $1.unitID.uuidString }
            return ($0.itemID?.uuidString ?? "") < ($1.itemID?.uuidString ?? "")
        }
    }
}
