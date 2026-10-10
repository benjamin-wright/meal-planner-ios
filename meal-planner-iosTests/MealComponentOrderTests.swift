import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct MealComponentOrderTests {
    @Test func savedMealsReloadTheChosenOrderInsteadOfRelationshipOrNameOrder() throws {
        let fixture = try makeFixture()
        let meal = try saveTemplate(fixture)
        let editingContext = ModelContext(fixture.context.container)
        let store = MealStore(context: editingContext)
        var draft = try store.draft(id: meal.id)
        let original = draft.components
        draft.components = [original[2], original[0], original[3], original[1]]
        try store.save(draft, id: meal.id)

        let verification = ModelContext(fixture.context.container)
        let persisted = try #require(verification.fetch(Meal.descriptor(id: meal.id)).first)
        #expect(persisted.orderedComponents.map(\.id) == draft.components.map(\.id))
        #expect(persisted.orderedComponents.map(\.sortOrder) == [0, 1, 2, 3])
        #expect(try MealStore(context: verification).draft(id: meal.id).components == draft.components)

        // Relationship storage order must not override the explicit positions.
        persisted.components.reverse()
        try verification.save()
        let reloadedContext = ModelContext(fixture.context.container)
        let reloaded = try MealStore(context: reloadedContext).draft(id: meal.id)
        #expect(reloaded.components == draft.components)
        #expect(reloaded.components.filter { $0.course == .side }.map(\.id)
                == draft.components.filter { $0.course == .side }.map(\.id))
    }

    @Test func movingBetweenCoursesAndCopyingPreservesPositionsWithoutChangingTheTemplate() throws {
        let fixture = try makeFixture()
        let template = try saveTemplate(fixture)
        let originalDraft = try MealStore(context: fixture.context).draft(id: template.id)
        let planDraft = PlannedMealDraft(meal: template)
        #expect(planDraft.components.map(\.source) == originalDraft.components.map(\.source))
        #expect(Set(planDraft.components.map(\.id)).isDisjoint(with: originalDraft.components.map(\.id)))
        let plannedStore = PlannedMealStore(context: fixture.context)
        try plannedStore.save(planDraft, id: nil, mealType: .lunch, day: nil, sourceMealID: template.id)
        let planned = try #require(fixture.context.fetch(FetchDescriptor<PlannedMeal>()).first)

        var moved = try plannedStore.draft(id: planned.id)
        let ingredientIndex = try #require(moved.components.firstIndex {
            if case .ingredient = $0.source { return true }
            return false
        })
        var ingredient = moved.components.remove(at: ingredientIndex)
        ingredient.course = .main
        moved.components.insert(ingredient, at: 0)
        try plannedStore.save(moved, id: planned.id, mealType: .lunch, day: nil)

        let verification = ModelContext(fixture.context.container)
        let loadedPlan = try PlannedMealStore(context: verification).draft(id: planned.id)
        let persistedPlan = try #require(verification.fetch(PlannedMeal.descriptor(id: planned.id)).first)
        #expect(loadedPlan.components == moved.components)
        #expect(persistedPlan.orderedComponents.map(\.sortOrder) == [0, 1, 2, 3])
        #expect(loadedPlan.components.filter { $0.course == .main }.first?.id == ingredient.id)
        #expect(loadedPlan.components.first?.quantity == 0.5)
        #expect(try MealStore(context: verification).draft(id: template.id).components == originalDraft.components)

        var savedCopy = MealDraft(plannedMeal: loadedPlan, mealType: .breakfast)
        savedCopy.name = "Ordered breakfast"
        #expect(savedCopy.components.map(\.source) == moved.components.map(\.source))
        #expect(savedCopy.components.map(\.course) == moved.components.map(\.course))
        #expect(Set(savedCopy.components.map(\.id)).isDisjoint(with: moved.components.map(\.id)))
        try MealStore(context: verification).save(savedCopy, id: nil)
        let copied = try #require(verification.fetch(FetchDescriptor<Meal>()).first { $0.name == savedCopy.name })
        let finalContext = ModelContext(fixture.context.container)
        let finalDraft = try MealStore(context: finalContext).draft(id: copied.id)
        #expect(finalDraft.components == savedCopy.components)
        let persistedCopy = try #require(finalContext.fetch(Meal.descriptor(id: copied.id)).first)
        #expect(persistedCopy.orderedComponents.map(\.sortOrder) == [0, 1, 2, 3])
    }

    @Test func directConstructorsAssignPositionsAndComponentCopiesKeepTheirRank() throws {
        let fixture = try makeFixture()
        let meal = Meal(name: "Direct dinner", mealType: .dinner, components: [
            MealComponent(recipe: fixture.secondRecipe, course: .side),
            MealComponent(readymeal: fixture.readymeal, course: .main),
            MealComponent(recipe: fixture.firstRecipe, course: .side),
        ])
        let originalIDs = meal.components.map(\.id)
        #expect(meal.orderedComponents.map(\.id) == originalIDs)
        #expect(meal.orderedComponents.map(\.sortOrder) == [0, 1, 2])
        let componentCopy = MealComponent(copying: meal.orderedComponents[2])
        #expect(componentCopy.sortOrder == 2)
        #expect(componentCopy.id != originalIDs[2])
        let planned = PlannedMeal(mealType: .dinner, components: meal.orderedComponents.map {
            MealComponent(copying: $0)
        })
        #expect(planned.orderedComponents.map(\.source) == meal.orderedComponents.map(\.source))
        #expect(planned.orderedComponents.map(\.sortOrder) == [0, 1, 2])
        fixture.context.insert(meal)
        fixture.context.insert(planned)
        try fixture.context.save()

        let verification = ModelContext(fixture.context.container)
        let persistedMeal = try #require(verification.fetch(Meal.descriptor(id: meal.id)).first)
        let persistedPlan = try #require(verification.fetch(PlannedMeal.descriptor(id: planned.id)).first)
        #expect(persistedMeal.orderedComponents.map(\.id) == originalIDs)
        #expect(persistedPlan.displayName == "Beans, Zulu dish, Alpha dish")
    }

    private func saveTemplate(_ fixture: Fixture) throws -> Meal {
        var draft = MealDraft(mealType: .lunch)
        draft.name = "Ordered lunch"
        draft.components = [
            MealComponentDraft(source: .recipe(fixture.secondRecipe.id), course: .side),
            MealComponentDraft(source: .readymeal(fixture.readymeal.id), course: .main),
            MealComponentDraft(source: .recipe(fixture.firstRecipe.id), course: .side),
            MealComponentDraft(source: .ingredient(fixture.apple.id), course: .side,
                               quantity: 0.5, unitID: fixture.count.id),
        ]
        try MealStore(context: fixture.context).save(draft, id: nil)
        return try #require(fixture.context.fetch(FetchDescriptor<Meal>()).first)
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(
            for: meal_planner_ios.Category.self, meal_planner_ios.Unit.self, AppSettings.self, Item.self,
            RecipieIngredient.self, Recipie.self, MealComponent.self, Meal.self,
            PlannedMeal.self, PlannedMiscEntry.self, ShoppingListEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let category = meal_planner_ios.Category(name: "Food", order: 0)
        let count = meal_planner_ios.Unit(name: "count", type: .count, magnitudes: [])
        let apple = Item(name: "Apple", category: category, kind: .ingredient)
        let readymeal = Item(name: "Beans", category: category, kind: .readymeal,
                             readymealData: ReadymealData(serves: 1, time: 3))
        let firstRecipe = Recipie(name: "Alpha dish")
        let secondRecipe = Recipie(name: "Zulu dish")
        context.insert(category)
        context.insert(count)
        [apple, readymeal].forEach(context.insert)
        [firstRecipe, secondRecipe].forEach(context.insert)
        try context.save()
        return Fixture(context: context, apple: apple, readymeal: readymeal, count: count,
                       firstRecipe: firstRecipe, secondRecipe: secondRecipe)
    }

    private struct Fixture {
        let context: ModelContext
        let apple: Item
        let readymeal: Item
        let count: meal_planner_ios.Unit
        let firstRecipe: Recipie
        let secondRecipe: Recipie
    }
}
