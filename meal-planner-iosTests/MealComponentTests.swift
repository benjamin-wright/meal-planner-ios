import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct MealComponentTests {
    @Test func ingredientOnlyMealPersistsAndUpdatesItsContextualPortion() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let portionID = UUID()
        var draft = MealDraft(mealType: .lunch)
        draft.name = "Light lunch"
        draft.components = [ingredientDraft(
            id: portionID, itemID: fixture.apple.id, unitID: fixture.count.id,
            quantity: 0.5, course: .side
        )]
        #expect(draft.validate().isEmpty)

        let store = MealStore(context: context)
        try store.save(draft, id: nil)
        let meal = try #require(context.fetch(FetchDescriptor<Meal>()).first)
        #expect(meal.isValid)
        #expect(meal.components.count == 1)
        #expect(meal.components.first?.source == .ingredient(fixture.apple.id))

        let verification = ModelContext(context.container)
        let persisted = try #require(verification.fetch(Meal.descriptor(id: meal.id)).first)
        let loaded = try MealStore(context: verification).draft(id: meal.id)
        #expect(loaded.components == draft.components)
        #expect(persisted.components.first?.item?.id == fixture.apple.id)
        #expect(persisted.components.first?.unit?.id == fixture.count.id)
        #expect(persisted.components.first?.courseEnum == .side)

        draft.components[0].quantity = 2
        draft.components[0].course = .main
        try store.save(draft, id: meal.id)
        let updatedContext = ModelContext(context.container)
        let updated = try #require(updatedContext.fetch(Meal.descriptor(id: meal.id)).first)
        #expect(updated.components.count == 1)
        #expect(updated.components.first?.id == portionID)
        #expect(updated.components.first?.quantity == 2)
        #expect(updated.components.first?.courseEnum == .main)
        #expect(try updatedContext.fetch(FetchDescriptor<MealComponent>()).count == 1)
    }

    @Test func oneIngredientHasIndependentCoursesAndAmountsInDifferentMeals() throws {
        let fixture = try makeFixture()
        let store = MealStore(context: fixture.context)
        var breakfast = MealDraft(mealType: .breakfast)
        breakfast.name = "Fruit breakfast"
        breakfast.components = [ingredientDraft(
            itemID: fixture.apple.id, unitID: fixture.count.id, quantity: 0.5, course: .main
        )]
        var lunch = MealDraft(mealType: .lunch)
        lunch.name = "Hiking lunch"
        lunch.components = [ingredientDraft(
            itemID: fixture.apple.id, unitID: fixture.count.id, quantity: 2, course: .side
        )]
        try store.save(breakfast, id: nil)
        try store.save(lunch, id: nil)

        let meals = try ModelContext(fixture.context.container).fetch(FetchDescriptor<Meal>())
        let first = try #require(meals.first { $0.name == breakfast.name }?.components.first)
        let second = try #require(meals.first { $0.name == lunch.name }?.components.first)
        #expect(first.item?.id == second.item?.id)
        #expect(first.id != second.id)
        #expect(first.quantity == 0.5)
        #expect(second.quantity == 2)
        #expect(first.courseEnum == .main)
        #expect(second.courseEnum == .side)
        #expect(fixture.apple.itemKind == .ingredient)
        #expect(fixture.apple.readymealData == nil)
    }

    @Test func savedAndPlannedMealsCopyPortionsWithoutSharingTheirIdentity() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let mealStore = MealStore(context: context)
        var templateDraft = mealDraft(fixture, name: "Light lunch", quantity: 0.5)
        try mealStore.save(templateDraft, id: nil)
        let template = try #require(context.fetch(FetchDescriptor<Meal>()).first)
        let templatePortionID = try #require(template.components.first?.id)

        let plannedStore = PlannedMealStore(context: context)
        let firstDraft = PlannedMealDraft(meal: template)
        let secondDraft = PlannedMealDraft(meal: template)
        #expect(firstDraft.validate().isEmpty)
        #expect(firstDraft.components.first?.id != templatePortionID)
        #expect(firstDraft.components.first?.id != secondDraft.components.first?.id)
        try plannedStore.save(firstDraft, id: nil, mealType: .lunch, day: nil, sourceMealID: template.id)
        try plannedStore.save(secondDraft, id: nil, mealType: .lunch, day: nil, sourceMealID: template.id)
        let planned = try context.fetch(FetchDescriptor<PlannedMeal>()).sorted { $0.sortOrder < $1.sortOrder }
        let first = try #require(planned.first)
        let second = try #require(planned.last)
        #expect(first.id != second.id)
        #expect(first.displayName == fixture.apple.name)
        #expect(first.components.first?.id == firstDraft.components.first?.id)

        var editedPlan = try plannedStore.draft(id: first.id)
        #expect(editedPlan.components.first?.id == first.components.first?.id)
        editedPlan.components[0].quantity = 2
        editedPlan.components[0].course = .main
        editedPlan.servings = 3
        try plannedStore.save(editedPlan, id: first.id, mealType: .lunch, day: nil)
        templateDraft.components[0].quantity = 1
        try mealStore.save(templateDraft, id: template.id)

        let verification = ModelContext(context.container)
        let persistedFirst = try #require(verification.fetch(PlannedMeal.descriptor(id: first.id)).first)
        let persistedSecond = try #require(verification.fetch(PlannedMeal.descriptor(id: second.id)).first)
        let persistedTemplate = try #require(verification.fetch(Meal.descriptor(id: template.id)).first)
        #expect(persistedFirst.components.first?.quantity == 2)
        #expect(persistedFirst.components.first?.courseEnum == .main)
        #expect(persistedFirst.servings == 3)
        #expect(persistedSecond.components.first?.quantity == 0.5)
        #expect(persistedSecond.components.first?.courseEnum == .side)
        #expect(persistedTemplate.components.first?.quantity == 1)

        var newTemplate = MealDraft(plannedMeal: editedPlan, mealType: .lunch)
        newTemplate.name = "Hiking lunch"
        #expect(newTemplate.components.first?.id != editedPlan.components.first?.id)
        #expect(newTemplate.components.first?.quantity == 2)
        newTemplate.components[0].quantity = 1.5
        try mealStore.save(newTemplate, id: nil)
        #expect(first.components.first?.quantity == 2)
        #expect(try context.fetch(FetchDescriptor<MealComponent>()).count == 4)
    }

    @Test(arguments: [0.0, -1.0, Double.nan, Double.infinity, -Double.infinity])
    func invalidPortionsDoNotMutateSavedOrPlannedMeals(quantity: Double) throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let mealStore = MealStore(context: context)
        var draft = mealDraft(fixture, name: "Original lunch", quantity: 0.5)
        try mealStore.save(draft, id: nil)
        let meal = try #require(context.fetch(FetchDescriptor<Meal>()).first)
        let plannedStore = PlannedMealStore(context: context)
        try plannedStore.save(PlannedMealDraft(meal: meal), id: nil, mealType: .lunch, day: nil)
        let planned = try #require(context.fetch(FetchDescriptor<PlannedMeal>()).first)
        var plannedDraft = try plannedStore.draft(id: planned.id)

        let invalid = ingredientDraft(
            itemID: fixture.apple.id, unitID: fixture.count.id, quantity: quantity
        )
        draft.name = "Changed lunch"
        draft.components[0].quantity = 2
        draft.components.append(invalid)
        #expect(throws: MealStore.Error.self) { try mealStore.save(draft, id: meal.id) }
        #expect(!context.hasChanges)
        #expect(meal.name == "Original lunch")
        #expect(meal.components.first?.quantity == 0.5)

        plannedDraft.servings = 4
        plannedDraft.components[0].quantity = 2
        plannedDraft.components.append(invalid)
        #expect(throws: PlannedMealStore.Error.self) {
            try plannedStore.save(plannedDraft, id: planned.id, mealType: .dinner, day: .monday)
        }
        #expect(!context.hasChanges)
        #expect(planned.servings == 2)
        #expect(planned.mealTypeEnum == .lunch)
        #expect(planned.dayEnum == nil)

        let verification = ModelContext(context.container)
        #expect(try verification.fetch(FetchDescriptor<MealComponent>()).count == 2)
        #expect(try verification.fetch(Meal.descriptor(id: meal.id)).first?.components.first?.quantity == 0.5)
        #expect(try verification.fetch(PlannedMeal.descriptor(id: planned.id)).first?.components.first?.quantity == 0.5)
    }

    @Test func storesRejectMissingReferencesAndNonIngredientItemsBeforeInsertingMeals() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let readymeal = Item(name: "Prepared curry", category: fixture.category, kind: .readymeal,
                             readymealData: .default)
        let miscellaneous = Item(name: "Napkins", category: fixture.category, kind: .misc)
        context.insert(readymeal)
        context.insert(miscellaneous)
        try context.save()

        let invalidReferences = [
            ingredientDraft(itemID: UUID(), unitID: fixture.count.id, quantity: 1),
            ingredientDraft(itemID: fixture.apple.id, unitID: UUID(), quantity: 1),
            ingredientDraft(itemID: readymeal.id, unitID: fixture.count.id, quantity: 1),
            ingredientDraft(itemID: miscellaneous.id, unitID: fixture.count.id, quantity: 1),
        ]
        for invalid in invalidReferences {
            var draft = mealDraft(fixture, name: "Missing portion", quantity: 0.5)
            draft.components.append(invalid)
            #expect(throws: MealStore.Error.self) { try MealStore(context: context).save(draft, id: nil) }
            var plannedDraft = PlannedMealDraft()
            plannedDraft.components = draft.components
            #expect(throws: PlannedMealStore.Error.self) {
                try PlannedMealStore(context: context).save(plannedDraft, id: nil, mealType: .lunch, day: nil)
            }
            #expect(!context.hasChanges)
        }
        #expect(try context.fetch(FetchDescriptor<Meal>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PlannedMeal>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MealComponent>()).isEmpty)
    }

    @Test func storesRejectReusingAPortionOwnedByAnotherMeal() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let mealStore = MealStore(context: context)
        var draft = mealDraft(fixture, name: "Light lunch", quantity: 0.5)
        try mealStore.save(draft, id: nil)
        draft.name = "Second lunch"
        #expect(throws: MealStore.Error.self) { try mealStore.save(draft, id: nil) }
        #expect(throws: PlannedMealStore.Error.self) {
            try PlannedMealStore(context: context).save(
                PlannedMealDraft(components: draft.components),
                id: nil, mealType: .lunch, day: nil
            )
        }
        #expect(!context.hasChanges)
        #expect(try context.fetch(FetchDescriptor<Meal>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PlannedMeal>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<MealComponent>()).count == 1)
    }

    @Test func removingPortionsAndDeletingMealsCleansUpOnlyTheirOwnedRows() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let mealStore = MealStore(context: context)
        var draft = mealDraft(fixture, name: "Fruit lunch", quantity: 0.5)
        draft.components.append(ingredientDraft(
            itemID: fixture.apple.id, unitID: fixture.count.id, quantity: 2, course: .dessert
        ))
        try mealStore.save(draft, id: nil)
        let meal = try #require(context.fetch(FetchDescriptor<Meal>()).first)
        let plannedStore = PlannedMealStore(context: context)
        try plannedStore.save(PlannedMealDraft(meal: meal), id: nil, mealType: .lunch, day: nil)
        let planned = try #require(context.fetch(FetchDescriptor<PlannedMeal>()).first)
        let removedID = draft.components.removeFirst().id
        let retainedID = try #require(draft.components.first?.id)
        try mealStore.save(draft, id: meal.id)
        let remaining = try context.fetch(FetchDescriptor<MealComponent>())
        #expect(remaining.count == 3)
        #expect(!remaining.contains { $0.id == removedID })
        #expect(meal.components.first?.id == retainedID)
        #expect(planned.components.count == 2)

        try mealStore.delete(ids: [meal.id])
        #expect(try context.fetch(FetchDescriptor<MealComponent>()).count == 2)
        try plannedStore.delete(id: planned.id)
        #expect(try context.fetch(FetchDescriptor<MealComponent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Item>()).map(\.id) == [fixture.apple.id])
        #expect(try context.fetch(FetchDescriptor<meal_planner_ios.Unit>()).count == 3)
    }

    @Test func clearingThePlanPreservesSavedIngredientPortions() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        try MealStore(context: context).save(mealDraft(fixture, name: "Light lunch", quantity: 0.5), id: nil)
        let template = try #require(context.fetch(FetchDescriptor<Meal>()).first)
        let templatePortionID = try #require(template.components.first?.id)
        try PlannedMealStore(context: context).save(
            PlannedMealDraft(meal: template), id: nil, mealType: .lunch, day: nil
        )

        try PlannerStore(context: context).clear()
        let verification = ModelContext(context.container)
        #expect(try verification.fetch(FetchDescriptor<PlannedMeal>()).isEmpty)
        #expect(try verification.fetch(FetchDescriptor<MealComponent>()).map(\.id) == [templatePortionID])
        #expect(try verification.fetch(Meal.descriptor(id: template.id)).first?.components.first?.quantity == 0.5)
    }

    @Test func deletingAnIngredientRemovesItsSavedAndPlannedPortions() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        try MealStore(context: context).save(mealDraft(fixture, name: "Light lunch", quantity: 0.5), id: nil)
        let template = try #require(context.fetch(FetchDescriptor<Meal>()).first)
        try PlannedMealStore(context: context).save(
            PlannedMealDraft(meal: template), id: nil, mealType: .lunch, day: nil
        )
        try ItemStore(context: context).delete(ids: [fixture.apple.id])

        let verification = ModelContext(context.container)
        #expect(try verification.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(try verification.fetch(FetchDescriptor<MealComponent>()).isEmpty)
        #expect(try verification.fetch(FetchDescriptor<Meal>()).first?.components.isEmpty == true)
        #expect(try verification.fetch(FetchDescriptor<PlannedMeal>()).first?.components.isEmpty == true)
    }

    @Test func usedIngredientsAllowDetailEditsButProtectTheirKindUntilPortionsAreRemoved() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let mealStore = MealStore(context: context)
        try mealStore.save(mealDraft(fixture, name: "Light lunch", quantity: 0.5), id: nil)
        let mealID = try #require(context.fetch(FetchDescriptor<Meal>()).first?.id)
        let itemStore = ItemStore(context: context)
        var draft = ItemDraft(item: fixture.apple)
        draft.name = "Lunch apple"
        draft.dietary.dairy = true
        try itemStore.save(draft, id: fixture.apple.id)
        #expect(fixture.apple.name == "Lunch apple")
        #expect(fixture.apple.dietary == [.dairy])

        for kind in [ItemKind.readymeal, .misc] {
            var invalid = draft
            invalid.kind = kind
            invalid.name = "Unwanted change"
            invalid.dietary.dairy = false
            do {
                try itemStore.save(invalid, id: fixture.apple.id)
                Issue.record("Changing a used ingredient's kind should fail.")
            } catch let error as ItemStore.Error {
                guard case .itemInUse = error else {
                    Issue.record("Expected an ingredient-in-use error, got \(error).")
                    return
                }
            }
            #expect(!context.hasChanges)
            #expect(fixture.apple.itemKind == .ingredient)
            #expect(fixture.apple.name == "Lunch apple")
            #expect(fixture.apple.dietary == [.dairy])
        }

        try mealStore.delete(ids: [mealID])
        draft.kind = .readymeal
        try itemStore.save(draft, id: fixture.apple.id)
        let persisted = try #require(ModelContext(context.container).fetch(Item.descriptor(id: fixture.apple.id)).first)
        #expect(persisted.itemKind == .readymeal)
        #expect(persisted.readymealData != nil)
        #expect(persisted.mealComponents.isEmpty)
    }

    @Test func countUnitsReferencedOnlyByPortionsCannotBeDeleted() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let countID = fixture.count.id
        let mealStore = MealStore(context: context)
        try mealStore.save(mealDraft(fixture, name: "Fruit lunch", quantity: 1), id: nil)
        let template = try #require(context.fetch(FetchDescriptor<Meal>()).first)
        let plannedStore = PlannedMealStore(context: context)
        try plannedStore.save(PlannedMealDraft(meal: template), id: nil, mealType: .lunch, day: nil)
        let planned = try #require(context.fetch(FetchDescriptor<PlannedMeal>()).first)
        let unitStore = UnitStore(context: context)
        #expect(throws: UnitStore.Error.self) { try unitStore.delete(ids: [countID]) }
        try mealStore.delete(ids: [template.id])
        #expect(throws: UnitStore.Error.self) { try unitStore.delete(ids: [countID]) }
        try plannedStore.delete(id: planned.id)
        try unitStore.delete(ids: [countID])
        #expect(try context.fetch(meal_planner_ios.Unit.descriptor(id: countID)).isEmpty)
    }

    @Test(arguments: [1, 2])
    func shoppingListScalesHalfApplesWithoutRounding(servings: Int) throws {
        let fixture = try makeFixture()
        let context = fixture.context
        context.insert(PlannedMeal(
            mealType: .lunch, servings: servings,
            components: [MealComponent(ingredient: fixture.apple, unit: fixture.count, quantity: 0.5)]
        ))
        try context.save()
        try ShoppingListStore(context: context).regenerate()

        let entries = try context.fetch(FetchDescriptor<ShoppingListEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.item?.id == fixture.apple.id)
        #expect(entries.first?.unit?.id == fixture.count.id)
        #expect(entries.first?.quantity == Double(servings) * 0.5)
    }

    @Test func shoppingListAggregatesPortionsRecipesAndMiscWithUnitConversions() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let ounces = meal_planner_ios.Unit(name: "ounces", type: .weight, base: 28.3495, magnitudes: [
            Magnitude(abbreviation: "oz", singular: "ounce", plural: "ounces", multiplier: 1)
        ])
        let pints = meal_planner_ios.Unit(name: "pints", type: .volume, base: 0.568261, magnitudes: [
            Magnitude(abbreviation: "pt", singular: "pint", plural: "pints", multiplier: 1)
        ])
        let bags = meal_planner_ios.Unit(name: "bags", type: .count, magnitudes: [
            Magnitude(singular: "bag", plural: "bags", multiplier: 1)
        ])
        let milk = Item(name: "Milk", category: fixture.category, kind: .ingredient)
        context.insert(ounces)
        context.insert(pints)
        context.insert(bags)
        context.insert(milk)
        let recipe = Recipie(name: "Apple salad", serves: 2, ingredients: [
            RecipieIngredient(item: fixture.apple, unit: fixture.count, quantity: 1),
            RecipieIngredient(item: fixture.apple, unit: fixture.grams, quantity: 100),
            RecipieIngredient(item: milk, unit: fixture.litres, quantity: 0.2),
        ])
        context.insert(recipe)
        context.insert(PlannedMeal(mealType: .lunch, servings: 4, components: [
            MealComponent(recipe: recipe),
            MealComponent(ingredient: fixture.apple, unit: fixture.count, quantity: 0.5),
            MealComponent(ingredient: fixture.apple, unit: fixture.grams, quantity: 10),
            MealComponent(ingredient: fixture.apple, unit: ounces, quantity: 1),
            MealComponent(ingredient: fixture.apple, unit: bags, quantity: 0.5),
            MealComponent(ingredient: milk, unit: pints, quantity: 0.5),
        ]))
        context.insert(PlannedMiscEntry(item: fixture.apple, quantity: 1, unit: fixture.count))
        context.insert(PlannedMiscEntry(item: fixture.apple, quantity: 50, unit: fixture.grams))
        context.insert(PlannedMiscEntry(item: milk, quantity: 0.1, unit: fixture.litres))
        try context.save()
        try ShoppingListStore(context: context).regenerate()

        let entries = try context.fetch(FetchDescriptor<ShoppingListEntry>())
        #expect(entries.count == 4)
        #expect(entries.first { $0.item?.id == fixture.apple.id && $0.unit?.id == fixture.count.id }?.quantity == 5)
        #expect(entries.first { $0.item?.id == fixture.apple.id && $0.unit?.id == bags.id }?.quantity == 2)
        let appleWeight = try #require(entries.first { $0.item?.id == fixture.apple.id && $0.unit?.id == fixture.grams.id })
        #expect(abs(appleWeight.quantity - 403.398) < 0.000_001)
        let milkVolume = try #require(entries.first { $0.item?.id == milk.id })
        #expect(milkVolume.unit?.id == fixture.litres.id)
        #expect(abs(milkVolume.quantity - 1.636522) < 0.000_001)
    }

    @Test(arguments: [0.0, -1.0, Double.nan, Double.infinity, -Double.infinity])
    func invalidStoredPortionsPreserveTheExistingShoppingList(quantity: Double) throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let existing = ShoppingListEntry(name: "Keep this entry", quantity: 7, isChecked: true)
        context.insert(existing)
        try context.save()
        // Keep the invalid model pending: some stores cannot persist a NaN Double.
        context.insert(PlannedMeal(mealType: .lunch, components: [
            MealComponent(ingredient: fixture.apple, unit: fixture.count, quantity: quantity)
        ]))
        #expect(throws: ShoppingListStore.Error.self) { try ShoppingListStore(context: context).regenerate() }
        #expect(existing.isChecked)
        #expect(existing.quantity == 7)
        let persisted = try ModelContext(context.container).fetch(FetchDescriptor<ShoppingListEntry>())
        #expect(persisted.map(\.id) == [existing.id])
        #expect(persisted.first?.isChecked == true)
    }

    @Test(arguments: [ItemKind.readymeal, ItemKind.misc])
    func nonIngredientPortionsPreserveTheExistingShoppingList(kind: ItemKind) throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let item = Item(name: "Invalid portion", category: fixture.category, kind: kind,
                        readymealData: kind == .readymeal ? .default : nil)
        let existing = ShoppingListEntry(name: "Keep this entry", quantity: 7, isChecked: true)
        context.insert(item)
        context.insert(existing)
        context.insert(PlannedMeal(mealType: .lunch, components: [
            MealComponent(ingredient: item, unit: fixture.count, quantity: 1)
        ]))
        try context.save()
        #expect(throws: ShoppingListStore.Error.self) { try ShoppingListStore(context: context).regenerate() }
        #expect(!context.hasChanges)
        let persisted = try ModelContext(context.container).fetch(FetchDescriptor<ShoppingListEntry>())
        #expect(persisted.map(\.id) == [existing.id])
        #expect(persisted.first?.isChecked == true)
        #expect(persisted.first?.quantity == 7)
    }

    private func ingredientDraft(
        id: UUID = UUID(), itemID: UUID, unitID: UUID,
        quantity: Double = 1, course: CourseType = .side
    ) -> MealComponentDraft {
        MealComponentDraft(id: id, source: .ingredient(itemID), course: course, quantity: quantity, unitID: unitID)
    }

    private func mealDraft(_ fixture: Fixture, name: String, quantity: Double) -> MealDraft {
        var draft = MealDraft(mealType: .lunch)
        draft.name = name
        draft.components = [ingredientDraft(
            itemID: fixture.apple.id, unitID: fixture.count.id, quantity: quantity, course: .side
        )]
        return draft
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(
            for: meal_planner_ios.Category.self, meal_planner_ios.Unit.self, AppSettings.self, Item.self,
            RecipieIngredient.self, Recipie.self, MealComponent.self, Meal.self,
            PlannedMeal.self, PlannedMiscEntry.self, ShoppingListEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let category = meal_planner_ios.Category(name: "Produce", order: 0)
        let apple = Item(name: "Apple", category: category, kind: .ingredient)
        let count = meal_planner_ios.Unit(name: "count", type: .count, magnitudes: [])
        let grams = meal_planner_ios.Unit(name: "grams", type: .weight, magnitudes: [
            Magnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1)
        ])
        let litres = meal_planner_ios.Unit(name: "litres", type: .volume, magnitudes: [
            Magnitude(abbreviation: "l", singular: "litre", plural: "litres", multiplier: 1)
        ])
        context.insert(category)
        context.insert(apple)
        context.insert(count)
        context.insert(grams)
        context.insert(litres)
        context.insert(AppSettings(preferredVolume: litres, preferredWeight: grams))
        try context.save()
        return Fixture(context: context, category: category, apple: apple, count: count, grams: grams, litres: litres)
    }

    private struct Fixture {
        let context: ModelContext
        let category: meal_planner_ios.Category
        let apple: Item
        let count: meal_planner_ios.Unit
        let grams: meal_planner_ios.Unit
        let litres: meal_planner_ios.Unit
    }
}
