//
//  meal_planner_iosTests.swift
//  meal-planner-iosTests
//
//  Created by Benjamin Wright on 09/09/2025.
//

import Testing
import SwiftData
import Foundation
@testable import meal_planner_ios

struct meal_planner_iosTests {

    @Test func unitDraftRequiresCompleteUnitDetails() {
        var draft = UnitDraft(type: .weight)
        #expect(!draft.validate().isEmpty)

        draft.name = "grams"
        draft.magnitudes = [
            Magnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1)
        ]
        #expect(draft.validate().isEmpty)

        draft.magnitudes[0].multiplier = 0
        #expect(!draft.validate().isEmpty)
    }

    @Test func unitCanBeFetchedByItsNavigationIdentifier() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Unit.self, configurations: configuration)
        let context = ModelContext(container)
        let unit = Unit(
            name: "grams",
            type: .weight,
            magnitudes: [Magnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1)]
        )

        context.insert(unit)
        try context.save()

        let fetched = try context.fetch(Unit.descriptor(id: unit.id)).first
        #expect(fetched?.id == unit.id)
    }

    @MainActor
    @Test func recipieStoreCreatesUpdatesAndRemovesIngredients() throws {
        let context = try makeRecipieContext()
        let category = Category(name: "vegetables", order: 0)
        let item = Item(name: "carrots", category: category, kind: .ingredient)
        let unit = Unit(name: "grams", type: .weight, magnitudes: [
            Magnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1)
        ])
        context.insert(category)
        context.insert(item)
        context.insert(unit)
        try context.save()

        let ingredientID = UUID()
        var draft = RecipieDraft()
        draft.name = "Carrot soup"
        draft.ingredients = [
            RecipieIngredientDraft(id: ingredientID, itemID: item.id, unitID: unit.id, quantity: 100)
        ]

        let store = RecipieStore(context: context)
        try store.save(draft, id: nil)

        let recipie = try #require(context.fetch(FetchDescriptor<Recipie>()).first)
        #expect(recipie.ingredients.count == 1)
        #expect(recipie.ingredients[0].id == ingredientID)

        draft.ingredients[0].quantity = 250
        try store.save(draft, id: recipie.id)
        #expect(recipie.ingredients.count == 1)
        #expect(recipie.ingredients[0].quantity == 250)

        draft.ingredients = []
        try store.save(draft, id: recipie.id)
        #expect(recipie.ingredients.isEmpty)
        #expect(try context.fetch(FetchDescriptor<RecipieIngredient>()).isEmpty)
    }

    @MainActor
    @Test func recipieStoreRejectsMissingIngredientReferences() throws {
        let context = try makeRecipieContext()
        var draft = RecipieDraft()
        draft.name = "Missing item soup"
        draft.ingredients = [
            RecipieIngredientDraft(itemID: UUID(), unitID: UUID(), quantity: 1)
        ]

        do {
            try RecipieStore(context: context).save(draft, id: nil)
            Issue.record("Saving with missing ingredient references should fail.")
        } catch let error as RecipieStore.Error {
            guard case .missingIngredientReference = error else {
                Issue.record("Expected a missing ingredient reference error, got \(error).")
                return
            }
        }

        #expect(try context.fetch(FetchDescriptor<Recipie>()).isEmpty)
    }

    @MainActor
    @Test func categoryAndItemStoresLoadSaveAndDelete() throws {
        let context = try makeDataContext()
        let categoryStore = CategoryStore(context: context)
        var categoryDraft = try categoryStore.newDraft()
        categoryDraft.name = "Produce"
        try categoryStore.save(categoryDraft, id: nil)

        let savedCategory = try #require(context.fetch(FetchDescriptor<meal_planner_ios.Category>()).first)
        #expect(try categoryStore.draft(id: savedCategory.id).name == "Produce")

        let itemStore = ItemStore(context: context)
        var itemDraft = try itemStore.newDraft()
        itemDraft.name = "Carrots"
        try itemStore.save(itemDraft, id: nil)

        let item = try #require(context.fetch(FetchDescriptor<Item>()).first)
        #expect(try itemStore.draft(id: item.id).categoryID == savedCategory.id)

        try itemStore.delete(ids: [item.id])
        #expect(try context.fetch(FetchDescriptor<Item>()).isEmpty)
        try categoryStore.delete(ids: [savedCategory.id])
        #expect(try context.fetch(FetchDescriptor<meal_planner_ios.Category>()).isEmpty)
    }

    @MainActor
    @Test func itemStoreRequiresCategoryToCreateDraft() throws {
        let context = try makeDataContext()

        do {
            _ = try ItemStore(context: context).newDraft()
            Issue.record("Creating an item draft without a category should fail.")
        } catch let error as ItemStore.Error {
            guard case .missingCategory = error else {
                Issue.record("Expected a missing category error, got \(error).")
                return
            }
        }
    }

    @MainActor
    @Test func unitStoreValidatesDraftsAndProtectsReferencedUnits() throws {
        let context = try makeDataContext()
        let store = UnitStore(context: context)
        var draft = UnitDraft(type: .weight)

        do {
            try store.save(draft, id: nil)
            Issue.record("An incomplete unit draft should not save.")
        } catch let error as UnitStore.Error {
            guard case .invalidDraft = error else {
                Issue.record("Expected an invalid draft error, got \(error).")
                return
            }
        }

        draft.name = "grams"
        draft.magnitudes = [Magnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1)]
        try store.save(draft, id: nil)
        let savedUnit = try #require(context.fetch(FetchDescriptor<meal_planner_ios.Unit>()).first)
        context.insert(AppSettings(preferredVolume: savedUnit, preferredWeight: savedUnit))
        try context.save()

        do {
            try store.delete(ids: [savedUnit.id])
            Issue.record("A unit referenced by settings should not delete.")
        } catch let error as UnitStore.Error {
            guard case .inUse(let name) = error else {
                Issue.record("Expected an in-use error, got \(error).")
                return
            }
            #expect(name == "grams")
        }
    }

    @MainActor
    @Test func mealStoreCreatesUpdatesAndDeletesMeals() throws {
        let context = try makeMealContext()
        let recipie = Recipie(name: "Tomato soup", mealType: .dinner, course: .starter)
        let category = Category(name: "Prepared", order: 0)
        let readymeal = Item(
            name: "Prepared salad",
            category: category,
            kind: .readymeal,
            readymealData: ReadymealData(mealType: MealType.dinner.rawValue, course: CourseType.side.rawValue)
        )
        context.insert(category)
        context.insert(recipie)
        context.insert(readymeal)
        try context.save()

        var draft = MealDraft(mealType: .dinner)
        draft.name = "Soup supper"
        draft.dishes = [.recipe(recipie.id), .readymeal(readymeal.id)]

        let store = MealStore(context: context)
        try store.save(draft, id: nil)

        let meal = try #require(context.fetch(FetchDescriptor<Meal>()).first)
        #expect(meal.name == "Soup supper")
        #expect(meal.recipies.map(\.id) == [recipie.id])
        #expect(meal.readymeals.map(\.id) == [readymeal.id])
        #expect(try store.draft(id: meal.id).dishes == draft.dishes)

        draft.name = "Updated soup supper"
        try store.save(draft, id: meal.id)
        #expect(meal.name == "Updated soup supper")

        try store.delete(ids: [meal.id])
        #expect(try context.fetch(FetchDescriptor<Meal>()).isEmpty)
    }

    @MainActor
    @Test func mealStoreRejectsMissingDishReferences() throws {
        let context = try makeMealContext()
        var draft = MealDraft(mealType: .dinner)
        draft.name = "Missing dish meal"
        draft.dishes = [.recipe(UUID())]

        do {
            try MealStore(context: context).save(draft, id: nil)
            Issue.record("Saving with a missing dish reference should fail.")
        } catch let error as MealStore.Error {
            guard case .missingDishReference = error else {
                Issue.record("Expected a missing dish reference error, got \(error).")
                return
            }
        }

        #expect(try context.fetch(FetchDescriptor<Meal>()).isEmpty)
    }

    @MainActor
    @Test func plannedMealsKeepIndependentCopiesAndMoveBetweenDinnerDays() throws {
        let context = try makePlannerContext()
        let recipie = Recipie(name: "Tomato soup", mealType: .dinner, course: .main)
        context.insert(recipie)
        try context.save()

        var firstDraft = MealDraft(mealType: .dinner)
        firstDraft.name = "Saturday soup"
        firstDraft.dishes = [.recipe(recipie.id)]
        let store = PlannedMealStore(context: context)
        try store.save(firstDraft, id: nil, mealType: .dinner, day: .saturday)

        var secondDraft = firstDraft
        secondDraft.name = "Sunday soup"
        try store.save(secondDraft, id: nil, mealType: .dinner, day: .sunday)

        let plannedMeals = try context.fetch(FetchDescriptor<PlannedMeal>())
        let saturday = try #require(plannedMeals.first { $0.dayEnum == .saturday })
        let sunday = try #require(plannedMeals.first { $0.dayEnum == .sunday })
        
        #expect(saturday.recipies.map(\.id) == [recipie.id])
        
        try store.moveDinner(id: saturday.id, to: .sunday)

        #expect(saturday.dayEnum == .sunday)
        #expect(sunday.dayEnum == .saturday)
        let movedSaturday = try #require(
            context.fetch(FetchDescriptor<PlannedMeal>()).first { $0.id == saturday.id }
        )
        #expect(movedSaturday.recipies.map(\.id) == [recipie.id])
    }

    @MainActor
    @Test func plannedMiscEntriesSupportNotesAndSavedItems() throws {
        let context = try makePlannerContext()
        let category = Category(name: "Household", order: 0)
        let item = Item(name: "Bin bags", category: category, kind: .misc)
        context.insert(category)
        context.insert(item)
        try context.save()

        let store = PlannedMiscStore(context: context)
        try store.saveNote("Birthday candles")
        try store.saveItem(item.id)

        let entries = try context.fetch(FetchDescriptor<PlannedMiscEntry>())
            .sorted { $0.sortOrder < $1.sortOrder }
        #expect(entries.map(\.displayName) == ["Birthday candles", "Bin bags"])
        #expect(entries[0].item == nil)
        #expect(entries[1].item?.id == item.id)
    }

    @MainActor
    @Test func movingDinnerShiftsInterveningDays() throws {
        let context = try makePlannerContext()
        let saturday = PlannedMeal(mealType: .dinner, day: .saturday, name: "Saturday dinner")
        let sunday = PlannedMeal(mealType: .dinner, day: .sunday, name: "Sunday dinner")
        let monday = PlannedMeal(mealType: .dinner, day: .monday, name: "Monday dinner")
        context.insert(saturday)
        context.insert(sunday)
        context.insert(monday)
        try context.save()

        try PlannedMealStore(context: context).moveDinner(id: saturday.id, to: .monday)

        #expect(saturday.dayEnum == .monday)
        #expect(sunday.dayEnum == .saturday)
        #expect(monday.dayEnum == .sunday)
    }

    private func makeRecipieContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Category.self,
            Unit.self,
            Item.self,
            RecipieIngredient.self,
            Recipie.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func makeDataContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Category.self,
            Unit.self,
            Item.self,
            RecipieIngredient.self,
            Recipie.self,
            AppSettings.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func makeMealContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Category.self,
            Item.self,
            Recipie.self,
            Meal.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func makePlannerContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Category.self,
            Item.self,
            Recipie.self,
            Meal.self,
            PlannedMeal.self,
            PlannedMiscEntry.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

}
