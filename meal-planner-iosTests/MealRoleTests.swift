import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct MealRoleTests {
    @Test(arguments: [MealComponentKind.recipe, .readymeal])
    func catalogueSourcesHaveIndependentRolesInSavedAndPlannedMeals(kind: MealComponentKind) throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let source = source(for: kind, in: fixture)
        let savedStore = MealStore(context: context)
        let plannedStore = PlannedMealStore(context: context)
        let first = try saveMeal("Starter meal", type: .lunch, components: [
            MealComponentDraft(source: source, course: .starter)
        ], in: context)
        let second = try saveMeal("Side meal", type: .breakfast, components: [
            MealComponentDraft(source: source, course: .side)
        ], in: context)
        try plannedStore.save(PlannedMealDraft(meal: first), id: nil, mealType: .dinner,
                              day: .saturday, sourceMealID: first.id)
        try plannedStore.save(PlannedMealDraft(meal: second), id: nil, mealType: .lunch,
                              day: nil, sourceMealID: second.id)
        let plans = try context.fetch(FetchDescriptor<PlannedMeal>())
        let firstPlan = try #require(plans.first { $0.sourceMealID == first.id })
        let secondPlan = try #require(plans.first { $0.sourceMealID == second.id })

        var firstDraft = try savedStore.draft(id: first.id)
        firstDraft.components[0].course = .main
        try savedStore.save(firstDraft, id: first.id)
        var plannedDraft = try plannedStore.draft(id: firstPlan.id)
        plannedDraft.components[0].course = .dessert
        try plannedStore.save(plannedDraft, id: firstPlan.id, mealType: .dinner, day: .saturday)

        let verification = ModelContext(context.container)
        let persistedFirst = try #require(verification.fetch(Meal.descriptor(id: first.id)).first)
        let persistedSecond = try #require(verification.fetch(Meal.descriptor(id: second.id)).first)
        let persistedFirstPlan = try #require(verification.fetch(PlannedMeal.descriptor(id: firstPlan.id)).first)
        let persistedSecondPlan = try #require(verification.fetch(PlannedMeal.descriptor(id: secondPlan.id)).first)
        #expect(persistedFirst.components.first?.courseEnum == .main)
        #expect(persistedSecond.components.first?.courseEnum == .side)
        #expect(persistedFirstPlan.components.first?.courseEnum == .dessert)
        #expect(persistedSecondPlan.components.first?.courseEnum == .side)
        let rows = [persistedFirst, persistedSecond].flatMap(\.components)
            + [persistedFirstPlan, persistedSecondPlan].flatMap(\.components)
        #expect(Set(rows.map(\.id)).count == 4)
        #expect(rows.allSatisfy { $0.source == source && $0.quantity == nil && $0.unit == nil })

        let recipe = try #require(verification.fetch(Recipie.descriptor(id: fixture.recipe.id)).first)
        #expect(recipe.serves == 4)
        #expect(recipe.time == 20)
        #expect(recipe.summary == "A shared recipe")
        #expect(recipe.steps == ["Slice the apple."])
        #expect(recipe.ingredients.first?.quantity == 2)
        let readymeal = try #require(verification.fetch(Item.descriptor(id: fixture.readymeal.id)).first)
        #expect(readymeal.itemKind == .readymeal)
        #expect(readymeal.readymealData?.serves == 2)
        #expect(readymeal.readymealData?.time == 5)
    }

    @Test func savingAndPlanningAllSourcesCopiesRolesWithIndependentComponentIDs() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let savedStore = MealStore(context: context)
        let plannedStore = PlannedMealStore(context: context)
        let original = try saveMeal("Reusable lunch", type: .lunch,
                                    components: allSources(fixture), in: context)
        let planDraft = PlannedMealDraft(meal: original)
        try plannedStore.save(planDraft, id: nil, mealType: .lunch, day: nil, sourceMealID: original.id)
        let planned = try #require(context.fetch(FetchDescriptor<PlannedMeal>()).first)
        var copiedDraft = MealDraft(plannedMeal: try plannedStore.draft(id: planned.id), mealType: .breakfast)
        copiedDraft.name = "Copied breakfast"
        try savedStore.save(copiedDraft, id: nil)
        let copied = try #require(context.fetch(FetchDescriptor<Meal>()).first { $0.name == copiedDraft.name })
        let groups = [original.components, planned.components, copied.components]
        #expect(groups.allSatisfy { $0.count == 3 })
        #expect(Set(groups.flatMap { $0 }.map(\.id)).count == 9)
        let originalRoles = Dictionary(uniqueKeysWithValues: original.components.map { ($0.source, $0.courseEnum) })
        for group in groups {
            #expect(Dictionary(uniqueKeysWithValues: group.map { ($0.source, $0.courseEnum) }) == originalRoles)
            #expect(group.first { $0.kindEnum == .ingredient }?.quantity == 0.5)
        }

        var editedCopy = try savedStore.draft(id: copied.id)
        for index in editedCopy.components.indices {
            editedCopy.components[index].course = .dessert
        }
        try savedStore.save(editedCopy, id: copied.id)
        let verification = ModelContext(context.container)
        let persistedOriginal = try #require(verification.fetch(Meal.descriptor(id: original.id)).first)
        let persistedPlan = try #require(verification.fetch(PlannedMeal.descriptor(id: planned.id)).first)
        let persistedCopy = try #require(verification.fetch(Meal.descriptor(id: copied.id)).first)
        #expect(Dictionary(uniqueKeysWithValues: persistedOriginal.components.map { ($0.source, $0.courseEnum) }) == originalRoles)
        #expect(Dictionary(uniqueKeysWithValues: persistedPlan.components.map { ($0.source, $0.courseEnum) }) == originalRoles)
        #expect(persistedCopy.components.allSatisfy { $0.courseEnum == .dessert })
    }

    @Test(arguments: [MealComponentKind.recipe, .readymeal])
    func deletingACatalogueSourceRemovesOnlyItsComponents(kind: MealComponentKind) throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let saved = try saveMeal("Mixed lunch", type: .lunch, components: allSources(fixture), in: context)
        try PlannedMealStore(context: context).save(PlannedMealDraft(meal: saved), id: nil,
                                                    mealType: .lunch, day: nil, sourceMealID: saved.id)
        let planned = try #require(context.fetch(FetchDescriptor<PlannedMeal>()).first)
        let deletedSource = source(for: kind, in: fixture)
        let expectedIDs = Set((saved.components + planned.components)
            .filter { $0.source != deletedSource }.map(\.id))
        if kind == .recipe {
            try RecipieStore(context: context).delete(id: fixture.recipe.id)
        } else {
            try ItemStore(context: context).delete(ids: [fixture.readymeal.id])
        }

        let verification = ModelContext(context.container)
        let persistedSaved = try #require(verification.fetch(Meal.descriptor(id: saved.id)).first)
        let persistedPlan = try #require(verification.fetch(PlannedMeal.descriptor(id: planned.id)).first)
        let remaining = try verification.fetch(FetchDescriptor<MealComponent>())
        #expect(persistedSaved.components.count == 2)
        #expect(persistedPlan.components.count == 2)
        #expect(Set(remaining.map(\.id)) == expectedIDs)
        #expect(remaining.allSatisfy { $0.source != nil && $0.source != deletedSource })
        #expect(try verification.fetch(Item.descriptor(id: fixture.apple.id)).count == 1)
        if kind == .recipe {
            #expect(try verification.fetch(Recipie.descriptor(id: fixture.recipe.id)).isEmpty)
            #expect(try verification.fetch(Item.descriptor(id: fixture.readymeal.id)).count == 1)
        } else {
            #expect(try verification.fetch(Item.descriptor(id: fixture.readymeal.id)).isEmpty)
            #expect(try verification.fetch(Recipie.descriptor(id: fixture.recipe.id)).count == 1)
        }
    }

    @Test(arguments: [MealComponentKind.recipe, .readymeal])
    func recipeAndReadymealComponentsRejectIngredientPortionFields(kind: MealComponentKind) throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let source = source(for: kind, in: fixture)
        let savedStore = MealStore(context: context)
        let plannedStore = PlannedMealStore(context: context)
        let saved = try saveMeal("Valid meal", type: .lunch, components: [
            MealComponentDraft(source: source, course: .starter)
        ], in: context)
        try plannedStore.save(PlannedMealDraft(meal: saved), id: nil, mealType: .lunch, day: nil)
        let planned = try #require(context.fetch(FetchDescriptor<PlannedMeal>()).first)
        let malformedFields: [(quantity: Double?, unitID: UUID?)] = [
            (1, nil), (nil, fixture.count.id), (1, fixture.count.id)
        ]
        for fields in malformedFields {
            var invalidSaved = try savedStore.draft(id: saved.id)
            invalidSaved.components[0].quantity = fields.quantity
            invalidSaved.components[0].unitID = fields.unitID
            invalidSaved.components[0].course = .dessert
            #expect(!invalidSaved.components[0].hasValidPortion)
            #expect(throws: MealStore.Error.self) { try savedStore.save(invalidSaved, id: saved.id) }
            var invalidPlan = try plannedStore.draft(id: planned.id)
            invalidPlan.components[0].quantity = fields.quantity
            invalidPlan.components[0].unitID = fields.unitID
            invalidPlan.components[0].course = .dessert
            #expect(throws: PlannedMealStore.Error.self) {
                try plannedStore.save(invalidPlan, id: planned.id, mealType: .lunch, day: nil)
            }
            #expect(!context.hasChanges)
        }
        let verification = ModelContext(context.container)
        let rows = try verification.fetch(FetchDescriptor<MealComponent>())
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.courseEnum == .starter && $0.quantity == nil && $0.unit == nil })
    }

    @Test func readymealKindIsProtectedUntilEverySavedAndPlannedOccurrenceIsRemoved() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let saved = try saveMeal("Packaged lunch", type: .lunch, components: [
            MealComponentDraft(source: .readymeal(fixture.readymeal.id), course: .side)
        ], in: context)
        let plannedStore = PlannedMealStore(context: context)
        try plannedStore.save(PlannedMealDraft(meal: saved), id: nil, mealType: .lunch, day: nil)
        let planned = try #require(context.fetch(FetchDescriptor<PlannedMeal>()).first)
        let itemStore = ItemStore(context: context)
        var detailEdit = try itemStore.draft(id: fixture.readymeal.id)
        detailEdit.name = "Renamed pasta pot"
        detailEdit.readymealData.time = 10
        try itemStore.save(detailEdit, id: fixture.readymeal.id)

        for kind in [ItemKind.ingredient, .misc] {
            var invalid = detailEdit
            invalid.kind = kind
            #expect(throws: ItemStore.Error.self) { try itemStore.save(invalid, id: fixture.readymeal.id) }
            #expect(!context.hasChanges)
        }
        #expect(saved.components.first?.courseEnum == .side)
        #expect(planned.components.first?.courseEnum == .side)
        try MealStore(context: context).delete(ids: [saved.id])
        var changedKind = detailEdit
        changedKind.kind = .ingredient
        #expect(throws: ItemStore.Error.self) { try itemStore.save(changedKind, id: fixture.readymeal.id) }
        try plannedStore.delete(id: planned.id)
        try itemStore.save(changedKind, id: fixture.readymeal.id)
        let verification = ModelContext(context.container)
        let persisted = try #require(verification.fetch(Item.descriptor(id: fixture.readymeal.id)).first)
        #expect(persisted.itemKind == .ingredient)
        #expect(persisted.readymealData == nil)
        #expect(persisted.mealComponents.isEmpty)
    }

    private func source(for kind: MealComponentKind, in fixture: Fixture) -> DishID {
        switch kind {
        case .recipe: return .recipe(fixture.recipe.id)
        case .readymeal: return .readymeal(fixture.readymeal.id)
        case .ingredient: return .ingredient(fixture.apple.id)
        }
    }

    private func allSources(_ fixture: Fixture) -> [MealComponentDraft] {
        [
            MealComponentDraft(source: .recipe(fixture.recipe.id), course: .starter),
            MealComponentDraft(source: .readymeal(fixture.readymeal.id), course: .main),
            MealComponentDraft(source: .ingredient(fixture.apple.id), course: .side,
                               quantity: 0.5, unitID: fixture.count.id)
        ]
    }

    private func saveMeal(
        _ name: String, type: MealType, components: [MealComponentDraft], in context: ModelContext
    ) throws -> Meal {
        var draft = MealDraft(mealType: type)
        draft.name = name
        draft.components = components
        try MealStore(context: context).save(draft, id: nil)
        return try #require(context.fetch(FetchDescriptor<Meal>()).first { $0.name == name })
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
        let grams = meal_planner_ios.Unit(name: "grams", type: .weight, magnitudes: [])
        let litres = meal_planner_ios.Unit(name: "litres", type: .volume, magnitudes: [])
        let apple = Item(name: "Apple", category: category, kind: .ingredient)
        let readymeal = Item(name: "Pasta pot", category: category, kind: .readymeal,
                             readymealData: ReadymealData(serves: 2, time: 5))
        let recipe = Recipie(name: "Apple salad", summary: "A shared recipe", serves: 4, time: 20,
                             ingredients: [RecipieIngredient(item: apple, unit: count, quantity: 2)],
                             steps: ["Slice the apple."])
        context.insert(category)
        [count, grams, litres].forEach(context.insert)
        [apple, readymeal].forEach(context.insert)
        context.insert(recipe)
        context.insert(AppSettings(preferredVolume: litres, preferredWeight: grams))
        try context.save()
        return Fixture(context: context, apple: apple, readymeal: readymeal, recipe: recipe, count: count)
    }

    private struct Fixture {
        let context: ModelContext
        let apple: Item
        let readymeal: Item
        let recipe: Recipie
        let count: meal_planner_ios.Unit
    }
}
