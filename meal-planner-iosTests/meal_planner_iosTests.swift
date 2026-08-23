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

    @Test func plannedMealDraftPrefillsANewUnnamedMeal() {
        let dishes: [DishID] = [.recipe(UUID()), .readymeal(UUID())]
        let plannedDraft = PlannedMealDraft(dishes: dishes)

        let mealDraft = MealDraft(plannedMeal: plannedDraft, mealType: .lunch)

        #expect(mealDraft.name.isEmpty)
        #expect(mealDraft.mealType == .lunch)
        #expect(mealDraft.dishes == dishes)
        #expect(plannedDraft.servings == 2)
    }

    @MainActor
    @Test func plannedMealsKeepIndependentCopiesAndMoveBetweenDinnerDays() throws {
        let context = try makePlannerContext()
        let recipie = Recipie(name: "Tomato soup", mealType: .dinner, course: .main)
        context.insert(recipie)
        try context.save()

        var firstDraft = PlannedMealDraft()
        firstDraft.dishes = [.recipe(recipie.id)]
        let store = PlannedMealStore(context: context)
        try store.save(firstDraft, id: nil, mealType: .dinner, day: .saturday)

        let secondDraft = firstDraft
        try store.save(secondDraft, id: nil, mealType: .dinner, day: .sunday)

        let plannedMeals = try context.fetch(FetchDescriptor<PlannedMeal>())
        let saturday = try #require(plannedMeals.first { $0.dayEnum == .saturday })
        let sunday = try #require(plannedMeals.first { $0.dayEnum == .sunday })
        
        #expect(saturday.recipies.map(\.id) == [recipie.id])
        
        try store.moveDinner(from: .saturday, to: .sunday)

        #expect(saturday.dayEnum == .sunday)
        #expect(sunday.dayEnum == .saturday)
        let movedSaturday = try #require(
            context.fetch(FetchDescriptor<PlannedMeal>()).first { $0.id == saturday.id }
        )
        #expect(movedSaturday.recipies.map(\.id) == [recipie.id])
    }

    @Test func plannedMealDerivesItsDisplayNameFromMainsAndSides() {
        let starter = Recipie(name: "Tomato soup", mealType: .dinner, course: .starter)
        let main = Recipie(name: "Roast chicken", mealType: .dinner, course: .main)
        let side = Recipie(name: "Mashed potatoes", mealType: .dinner, course: .side)
        let category = Category(name: "Prepared", order: 0)
        let readySide = Item(
            name: "Peas",
            category: category,
            kind: .readymeal,
            readymealData: ReadymealData(mealType: MealType.dinner.rawValue, course: CourseType.side.rawValue)
        )
        let meal = PlannedMeal(
            mealType: .dinner,
            recipies: [starter, main, side],
            readymeals: [readySide]
        )

        #expect(meal.displayName == "Roast chicken, Mashed potatoes, Peas")

        meal.recipies = [main]
        meal.readymeals = []
        #expect(meal.displayName == "Roast chicken")
    }

    @Test func plannedMealDisplayNameFallsBackWhenThereAreNoMainsOrSides() {
        let starter = Recipie(name: "Tomato soup", mealType: .dinner, course: .starter)
        let dessert = Recipie(name: "Apple crumble", mealType: .dinner, course: .dessert)
        let meal = PlannedMeal(mealType: .dinner, recipies: [starter, dessert])

        #expect(meal.displayName == "Tomato soup, Apple crumble")
        #expect(PlannedMeal(mealType: .dinner).displayName == "No dishes")
    }

    @MainActor
    @Test func plannedMiscEntriesSupportNotesAndSavedItems() throws {
        let context = try makePlannerContext()
        let category = Category(name: "Household", order: 0)
        let item = Item(name: "Bin bags", category: category, kind: .misc)
        let unit = Unit(name: "packs", type: .count, magnitudes: [
            Magnitude(singular: "pack", plural: "packs", multiplier: 1)
        ])
        context.insert(category)
        context.insert(item)
        context.insert(unit)
        try context.save()

        let store = PlannedMiscStore(context: context)
        try store.saveNote("Birthday candles", categoryID: category.id, unitID: unit.id, quantity: 12)
        try store.saveItem(item.id, unitID: unit.id, quantity: 2)

        let entries = try context.fetch(FetchDescriptor<PlannedMiscEntry>())
            .sorted { $0.sortOrder < $1.sortOrder }
        #expect(entries.map(\.displayName) == ["Birthday candles", "Bin bags"])
        #expect(entries[0].item == nil)
        #expect(entries[0].note?.category.id == category.id)
        #expect(entries[0].quantity == 12)
        #expect(entries[1].item?.id == item.id)
        #expect(entries[1].unit?.id == unit.id)
    }

    @MainActor
    @Test func shoppingListScalesConvertsAndKeepsDissimilarCountUnitsSeparate() throws {
        let context = try makeShoppingContext()
        let produce = Category(name: "Produce", order: 0)
        let dairy = Category(name: "Dairy", order: 1)
        let prepared = Category(name: "Prepared", order: 2)
        let grams = Unit(name: "grams", type: .weight, base: 1, magnitudes: [
            Magnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1)
        ])
        let ounces = Unit(name: "ounces", type: .weight, base: 28.3495, magnitudes: [
            Magnitude(abbreviation: "oz", singular: "ounce", plural: "ounces", multiplier: 1)
        ])
        let litres = Unit(name: "litres", type: .volume, base: 1, magnitudes: [
            Magnitude(abbreviation: "l", singular: "litre", plural: "litres", multiplier: 1)
        ])
        let pints = Unit(name: "pints", type: .volume, base: 0.568261, magnitudes: [
            Magnitude(abbreviation: "pt", singular: "pint", plural: "pints", multiplier: 1)
        ])
        let count = Unit(name: "count", type: .count, magnitudes: [])
        let cans = Unit(name: "cans", type: .count, magnitudes: [
            Magnitude(singular: "can", plural: "cans", multiplier: 1)
        ])
        let carrots = Item(name: "Carrots", category: produce, kind: .ingredient)
        let milk = Item(name: "Milk", category: dairy, kind: .ingredient)
        let beans = Item(name: "Beans", category: produce, kind: .ingredient)
        let readymeal = Item(
            name: "Curry",
            category: prepared,
            kind: .readymeal,
            readymealData: ReadymealData(
                mealType: MealType.dinner.rawValue,
                course: CourseType.main.rawValue,
                serves: 3,
                time: 5
            )
        )
        [produce, dairy, prepared].forEach(context.insert)
        [grams, ounces, litres, pints, count, cans].forEach(context.insert)
        [carrots, milk, beans, readymeal].forEach(context.insert)
        context.insert(AppSettings(preferredVolume: litres, preferredWeight: grams))

        let firstRecipe = Recipie(
            name: "Soup",
            serves: 2,
            ingredients: [
                RecipieIngredient(item: carrots, unit: grams, quantity: 100),
                RecipieIngredient(item: milk, unit: pints, quantity: 1),
                RecipieIngredient(item: beans, unit: count, quantity: 1),
            ]
        )
        let secondRecipe = Recipie(
            name: "Beans",
            serves: 4,
            ingredients: [
                RecipieIngredient(item: carrots, unit: ounces, quantity: 1),
                RecipieIngredient(item: beans, unit: cans, quantity: 3),
            ]
        )
        context.insert(firstRecipe)
        context.insert(secondRecipe)
        context.insert(PlannedMeal(
            mealType: .dinner,
            servings: 4,
            recipies: [firstRecipe, secondRecipe],
            readymeals: [readymeal]
        ))
        context.insert(PlannedMiscEntry(
            item: carrots,
            quantity: 50,
            unit: grams
        ))
        context.insert(PlannedMiscEntry(
            note: PlannedMiscNote(text: "Birthday candles", category: produce),
            quantity: 12,
            unit: count
        ))
        try context.save()

        let store = ShoppingListStore(context: context)
        try store.addNote("Temporary", categoryID: dairy.id, unitID: count.id, quantity: 1)
        try store.regenerate()

        let entries = try context.fetch(FetchDescriptor<ShoppingListEntry>())
        #expect(entries.count == 6)
        #expect(!entries.contains { $0.name == "Temporary" })

        let carrotEntry = try #require(entries.first { $0.name == "Carrots" })
        #expect(carrotEntry.unit?.id == grams.id)
        #expect(abs(carrotEntry.quantity - 278.3495) < 0.000_001)

        let milkEntry = try #require(entries.first { $0.name == "Milk" })
        #expect(milkEntry.unit?.id == litres.id)
        #expect(abs(milkEntry.quantity - 1.136522) < 0.000_001)

        let beanEntries = entries.filter { $0.name == "Beans" }
        #expect(beanEntries.count == 2)
        #expect(Set(beanEntries.compactMap { $0.unit?.id }) == Set([count.id, cans.id]))
        #expect(beanEntries.first { $0.unit?.id == count.id }?.quantity == 2)
        #expect(beanEntries.first { $0.unit?.id == cans.id }?.quantity == 3)

        let note = try #require(entries.first { $0.name == "Birthday candles" })
        #expect(note.category?.id == produce.id)
        #expect(note.quantity == 12)
        let packagedMeal = try #require(entries.first { $0.name == "Curry" })
        #expect(packagedMeal.quantity == 2)
    }

    @MainActor
    @Test func checkedShoppingEntriesCanBeRemovedAndRestored() throws {
        let context = try makeShoppingContext()
        let category = Category(name: "Produce", order: 0)
        let count = Unit(name: "count", type: .count, magnitudes: [])
        let item = Item(name: "Apples", category: category, kind: .ingredient)
        context.insert(category)
        context.insert(count)
        context.insert(item)
        context.insert(ShoppingListEntry(name: item.name, quantity: 3, isChecked: true, item: item, category: category, unit: count))
        try context.save()

        let store = ShoppingListStore(context: context)
        let snapshots = try store.removeChecked()
        #expect(snapshots.count == 1)
        #expect(snapshots[0].itemID == item.id)
        #expect(snapshots[0].categoryID == category.id)
        #expect(snapshots[0].unitID == count.id)
        #expect(try context.fetch(FetchDescriptor<ShoppingListEntry>()).isEmpty)

        try store.restore(snapshots)
        let restored = try #require(context.fetch(FetchDescriptor<ShoppingListEntry>()).first)
        #expect(restored.name == "Apples")
        #expect(restored.quantity == 3)
        #expect(!restored.isChecked)
        #expect(restored.item?.id == item.id)
        #expect(restored.category?.id == category.id)
        #expect(restored.unit?.id == count.id)
    }

    @MainActor
    @Test func movingDinnerShiftsInterveningDays() throws {
        let context = try makePlannerContext()
        let saturday = PlannedMeal(mealType: .dinner, day: .saturday)
        let sunday = PlannedMeal(mealType: .dinner, day: .sunday)
        let monday = PlannedMeal(mealType: .dinner, day: .monday)
        context.insert(saturday)
        context.insert(sunday)
        context.insert(monday)
        try context.save()

        try PlannedMealStore(context: context).moveDinner(from: .saturday, to: .monday)

        #expect(saturday.dayEnum == .monday)
        #expect(sunday.dayEnum == .saturday)
        #expect(monday.dayEnum == .sunday)
    }

    @MainActor
    @Test func movingEmptyDinnerSlotForwardPersistsTheReorder() throws {
        let context = try makePlannerContext()
        let sunday = PlannedMeal(mealType: .dinner, day: .sunday)
        let monday = PlannedMeal(mealType: .dinner, day: .monday)
        context.insert(sunday)
        context.insert(monday)
        try context.save()

        try PlannedMealStore(context: context).moveDinner(from: .saturday, to: .monday)

        #expect(sunday.dayEnum == .saturday)
        #expect(monday.dayEnum == .sunday)
        #expect(try context.fetch(FetchDescriptor<PlannedMeal>()).allSatisfy { $0.dayEnum != .monday })
    }

    @MainActor
    @Test func movingEmptyDinnerSlotBackwardPersistsTheReorder() throws {
        let context = try makePlannerContext()
        let saturday = PlannedMeal(mealType: .dinner, day: .saturday)
        let sunday = PlannedMeal(mealType: .dinner, day: .sunday)
        context.insert(saturday)
        context.insert(sunday)
        try context.save()

        try PlannedMealStore(context: context).moveDinner(from: .monday, to: .saturday)

        #expect(saturday.dayEnum == .sunday)
        #expect(sunday.dayEnum == .monday)
        #expect(try context.fetch(FetchDescriptor<PlannedMeal>()).allSatisfy { $0.dayEnum != .saturday })
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
            Unit.self,
            Item.self,
            Recipie.self,
            Meal.self,
            PlannedMeal.self,
            PlannedMiscEntry.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func makeShoppingContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Category.self,
            Unit.self,
            AppSettings.self,
            Item.self,
            RecipieIngredient.self,
            Recipie.self,
            Meal.self,
            PlannedMeal.self,
            PlannedMiscEntry.self,
            ShoppingListEntry.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

}
