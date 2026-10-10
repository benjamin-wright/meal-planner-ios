import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct ItemDependencyTests {
    @Test
    func deletingItemsRejectsRecipeReferencesBeforeDeletingAnySelectedItem() throws {
        let fixture = try makeFixture()
        let context = fixture.context

        do {
            try ItemStore(context: context).delete(ids: [fixture.unusedItem.id, fixture.recipeItem.id])
            Issue.record("An item required by a recipe must not be deleted.")
        } catch let error as ItemStore.Error {
            guard case .usedInRecipe(let name) = error else {
                Issue.record("Expected a recipe dependency error, got \(error).")
                return
            }
            #expect(name == fixture.recipeItem.name)
            #expect(error.errorDescription?.contains("recipe") == true)
        }

        #expect(!context.hasChanges)
        let verification = ModelContext(context.container)
        #expect(Set(try verification.fetch(FetchDescriptor<Item>()).map(\.id))
                == Set([fixture.recipeItem.id, fixture.unusedItem.id]))
        let recipe = try #require(verification.fetch(Recipie.descriptor(id: fixture.recipe.id)).first)
        #expect(recipe.ingredients.first?.item.id == fixture.recipeItem.id)
    }

    @Test
    func deletingCategoriesRejectsRecipeReferencesBeforeDeletingOrReordering() throws {
        let fixture = try makeFixture()
        let context = fixture.context

        do {
            try CategoryStore(context: context).delete(ids: [fixture.unusedCategory.id, fixture.recipeCategory.id])
            Issue.record("A category containing an item required by a recipe must not be deleted.")
        } catch let error as CategoryStore.Error {
            guard case .itemUsedInRecipe(let category, let item) = error else {
                Issue.record("Expected a recipe dependency error, got \(error).")
                return
            }
            #expect(category == fixture.recipeCategory.name)
            #expect(item == fixture.recipeItem.name)
            #expect(error.errorDescription?.contains("recipe") == true)
        }

        #expect(!context.hasChanges)
        let verification = ModelContext(context.container)
        let categories = try verification.fetch(meal_planner_ios.Category.orderedDescriptor)
        #expect(categories.map(\.id)
                == [fixture.unusedCategory.id, fixture.recipeCategory.id, fixture.retainedCategory.id])
        #expect(categories.map(\.order) == [0, 1, 2])
        #expect(try verification.fetch(FetchDescriptor<Item>()).count == 2)
        let recipe = try #require(verification.fetch(Recipie.descriptor(id: fixture.recipe.id)).first)
        #expect(recipe.ingredients.first?.item.id == fixture.recipeItem.id)
    }

    @Test
    func deletingAnUnreferencedItemPreservesRecipeIngredients() throws {
        let fixture = try makeFixture()
        try ItemStore(context: fixture.context).delete(ids: [fixture.unusedItem.id])

        let verification = ModelContext(fixture.context.container)
        #expect(try verification.fetch(FetchDescriptor<Item>()).map(\.id) == [fixture.recipeItem.id])
        #expect(try verification.fetch(FetchDescriptor<RecipieIngredient>()).first?.item.id == fixture.recipeItem.id)
    }

    @Test
    func deletingAnUnreferencedCategoryCascadesItemsAndReordersRemainingCategories() throws {
        let fixture = try makeFixture()
        try CategoryStore(context: fixture.context).delete(ids: [fixture.unusedCategory.id])

        let verification = ModelContext(fixture.context.container)
        let categories = try verification.fetch(meal_planner_ios.Category.orderedDescriptor)
        #expect(categories.map(\.id) == [fixture.recipeCategory.id, fixture.retainedCategory.id])
        #expect(categories.map(\.order) == [0, 1])
        #expect(try verification.fetch(FetchDescriptor<Item>()).map(\.id) == [fixture.recipeItem.id])
        #expect(try verification.fetch(FetchDescriptor<RecipieIngredient>()).first?.item.id == fixture.recipeItem.id)
    }

    @Test
    func deletingAnItemOrItsCategorySucceedsAfterRecipeReferencesAreRemoved() throws {
        for deleteCategory in [false, true] {
            let fixture = try makeFixture()
            let context = fixture.context
            let ingredient = try #require(fixture.recipe.ingredients.first)
            fixture.recipe.ingredients = []
            context.delete(ingredient)
            try context.save()

            if deleteCategory {
                try CategoryStore(context: context).delete(ids: [fixture.recipeCategory.id])
            } else {
                try ItemStore(context: context).delete(ids: [fixture.recipeItem.id])
            }

            let verification = ModelContext(context.container)
            #expect(try verification.fetch(Item.descriptor(id: fixture.recipeItem.id)).isEmpty)
            let recipe = try #require(verification.fetch(Recipie.descriptor(id: fixture.recipe.id)).first)
            #expect(recipe.ingredients.isEmpty)
        }
    }

    @Test
    func pendingRecipeReferencesPreventItemOrCategoryDeletion() throws {
        for deleteCategory in [false, true] {
            let fixture = try makeFixture()
            let context = fixture.context
            let ingredient = RecipieIngredient(item: fixture.unusedItem, unit: fixture.unit, quantity: 2)
            let pendingRecipe = Recipie(name: "Pending recipe", ingredients: [ingredient])
            context.insert(pendingRecipe)

            if deleteCategory {
                #expect(throws: CategoryStore.Error.self) {
                    try CategoryStore(context: context).delete(ids: [fixture.unusedCategory.id])
                }
            } else {
                #expect(throws: ItemStore.Error.self) {
                    try ItemStore(context: context).delete(ids: [fixture.unusedItem.id])
                }
            }

            #expect(context.hasChanges)
            #expect(pendingRecipe.ingredients.first?.item.id == fixture.unusedItem.id)
            let verification = ModelContext(context.container)
            #expect(try verification.fetch(Item.descriptor(id: fixture.unusedItem.id)).count == 1)
            #expect(try verification.fetch(Recipie.descriptor(id: pendingRecipe.id)).isEmpty)
        }
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(
            for: meal_planner_ios.Category.self, meal_planner_ios.Unit.self, AppSettings.self, Item.self,
            RecipieIngredient.self, Recipie.self, MealComponent.self, Meal.self,
            PlannedMeal.self, PlannedMiscEntry.self, ShoppingListEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let unusedCategory = meal_planner_ios.Category(name: "Unused", order: 0)
        let recipeCategory = meal_planner_ios.Category(name: "Produce", order: 1)
        let retainedCategory = meal_planner_ios.Category(name: "Retained", order: 2)
        let unusedItem = Item(name: "Onion", category: unusedCategory, kind: .ingredient)
        let recipeItem = Item(name: "Carrot", category: recipeCategory, kind: .ingredient)
        let unit = meal_planner_ios.Unit(name: "count", type: .count, magnitudes: [])
        let ingredient = RecipieIngredient(item: recipeItem, unit: unit, quantity: 2)
        let recipe = Recipie(name: "Carrot soup", ingredients: [ingredient])
        context.insert(unusedCategory)
        context.insert(recipeCategory)
        context.insert(retainedCategory)
        context.insert(unusedItem)
        context.insert(recipeItem)
        context.insert(unit)
        context.insert(recipe)
        try context.save()
        return Fixture(
            context: context, unusedCategory: unusedCategory, recipeCategory: recipeCategory,
            retainedCategory: retainedCategory, unusedItem: unusedItem, recipeItem: recipeItem,
            unit: unit, recipe: recipe
        )
    }

    private struct Fixture {
        let context: ModelContext
        let unusedCategory: meal_planner_ios.Category
        let recipeCategory: meal_planner_ios.Category
        let retainedCategory: meal_planner_ios.Category
        let unusedItem: Item
        let recipeItem: Item
        let unit: meal_planner_ios.Unit
        let recipe: Recipie
    }
}
