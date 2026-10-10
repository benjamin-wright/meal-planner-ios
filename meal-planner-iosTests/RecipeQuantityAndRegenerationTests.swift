import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

struct RecipeQuantityAndRegenerationTests {
    @MainActor
    @Test
    func invalidRecipeQuantitiesCannotCreateOrUpdateRecipes() throws {
        for quantity in [0.0, -1.0, Double.nan, Double.infinity, -Double.infinity] {
            let fixture = try makeFixture()
            let context = fixture.context
            let store = RecipieStore(context: context)
            var draft = RecipieDraft()
            draft.name = "New recipe"
            draft.ingredients = [RecipieIngredientDraft(
                itemID: fixture.item.id, unitID: fixture.count.id, quantity: quantity
            )]
            #expect(draft.validate().contains(.invalidIngredientQuantity))
            #expect(throws: RecipieStore.Error.self) { try store.save(draft, id: nil) }
            #expect(try context.fetch(FetchDescriptor<Recipie>()).map(\.id) == [fixture.recipe.id])

            var edit = RecipieDraft(recipie: fixture.recipe)
            edit.name = "Changed recipe"
            edit.ingredients[0].quantity = quantity
            #expect(throws: RecipieStore.Error.self) { try store.save(edit, id: fixture.recipe.id) }
            #expect(fixture.recipe.name == "Apple salad")
            #expect(fixture.recipe.ingredients[0].quantity == 2)
            #expect(!context.hasChanges)
            let persisted = try #require(ModelContext(context.container).fetch(FetchDescriptor<Recipie>()).first)
            #expect(persisted.ingredients[0].quantity == 2)
        }
    }

    @MainActor
    @Test
    func invalidStoredRecipeQuantitiesPreserveTheExistingList() throws {
        for quantity in [0.0, -1.0, Double.infinity, -Double.infinity] {
            let fixture = try makeFixture()
            let context = fixture.context
            fixture.recipe.ingredients[0].quantity = quantity
            try context.save()

            do {
                try ShoppingListStore(context: context).regenerate()
                Issue.record("A stored recipe with an invalid quantity must not regenerate the list.")
            } catch let error as ShoppingListStore.Error {
                guard case .invalidRecipeIngredient(let name) = error else {
                    Issue.record("Expected an invalid recipe ingredient error, got \(error).")
                    return
                }
                #expect(name == "Apple salad")
            }
            try expectOriginalList(context: context, id: fixture.oldEntry.id)
            #expect(!context.hasChanges)
            try expectOriginalList(context: ModelContext(context.container), id: fixture.oldEntry.id)
        }
    }

