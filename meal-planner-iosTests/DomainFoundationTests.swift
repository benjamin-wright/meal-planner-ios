import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

struct DomainFoundationTests {
    @Test(arguments: [0.0, -1.0, Double.nan, Double.infinity, -Double.infinity])
    func nonPositiveOrNonFiniteValuesAreRejectedAtDomainBoundaries(value: Double) {
        #expect(!DomainValidation.isPositiveFinite(value))
        var recipe = RecipieDraft()
        recipe.name = "Valid recipe"
        recipe.ingredients = [RecipieIngredientDraft(itemID: UUID(), unitID: UUID(), quantity: value)]
        #expect(recipe.validate().contains(.invalidIngredientQuantity))

        var unit = UnitDraft(type: .weight)
        unit.name = "Valid unit"
        unit.base = value
        unit.magnitudes = [Magnitude(singular: "unit", plural: "units", multiplier: 1)]
        #expect(unit.validate().contains(.nonPositiveBase))
        unit.base = 1
        unit.magnitudes[0].multiplier = value
        #expect(unit.validate().contains(.invalidMagnitude))
    }

    @Test(arguments: [0, -1])
    func recipesAndReadyMealsRequirePositiveYields(servings: Int) {
        var recipe = RecipieDraft()
        recipe.name = "Valid recipe"
        recipe.serves = servings
        #expect(recipe.validate().contains(.invalidServings))
        var item = ItemDraft(categoryID: UUID(), kind: .readymeal)
        item.name = "Ready meal"
        item.readymealData.serves = servings
        #expect(item.validate().contains(.invalidServings))
        item.kind = .ingredient
        #expect(!item.validate().contains(.invalidServings))
    }

