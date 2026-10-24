import Foundation

enum DomainValidation {
    static func isPositiveFinite(_ value: Double) -> Bool {
        value > 0 && value.isFinite
    }
}

/// Resolves ingredient values independently of editors and persistence.
struct IngredientResolver {
    enum Error: LocalizedError, Equatable {
        case invalidQuantity
        case missingItem
        case invalidItemKind
        case missingUnit
        case invalidUnit
        case invalidOverride
        case duplicateIngredient

        var errorDescription: String? {
            switch self {
            case .invalidQuantity:
                return "Ingredient quantities must be finite and greater than zero."
            case .missingItem, .invalidItemKind:
                return "Choose an existing ingredient item."
            case .missingUnit, .invalidUnit:
                return "Choose a valid unit for the ingredient."
            case .invalidOverride:
                return "A substitution must refer to an existing ingredient in this recipe."
            case .duplicateIngredient:
                return "Each recipe ingredient must have its own identifier."
            }
        }
    }

    struct ResolvedIngredient {
        let id: UUID
        let itemID: UUID
        let unit: UnitDefinition
        let quantity: Double
    }

    let itemKinds: [UUID: ItemKind]
    let units: [UUID: UnitDefinition]

    init(itemKinds: [UUID: ItemKind], units: [UUID: UnitDefinition]) {
        self.itemKinds = itemKinds
        self.units = units
    }

    init(items: [Item], units: [Unit]) {
        self.init(
            itemKinds: Dictionary(uniqueKeysWithValues: items.compactMap { item in
                ItemKind(rawValue: item.kind).map { (item.id, $0) }
            }),
            units: Dictionary(uniqueKeysWithValues: units.compactMap { unit in
                unit.definition.map { (unit.id, $0) }
            })
        )
    }

    func resolve(_ ingredient: RecipieIngredientDraft) throws -> ResolvedIngredient {
        guard DomainValidation.isPositiveFinite(ingredient.quantity) else { throw Error.invalidQuantity }
        guard let kind = itemKinds[ingredient.itemID] else { throw Error.missingItem }
        guard kind == .ingredient else { throw Error.invalidItemKind }
        guard let unit = units[ingredient.unitID] else { throw Error.missingUnit }
        guard unit.isValid else { throw Error.invalidUnit }
        return ResolvedIngredient(id: ingredient.id, itemID: ingredient.itemID,
                                  unit: unit, quantity: ingredient.quantity)
    }

    func resolve(
        _ ingredients: [RecipieIngredientDraft],
        overrides: [RecipeIngredientOverride] = []
    ) throws -> [ResolvedIngredient] {
        let ingredientIDs = Set(ingredients.map(\.id))
        guard ingredientIDs.count == ingredients.count else { throw Error.duplicateIngredient }
        guard Set(overrides.map(\.id)).count == overrides.count,
              overrides.allSatisfy({ ingredientIDs.contains($0.id) }) else { throw Error.invalidOverride }
        return try Self.applying(overrides, to: ingredients).map(resolve)
    }

    static func applying(
        _ overrides: [RecipeIngredientOverride], to ingredients: [RecipieIngredientDraft]
    ) -> [RecipieIngredientDraft] {
        // The first override wins only for displaying an invalid draft; resolve rejects duplicates.
        let replacements = Dictionary(overrides.map { ($0.id, $0.draft) }, uniquingKeysWith: { first, _ in first })
        return ingredients.map { replacements[$0.id] ?? $0 }
    }

    static func retaining(
        _ overrides: [RecipeIngredientOverride], ingredientIDs: Set<UUID>
    ) -> [RecipeIngredientOverride] {
        overrides.filter { ingredientIDs.contains($0.id) }
    }
}
