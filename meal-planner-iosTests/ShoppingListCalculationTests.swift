import Foundation
import Testing
@testable import meal_planner_ios

struct ShoppingListCalculationTests {
    @Test(arguments: [1, 2, 5], [1, 2, 4])
    func recipeAndDirectPortionsScaleBeforeAggregation(servings: Int, yield: Int) throws {
        var fixture = Fixture()
        let recipeID = UUID()
        fixture.input.recipes[recipeID] = .init(name: "Soup", servings: yield, ingredients: [
            .init(itemID: fixture.apple, unitID: fixture.grams.id, quantity: 100)
        ])
        fixture.input.meals = [.init(servings: servings, components: [
            .init(source: .recipe(recipeID)),
            .init(source: .ingredient(fixture.apple), quantity: 50, unitID: fixture.grams.id)
        ])]
        let entry = try #require(ShoppingListCalculator.generate(from: fixture.input).first)
        #expect(entry.quantity == Double(servings) * (100 / Double(yield) + 50))
        #expect(entry.itemID == fixture.apple)
    }

    @Test func conversionsMergeByItemAndDimensionWhileCountUnitsStayDistinct() throws {
        var fixture = Fixture()
        let kilograms = UnitDefinition(id: UUID(), name: "kilograms", type: .weight, base: 1000, magnitudes: [])
        let loaves = UnitDefinition(id: UUID(), name: "loaves", type: .count, base: 1, magnitudes: [])
        fixture.input.units[kilograms.id] = kilograms
        fixture.input.units[loaves.id] = loaves
        fixture.input.meals = [.init(servings: 2, components: [
            .init(source: .ingredient(fixture.apple), quantity: 0.5, unitID: kilograms.id),
            .init(source: .ingredient(fixture.apple), quantity: 100, unitID: fixture.grams.id),
            .init(source: .ingredient(fixture.apple), quantity: 1, unitID: fixture.count.id),
            .init(source: .ingredient(fixture.apple), quantity: 0.5, unitID: loaves.id),
            .init(source: .ingredient(fixture.apple), quantity: 0.25, unitID: fixture.litres.id)
        ])]
        fixture.input.miscellaneous = [.init(name: "Apples", itemID: fixture.apple, category: fixture.category,
                                             unitID: kilograms.id, quantity: 1)]
        let entries = try ShoppingListCalculator.generate(from: fixture.input)
        #expect(entries.count == 4)
        let quantities = Dictionary(uniqueKeysWithValues: entries.map { ($0.unitID, $0.quantity) })
        #expect(quantities[fixture.grams.id] == 2200)
        #expect(quantities[fixture.count.id] == 2)
        #expect(quantities[loaves.id] == 1)
        #expect(quantities[fixture.litres.id] == 0.5)
        fixture.input.meals[0].components.reverse()
        #expect(try ShoppingListCalculator.generate(from: fixture.input) == entries)
    }

    @Test func overridesApplyOnlyToTheirOwnOccurrenceAndNotesRemainStandalone() throws {
        var fixture = Fixture()
        let replacement = UUID()
        fixture.input.items[replacement] = .init(name: "Pears", kind: .ingredient, category: fixture.category)
        let recipeID = UUID()
        let ingredient = RecipieIngredientDraft(itemID: fixture.apple, unitID: fixture.count.id, quantity: 4)
        fixture.input.recipes[recipeID] = .init(name: "Fruit", servings: 2, ingredients: [ingredient])
        var changed = ingredient
        changed.itemID = replacement
        changed.quantity = 6
        fixture.input.meals = [.init(servings: 1, components: [
            .init(source: .recipe(recipeID)),
            .init(source: .recipe(recipeID), ingredientOverrides: [.init(ingredient: changed)])
        ])]
        fixture.input.miscellaneous = [.init(name: "Apples", itemID: nil, category: fixture.category,
                                             unitID: fixture.count.id, quantity: 10)]
        let entries = try ShoppingListCalculator.generate(from: fixture.input)
        #expect(entries.count == 3)
        #expect(entries.first { $0.itemID == fixture.apple }?.quantity == 2)
        #expect(entries.first { $0.itemID == replacement }?.quantity == 3)
        #expect(entries.first { $0.itemID == nil }?.quantity == 10)
        #expect(fixture.input.recipes[recipeID]?.ingredients == [ingredient])
    }

    @Test(arguments: [1, 2, 3, 5])
    func readyMealsRoundUpPerPlannedOccurrence(servings: Int) throws {
        var fixture = Fixture()
        let item = UUID()
        fixture.input.items[item] = .init(name: "Ready meal", kind: .readymeal, category: fixture.category, servings: 2)
        fixture.input.meals = [.init(servings: servings, components: [
            .init(source: .readymeal(item)), .init(source: .readymeal(item))
        ])]
        #expect(try ShoppingListCalculator.generate(from: fixture.input).first?.quantity == 2 * ceil(Double(servings) / 2))
    }

    @Test(arguments: [0, -1, Double.nan, Double.infinity, -Double.infinity])
    func invalidPortionsCannotProduceAList(quantity: Double) throws {
        var fixture = Fixture()
        fixture.input.meals = [.init(servings: 1, components: [
            .init(source: .ingredient(fixture.apple), quantity: quantity, unitID: fixture.count.id)
        ])]
        #expect(throws: ShoppingListError.self) { try ShoppingListCalculator.generate(from: fixture.input) }
    }

    @Test func incompatiblePreferencesAndOverflowAreRejected() throws {
        var fixture = Fixture()
        fixture.input.preferredWeightID = fixture.litres.id
        fixture.input.meals = [.init(servings: 1, components: [
            .init(source: .ingredient(fixture.apple), quantity: 1, unitID: fixture.grams.id)
        ])]
        #expect(throws: ShoppingListError.self) { try ShoppingListCalculator.generate(from: fixture.input) }
        fixture.input.preferredWeightID = fixture.grams.id
        let huge = MealComponentDraft(source: .ingredient(fixture.apple), quantity: .greatestFiniteMagnitude,
                                      unitID: fixture.count.id)
        fixture.input.meals[0].components = [huge, huge]
        #expect(throws: ShoppingListError.self) { try ShoppingListCalculator.generate(from: fixture.input) }
    }

    private struct Fixture {
        let apple = UUID()
        let category = ShoppingListInput.Category(id: UUID(), order: 0)
        let count = UnitDefinition(id: UUID(), name: "count", type: .count, base: 1, magnitudes: [])
        let grams = UnitDefinition(id: UUID(), name: "grams", type: .weight, base: 1, magnitudes: [])
        let litres = UnitDefinition(id: UUID(), name: "litres", type: .volume, base: 1, magnitudes: [])
        var input: ShoppingListInput

        init() {
            input = .init(units: Dictionary(uniqueKeysWithValues: [count, grams, litres].map { ($0.id, $0) }),
                          items: [apple: .init(name: "Apples", kind: .ingredient, category: category)],
                          preferredWeightID: grams.id, preferredVolumeID: litres.id)
        }
    }
}
