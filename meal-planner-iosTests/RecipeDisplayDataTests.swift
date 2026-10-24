import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct RecipeDisplayDataTests {
    @Test func substitutionsAreScaledIndependentlyForEachOccurrenceWithoutChangingSavedData() throws {
        let fixture = Fixture()
        let context = try makeTestContext(autosaveEnabled: false)
        context.insert(fixture.recipe)
        context.insert(fixture.substitute)
        context.insert(fixture.kilograms)
        let first = MealComponent(recipe: fixture.recipe)
        first.ingredientOverrides = [fixture.override(quantity: 0.4)]
        let second = MealComponent(recipe: fixture.recipe)
        second.ingredientOverrides = [fixture.override(quantity: 0.8)]
        let plan = PlannedMeal(mealType: .lunch, servings: 2, components: [first, second])
        context.insert(plan)
        try context.save()

        let firstDisplay = fixture.display(component: MealComponentDraft(component: first), servings: plan.servings)
        let secondDisplay = fixture.display(component: MealComponentDraft(component: second), servings: plan.servings)
        let originalDisplay = fixture.display(servings: plan.servings)

        #expect(firstDisplay.servings == 2)
        #expect(firstDisplay.hasSubstitutions)
        // Ingredient relationships have no persisted order; substitutions are keyed by identity.
        let firstNames = Dictionary(uniqueKeysWithValues: firstDisplay.ingredients.map { ($0.id, $0.name) })
        let firstQuantities = Dictionary(uniqueKeysWithValues: firstDisplay.ingredients.map { ($0.id, $0.quantity) })
        let secondQuantities = Dictionary(uniqueKeysWithValues: secondDisplay.ingredients.map { ($0.id, $0.quantity) })
        let originalQuantities = Dictionary(uniqueKeysWithValues: originalDisplay.ingredients.map { ($0.id, $0.quantity) })
        #expect(firstNames == [fixture.firstIngredient.id: "Parsnip", fixture.secondIngredient.id: "Carrot"])
        #expect(firstQuantities == [fixture.firstIngredient.id: "0.2kg", fixture.secondIngredient.id: "25g"])
        #expect(secondQuantities == [fixture.firstIngredient.id: "0.4kg", fixture.secondIngredient.id: "25g"])
        #expect(originalQuantities == [fixture.firstIngredient.id: "50g", fixture.secondIngredient.id: "25g"])
        #expect(!originalDisplay.hasSubstitutions)
        #expect(!context.hasChanges)

        let verification = ModelContext(context.container)
        let saved = try #require(verification.fetch(Recipie.descriptor(id: fixture.recipe.id)).first)
        #expect(saved.serves == 4)
        #expect(saved.ingredients.first { $0.id == fixture.firstIngredient.id }?.item.id == fixture.original.id)
        #expect(saved.ingredients.first { $0.id == fixture.firstIngredient.id }?.unit.id == fixture.grams.id)
        #expect(saved.ingredients.first { $0.id == fixture.firstIngredient.id }?.quantity == 100)
        let savedPlan = try #require(verification.fetch(PlannedMeal.descriptor(id: plan.id)).first)
        #expect(savedPlan.orderedComponents.map { $0.ingredientOverrides?.first?.quantity } == [0.4, 0.8])
    }

    @Test func existingContentIsPreservedAndBlankStepsAreExcluded() {
        let fixture = Fixture()
        fixture.recipe.summary = "A simple vegetable stew."
        fixture.recipe.steps = ["", " \n\t", "Peel the vegetables.", "\nSimmer until tender.\n"]
        let display = fixture.display()

        #expect(display.name == "Vegetable stew")
        #expect(display.summary == "A simple vegetable stew.")
        #expect(display.servings == 4)
        #expect(display.time == 45)
        #expect(display.steps == ["Peel the vegetables.", "\nSimmer until tender.\n"])
        #expect(fixture.recipe.steps.count == 4)
    }

    @Test func absentContentStaysEmpty() {
        let recipe = Recipie(name: "Undocumented recipe", summary: " \n\t", time: -1, steps: ["", " \n"])
        let display = RecipeDisplayData(recipe: recipe, items: [], units: [])

        #expect(display.summary.isEmpty)
        #expect(display.ingredients.isEmpty)
        #expect(display.steps.isEmpty)
        #expect(display.time == -1)
    }

    @Test func missingCatalogueEntriesUseOriginalReferencesOrExplicitFallbacks() {
        let fixture = Fixture()
        let original = RecipeDisplayData(recipe: fixture.recipe, items: [], units: [])
        #expect(original.ingredients.map(\.name) == ["Carrot", "Carrot"])
        #expect(original.ingredients.map(\.quantity) == ["100g", "50g"])

        let missing = RecipeIngredientOverride(ingredient: RecipieIngredientDraft(
            id: fixture.firstIngredient.id, itemID: UUID(), unitID: UUID(), quantity: 200
        ))
        let component = MealComponentDraft(source: .recipe(fixture.recipe.id), ingredientOverrides: [missing])
        let display = RecipeDisplayData(recipe: fixture.recipe, component: component, items: [], units: [])
        #expect(display.ingredients[0].id == fixture.firstIngredient.id)
        #expect(display.ingredients[0].name == "Missing ingredient")
        #expect(display.ingredients[0].quantity == "Missing unit")
        #expect(display.ingredients[1].name == "Carrot")
        #expect(display.ingredients[1].quantity == "50g")
    }

    @Test(arguments: [0.0, -1.0, Double.nan, Double.infinity])
    func invalidQuantitiesAreNotPresentedAsUsableAmounts(quantity: Double) {
        let fixture = Fixture()
        let component = MealComponentDraft(
            source: .recipe(fixture.recipe.id), ingredientOverrides: [fixture.override(quantity: quantity)]
        )
        let display = fixture.display(component: component, servings: 2)

        #expect(display.ingredients[0].quantity == "Quantity unavailable")
        #expect(display.ingredients[1].quantity == "25g")
    }

    @Test func invalidServingsUseSafeDisplayAndScalingFallbacks() {
        let fixture = Fixture()
        let clamped = fixture.display(servings: 0)
        #expect(clamped.servings == 1)
        #expect(clamped.ingredients[0].quantity == "25g")

        fixture.recipe.serves = 0
        let defaultServings = fixture.display()
        let plannedServings = fixture.display(servings: 3)
        #expect(defaultServings.servings == 1)
        #expect(plannedServings.servings == 3)
        #expect(defaultServings.ingredients[0].quantity == "100g")
        #expect(plannedServings.ingredients[0].quantity == "100g")
    }

    @MainActor private final class Fixture {
        let original = Item(name: "Carrot", category: .init(name: "Produce", order: 0), kind: .ingredient)
        let substitute = Item(name: "Parsnip", category: .init(name: "Substitutes", order: 1), kind: .ingredient)
        let grams = meal_planner_ios.Unit(name: "grams", type: .weight, magnitudes: [
            Magnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1)
        ])
        let kilograms = meal_planner_ios.Unit(name: "kilograms", type: .weight, base: 1_000, magnitudes: [
            Magnitude(abbreviation: "kg", singular: "kilogram", plural: "kilograms", multiplier: 1)
        ])
        lazy var firstIngredient = RecipieIngredient(item: original, unit: grams, quantity: 100)
        lazy var secondIngredient = RecipieIngredient(item: original, unit: grams, quantity: 50)
        lazy var recipe = Recipie(name: "Vegetable stew", serves: 4, time: 45,
                                 ingredients: [firstIngredient, secondIngredient])

        func override(quantity: Double) -> RecipeIngredientOverride {
            RecipeIngredientOverride(ingredient: RecipieIngredientDraft(
                id: firstIngredient.id, itemID: substitute.id, unitID: kilograms.id, quantity: quantity
            ))
        }

        func display(component: MealComponentDraft? = nil, servings: Int? = nil) -> RecipeDisplayData {
            RecipeDisplayData(recipe: recipe, component: component, servings: servings,
                              items: [original, substitute], units: [grams, kilograms])
        }
    }
}