    @MainActor
    @Test
    func invalidPendingRecipeQuantitiesPreserveTheListAndPendingEdits() throws {
        for quantity in [0.0, -1.0, Double.nan, Double.infinity, -Double.infinity] {
            let fixture = try makeFixture()
            fixture.recipe.ingredients[0].quantity = quantity

            #expect(throws: ShoppingListStore.Error.self) {
                try ShoppingListStore(context: fixture.context).regenerate()
            }
            #expect(fixture.context.hasChanges)
            try expectOriginalList(context: fixture.context, id: fixture.oldEntry.id)
            try expectOriginalList(context: ModelContext(fixture.context.container), id: fixture.oldEntry.id)
        }
    }

    @MainActor
    @Test func aFailedReplacementSaveRollsBackWithoutDiscardingSharedEdits() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        fixture.item.name = "Unsaved apple name"
        var replacementContext: ModelContext?
        let store = ShoppingListStore(context: context, saveRegeneratedList: { isolated in
            replacementContext = isolated
            #expect(isolated !== context)
            #expect(!isolated.autosaveEnabled)
            #expect(isolated.hasChanges)
            #expect(isolated.deletedModelsArray.contains { $0 is ShoppingListEntry })
            #expect(isolated.insertedModelsArray.contains { $0 is ShoppingListEntry })
            throw SaveFailure.injected
        })

        #expect(throws: SaveFailure.injected) { try store.regenerate() }
        #expect(try #require(replacementContext).hasChanges == false)
        #expect(fixture.item.name == "Unsaved apple name")
        #expect(context.hasChanges)
        try expectOriginalList(context: context, id: fixture.oldEntry.id)
        try expectOriginalList(context: ModelContext(context.container), id: fixture.oldEntry.id)

        // A later editor save must not accidentally commit the failed replacement.
        try context.save()
        try expectOriginalList(context: ModelContext(context.container), id: fixture.oldEntry.id)
        let savedItem = try #require(ModelContext(context.container).fetch(Item.descriptor(id: fixture.item.id)).first)
        #expect(savedItem.name == "Unsaved apple name")
    }

    @MainActor
    @Test func successfulRegenerationCommitsOnlyTheListReplacement() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        fixture.item.name = "Unsaved apple name"

        try ShoppingListStore(context: context).regenerate()

        let persistedContext = ModelContext(context.container)
        let entries = try persistedContext.fetch(FetchDescriptor<ShoppingListEntry>())
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.id != fixture.oldEntry.id)
        #expect(entry.name == "Unsaved apple name")
        #expect(entry.quantity == 2)
        #expect(!entry.isChecked)
        #expect(entry.item?.id == fixture.item.id)
        #expect(entry.unit?.id == fixture.count.id)
        #expect(context.hasChanges)
        #expect(fixture.item.name == "Unsaved apple name")
        #expect(try persistedContext.fetch(Item.descriptor(id: fixture.item.id)).first?.name == "Apples")
        #expect(try context.fetch(FetchDescriptor<ShoppingListEntry>()).map(\.id) == [entry.id])
    }

    @MainActor
    private func expectOriginalList(context: ModelContext, id: UUID) throws {
        let entries = try context.fetch(FetchDescriptor<ShoppingListEntry>())
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.id == id)
        #expect(entry.name == "Keep this list")
        #expect(entry.quantity == 7)
        #expect(entry.sortOrder == 4)
        #expect(entry.isChecked)
    }

    @MainActor
    private func makeFixture() throws -> Fixture {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Category.self, Unit.self, AppSettings.self, Item.self, RecipieIngredient.self,
            Recipie.self, Meal.self, PlannedMeal.self, PlannedMiscEntry.self, ShoppingListEntry.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let category = Category(name: "Produce", order: 0)
        let count = Unit(name: "count", type: .count, magnitudes: [])
        let grams = Unit(name: "grams", type: .weight, magnitudes: [])
        let litres = Unit(name: "litres", type: .volume, magnitudes: [])
        let item = Item(name: "Apples", category: category, kind: .ingredient)
        let recipe = Recipie(name: "Apple salad", serves: 2, ingredients: [
            RecipieIngredient(item: item, unit: count, quantity: 2)
        ])
        let meal = PlannedMeal(mealType: .lunch, servings: 2, components: [MealComponent(recipe: recipe)])
        let oldEntry = ShoppingListEntry(
            name: "Keep this list", quantity: 7, sortOrder: 4, isChecked: true,
            item: item, category: category, unit: count
        )
        context.insert(category)
        context.insert(count)
        context.insert(grams)
        context.insert(litres)
        context.insert(AppSettings(preferredVolume: litres, preferredWeight: grams))
        context.insert(item)
        context.insert(recipe)
        context.insert(meal)
        context.insert(oldEntry)
        try context.save()
        return Fixture(context: context, item: item, count: count, recipe: recipe, oldEntry: oldEntry)
    }

    private struct Fixture {
        let context: ModelContext
        let item: Item
        let count: meal_planner_ios.Unit
        let recipe: Recipie
        let oldEntry: ShoppingListEntry
    }

    private enum SaveFailure: Error {
        case injected
    }
}