    @Test func ingredientResolutionUsesSourceIdentityAndRejectsInvalidReferences() throws {
        let originalID = UUID(), replacementID = UUID(), unitID = UUID()
        let unit = UnitDefinition(id: unitID, name: "grams", type: .weight, base: 1, magnitudes: [])
        let resolver = IngredientResolver(itemKinds: [originalID: .ingredient, replacementID: .ingredient],
                                          units: [unitID: unit])
        let original = RecipieIngredientDraft(itemID: originalID, unitID: unitID, quantity: 100)
        let replacement = RecipieIngredientDraft(id: original.id, itemID: replacementID,
                                                 unitID: unitID, quantity: 250)
        let overrides = [RecipeIngredientOverride(ingredient: replacement)]
        let resolved = try #require(resolver.resolve([original], overrides: overrides).first)
        #expect(resolved.id == original.id)
        #expect(resolved.itemID == replacementID)
        #expect(resolved.quantity == 250)
        #expect(original.itemID == originalID)
        #expect(try resolver.resolve([original]).first?.quantity == 100)
        #expect(throws: IngredientResolver.Error.invalidOverride) {
            try resolver.resolve([], overrides: overrides)
        }
        #expect(throws: IngredientResolver.Error.invalidOverride) {
            try resolver.resolve([original], overrides: overrides + overrides)
        }
        #expect(throws: IngredientResolver.Error.duplicateIngredient) {
            try resolver.resolve([original, original])
        }
        #expect(IngredientResolver.retaining(overrides, ingredientIDs: []).isEmpty)
    }

    @Test(arguments: InvalidIngredient.allCases)
    func ingredientResolutionHasTheSameRulesForEveryConsumer(invalid: InvalidIngredient) {
        let itemID = UUID(), unitID = UUID()
        var kinds: [UUID: ItemKind] = [itemID: .ingredient]
        var unit = UnitDefinition(id: unitID, name: "grams", type: .weight, base: 1, magnitudes: [])
        var ingredient = RecipieIngredientDraft(itemID: itemID, unitID: unitID, quantity: 100)
        var units: [UUID: UnitDefinition] = [:]
        let error: IngredientResolver.Error
        switch invalid {
        case .missingItem: kinds = [:]; error = .missingItem
        case .readymeal: kinds[itemID] = .readymeal; error = .invalidItemKind
        case .misc: kinds[itemID] = .misc; error = .invalidItemKind
        case .missingUnit: ingredient.unitID = UUID(); error = .missingUnit
        case .invalidBase: unit.base = .infinity; error = .invalidUnit
        case .invalidQuantity: ingredient.quantity = .nan; error = .invalidQuantity
        }
        units[unitID] = unit
        #expect(throws: error) { try IngredientResolver(itemKinds: kinds, units: units).resolve(ingredient) }
    }

    enum InvalidIngredient: CaseIterable { case missingItem, readymeal, misc, missingUnit, invalidBase, invalidQuantity }

    @Test func unitValuesKeepCalculationFormattingAndDefaultSelectionTogether() {
        let grams = UnitDefinition(id: UUID(), name: "grams", type: .weight, base: 1, magnitudes: [
            Magnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1),
            Magnitude(abbreviation: "kg", singular: "kilogram", plural: "kilograms", multiplier: 1000)
        ])
        let kilos = UnitDefinition(id: UUID(), name: "kilograms", type: .weight, base: 1000, magnitudes: [])
        let count = UnitDefinition(id: UUID(), name: "count", type: .count, base: 1, magnitudes: [])
        let loaves = UnitDefinition(id: UUID(), name: "loaves", type: .count, base: 1, magnitudes: [])
        #expect(grams.convert(2500, to: kilos) == 2.5)
        #expect(kilos.convert(2.5, to: grams) == 2500)
        #expect(grams.convert(1, to: count) == nil)
        #expect(count.convert(1, to: loaves) == nil)
        #expect(grams.toString(forValue: 2500) == "2.5kg")
        #expect(UnitDefinition.defaultForNewObject(in: [grams, loaves, count])?.id == count.id)
    }

    @Test(arguments: Day.allCases, Day.allCases)
    func dinnerMovementPreservesEveryOccupancyCombination(source: Day, destination: Day) {
        let ids = Day.allCases.map { _ in UUID() }
        let sourceIndex = Day.allCases.firstIndex(of: source)!
        let destinationIndex = Day.allCases.firstIndex(of: destination)!
        for mask in 0..<(1 << Day.allCases.count) {
            let initial = Dictionary(uniqueKeysWithValues: Day.allCases.enumerated().compactMap { index, day in
                mask & (1 << index) == 0 ? nil : (day, ids[index])
            })
            var slots = DinnerSlots(meals: initial)
            slots.move(from: source, to: destination)
            #expect(slots.meals[destination] == initial[source])
            #expect(Set(slots.meals.values) == Set(initial.values))
            let remainingBefore = Day.allCases.filter { $0 != source }.map { initial[$0] }
            let remainingAfter = Day.allCases.filter { $0 != destination }.map { slots.meals[$0] }
            #expect(remainingAfter == remainingBefore)
            for (index, day) in Day.allCases.enumerated()
                where index < min(sourceIndex, destinationIndex) || index > max(sourceIndex, destinationIndex) {
                #expect(slots.meals[day] == initial[day])
            }
            slots.move(from: destination, to: source)
            #expect(slots.meals == initial)
        }
    }

    @MainActor
    @Test func duplicateDinnerAndIngredientOwnershipAreRejectedBeforeMutation() throws {
        let context = try makeTestContext(autosaveEnabled: false)
        let category = Category(name: "Food", order: 0)
        let item = Item(name: "Carrot", category: category, kind: .ingredient)
        let unit = meal_planner_ios.Unit(name: "count", type: .count, magnitudes: [])
        let ingredient = RecipieIngredient(item: item, unit: unit, quantity: 2)
        let recipe = Recipie(name: "Carrot soup", ingredients: [ingredient])
        context.insert(recipe)
        try context.save()
        let store = PlannedMealStore(context: context)
        func draft() -> PlannedMealDraft {
            PlannedMealDraft(components: [MealComponentDraft(source: .recipe(recipe.id))])
        }
        try store.save(draft(), id: nil, mealType: .dinner, day: .monday)
        #expect(throws: PlannedMealStore.Error.self) {
            try store.save(draft(), id: nil, mealType: .dinner, day: .monday)
        }
        #expect(!context.hasChanges)
        #expect(try context.fetch(FetchDescriptor<PlannedMeal>()).count == 1)
        var copiedRecipe = RecipieDraft(recipie: recipe)
        copiedRecipe.name = "Another recipe"
        #expect(throws: RecipieStore.Error.self) {
            try RecipieStore(context: context).save(copiedRecipe, id: nil)
        }
        #expect(!context.hasChanges)
        #expect(try context.fetch(FetchDescriptor<RecipieIngredient>()).count == 1)
    }

    @MainActor
    @Test func recipeReferencesPreventInvalidKindsButAllowRepairingLegacyItems() throws {
        let context = try makeTestContext(autosaveEnabled: false)
        let item = Item(name: "Carrot", category: Category(name: "Food", order: 0), kind: .ingredient)
        let ingredient = RecipieIngredient(item: item,
                                          unit: meal_planner_ios.Unit(name: "count", type: .count, magnitudes: []),
                                          quantity: 2)
        context.insert(Recipie(name: "Carrot soup", ingredients: [ingredient]))
        try context.save()
        var draft = ItemDraft(item: item)
        draft.kind = .misc
        #expect(throws: ItemStore.Error.self) { try ItemStore(context: context).save(draft, id: item.id) }
        #expect(item.itemKind == .ingredient)
        #expect(!context.hasChanges)

        // Older stores allowed non-ingredient items in recipes. Correcting one must remain possible.
        item.kind = ItemKind.misc.rawValue
        try context.save()
        draft = ItemDraft(item: item)
        draft.kind = .ingredient
        try ItemStore(context: context).save(draft, id: item.id)
        let persisted = try #require(ModelContext(context.container).fetch(Item.descriptor(id: item.id)).first)
        #expect(persisted.itemKind == .ingredient)
    }
}
