import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct MealComponentOrderTests {
    @Test func coursesDetermineDisplayOrderAndExistingPositionsOrderEachCourse() {
        let firstSide = MealComponent(recipe: Recipie(name: "Zulu side"), course: .side)
        let main = MealComponent(recipe: Recipie(name: "Main dish"), course: .main)
        let secondSide = MealComponent(recipe: Recipie(name: "Alpha side"), course: .side)
        let starter = MealComponent(recipe: Recipie(name: "Starter"), course: .starter)
        let meal = Meal(name: "Dinner", mealType: .dinner,
                        components: [firstSide, main, secondSide, starter])
        let expectedIDs = [starter.id, main.id, firstSide.id, secondSide.id]
        #expect(meal.orderedComponents.map(\.id) == expectedIDs)
        #expect(meal.orderedComponents.map(\.sortOrder) == [3, 1, 0, 2])

        // SwiftData relationship order must not replace the stored order within a course.
        meal.components.reverse()
        #expect(meal.orderedComponents.map(\.id) == expectedIDs)
        let planned = PlannedMeal(mealType: .dinner,
                                  components: meal.orderedComponents.map { MealComponent(copying: $0) })
        #expect(planned.orderedComponents.map(\.source) == meal.orderedComponents.map(\.source))
        #expect(planned.displayName == "Main dish, Zulu side, Alpha side")
    }

    @Test func changingCoursesPersistsWithoutLosingPortionsOverridesOrIndependentOccurrences() throws {
        let context = try makeTestContext()
        let count = meal_planner_ios.Unit(name: "count", type: .count, magnitudes: [])
        let apple = Item(name: "Apple", category: Category(name: "Food", order: 0), kind: .ingredient)
        let readymeal = Item(name: "Beans", category: apple.category, kind: .readymeal,
                             readymealData: ReadymealData(serves: 1, time: 3))
        let ingredient = RecipieIngredient(item: apple, unit: count, quantity: 1)
        let recipe = Recipie(name: "Apple dish", ingredients: [ingredient])
        context.insert(recipe)
        context.insert(readymeal)
        try context.save()

        let ordinary = MealComponentDraft(source: .recipe(recipe.id), course: .side)
        var modified = MealComponentDraft(source: .recipe(recipe.id), course: .dessert)
        var replacement = RecipieIngredientDraft(ingredient: ingredient)
        replacement.quantity = 2
        modified.updateIngredient(replacement, in: recipe)
        let portion = MealComponentDraft(source: .ingredient(apple.id), course: .starter,
                                         quantity: 0.5, unitID: count.id)
        let ready = MealComponentDraft(source: .readymeal(readymeal.id), course: .main)
        var draft = MealDraft(mealType: .lunch)
        draft.name = "Course ordered lunch"
        draft.components = [ordinary, portion, modified, ready]
        let templateID = try MealStore(context: context).save(draft, id: nil)

        let editing = ModelContext(context.container)
        let template = try #require(editing.fetch(Meal.descriptor(id: templateID)).first)
        let original = [portion, ready, ordinary, modified]
        #expect(try MealStore(context: editing).draft(id: templateID).components == original)
        var plan = PlannedMealDraft(meal: template)
        #expect(Set(plan.components.map(\.id)).isDisjoint(with: original.map(\.id)))
        let plannedStore = PlannedMealStore(context: editing)
        try plannedStore.save(plan, id: nil, mealType: .lunch, day: nil)
        let plannedID = try #require(editing.fetch(FetchDescriptor<PlannedMeal>()).first?.id)
        plan = try plannedStore.draft(id: plannedID)
        let plannedPortionID = plan.components[0].id
        let plannedModifiedID = plan.components[3].id
        plan.components[0].course = .dessert
        plan.components[3].course = .main
        let expected = [plan.components[1], plan.components[3], plan.components[2], plan.components[0]]
        try plannedStore.save(plan, id: plannedID, mealType: .lunch, day: nil)

        let verification = ModelContext(context.container)
        let reloaded = try PlannedMealStore(context: verification).draft(id: plannedID)
        #expect(reloaded.components == expected)
        #expect(reloaded.components.first { $0.id == plannedPortionID }?.quantity == 0.5)
        #expect(reloaded.components.first { $0.id == plannedPortionID }?.unitID == count.id)
        #expect(reloaded.components.first { $0.id == plannedModifiedID }?.ingredientOverrides == modified.ingredientOverrides)
        let occurrences = reloaded.components.filter { $0.source == .recipe(recipe.id) }
        #expect(occurrences.count == 2)
        #expect(Set(occurrences.map(\.id)).count == 2)
        #expect(occurrences.first { $0.id != plannedModifiedID }?.ingredientOverrides.isEmpty == true)
        #expect(try MealStore(context: verification).draft(id: templateID).components == original)
        let persistedPlan = try #require(verification.fetch(PlannedMeal.descriptor(id: plannedID)).first)
        #expect(persistedPlan.displayName == "Beans, Apple dish*, Apple dish")
    }
}
