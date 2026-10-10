import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct PickerCreationTests {
    @Test func nestedCategoryCreationPreservesPendingItemSelection() {
        let router = FlowRouter()
        var selectedItemID: UUID?
        var selectedCategoryID: UUID?
        var itemCompletions = 0
        var categoryCompletions = 0

        router.showItemPicker(selectedID: UUID()) { selectedItemID = $0 }
        router.showCreation(.newItem) { id in
            itemCompletions += 1
            router.selectItem(id)
            router.path = Array(router.path.dropLast())
        }
        router.showCategoryPicker(selectedID: UUID()) { selectedCategoryID = $0 }
        router.showCreation(.newCategory) { id in
            categoryCompletions += 1
            router.selectCategory(id)
            router.path = Array(router.path.dropLast())
        }

        let categoryID = UUID()
        #expect(router.completeCreation(id: categoryID))
        #expect(selectedCategoryID == categoryID)
        #expect(selectedItemID == nil)
        #expect(categoryCompletions == 1)
        #expect(itemCompletions == 0)
        #expect(router.path == [.itemPicker, .newItem])

        let itemID = UUID()
        #expect(router.completeCreation(id: itemID))
        #expect(selectedItemID == itemID)
        #expect(itemCompletions == 1)
        #expect(router.path.isEmpty)
    }

    @Test func cancelledCreationDoesNotSelectAReplacementEditor() {
        let router = FlowRouter()
        var cancelledSelections: [UUID] = []
        var replacementSelections: [UUID] = []
        router.path = [.itemPicker]
        router.showCreation(.newItem) { cancelledSelections.append($0) }
        router.path.removeLast()

        // The same editor route opened directly must not inherit the cancelled callback.
        router.path.append(.newItem)
        #expect(!router.completeCreation(id: UUID()))
        #expect(cancelledSelections.isEmpty)
        #expect(router.path == [.itemPicker, .newItem])
        router.path.removeLast()

        router.showCreation(.newItem) { replacementSelections.append($0) }
        let itemID = UUID()
        #expect(router.completeCreation(id: itemID))
        #expect(cancelledSelections.isEmpty)
        #expect(replacementSelections == [itemID])
        #expect(router.path == [.itemPicker])
    }

    @Test func directCatalogCreationKeepsItsNormalDismissal() {
        let router = FlowRouter()
        router.path = [.categories, .newCategory]

        #expect(!router.completeCreation(id: UUID()))
        #expect(router.path == [.categories, .newCategory])
    }

    @Test func creationCompletionSelectsOnlyOnce() {
        let router = FlowRouter()
        var selectedIDs: [UUID] = []
        router.path = [.unitPicker(typeFilter: .weight)]
        router.showCreation(.newUnit(.weight)) { id in
            selectedIDs.append(id)
            router.path = Array(router.path.dropLast())
        }

        let unitID = UUID()
        #expect(router.completeCreation(id: unitID))
        #expect(!router.completeCreation(id: unitID))
        #expect(selectedIDs == [unitID])
        #expect(router.path.isEmpty)
    }

    @Test func unrelatedNestedEditorCannotCompleteAncestorCreation() {
        let router = FlowRouter()
        var selectedMealID: UUID?
        router.path = [.plannerMealPicker(.lunch)]
        router.showCreation(.newMeal(.lunch)) { selectedMealID = $0 }
        router.path.append(.dishPicker(course: .main))
        router.path.append(.newRecipie)

        #expect(!router.completeCreation(id: UUID()))
        #expect(selectedMealID == nil)
        #expect(router.path == [.plannerMealPicker(.lunch), .newMeal(.lunch), .dishPicker(course: .main), .newRecipie])

        router.path = [.plannerMealPicker(.lunch), .newMeal(.lunch)]
        let mealID = UUID()
        #expect(router.completeCreation(id: mealID))
        #expect(selectedMealID == mealID)
        #expect(router.path == [.plannerMealPicker(.lunch)])
    }

    @Test func savedCatalogIdentifiersResolveImmediately() throws {
        let context = try makeContext()
        var categoryDraft = CategoryDraft()
        categoryDraft.name = "Picker produce"
        let categoryID = try CategoryStore(context: context).save(categoryDraft, id: nil)
        let category = try #require(context.fetch(Category.descriptor(id: categoryID)).first)
        #expect(category.name == categoryDraft.name)

        var itemDraft = ItemDraft(categoryID: categoryID)
        itemDraft.name = "Picker apples"
        let itemID = try ItemStore(context: context).save(itemDraft, id: nil)
        let item = try #require(context.fetch(Item.descriptor(id: itemID)).first)
        #expect(item.name == itemDraft.name)
        #expect(item.category.id == categoryID)

        var unitDraft = UnitDraft(type: .count)
        unitDraft.name = "Picker count"
        let unitID = try UnitStore(context: context).save(unitDraft, id: nil)
        let unit = try #require(context.fetch(meal_planner_ios.Unit.descriptor(id: unitID)).first)
        #expect(unit.name == unitDraft.name)

        var recipeDraft = RecipieDraft()
        recipeDraft.name = "Picker apple salad"
        recipeDraft.ingredients = [RecipieIngredientDraft(itemID: itemID, unitID: unitID, quantity: 2)]
        let recipeID = try RecipieStore(context: context).save(recipeDraft, id: nil)
        let recipe = try #require(context.fetch(Recipie.descriptor(id: recipeID)).first)
        #expect(recipe.name == recipeDraft.name)

        var mealDraft = MealDraft(mealType: .lunch)
        mealDraft.name = "Picker lunch"
        mealDraft.components = [MealComponentDraft(source: .recipe(recipeID), course: .main)]
        let mealID = try MealStore(context: context).save(mealDraft, id: nil)
        let meal = try #require(context.fetch(Meal.descriptor(id: mealID)).first)
        #expect(meal.name == mealDraft.name)
        #expect(meal.orderedComponents.map(\.source) == [.recipe(recipeID)])
    }

    @Test func importedRecipeIdentifierResolvesAfterSeparateContextSave() throws {
        let context = try makeContext()
        let category = Category(name: "Produce", order: 0)
        let item = Item(name: "Apples", category: category, kind: .ingredient)
        let unit = meal_planner_ios.Unit(name: "count", type: .count, magnitudes: [])
        context.insert(category)
        context.insert(item)
        context.insert(unit)
        try context.save()

        var ingredient = ImportedRecipieIngredient(sourceText: "2 apples", name: "apples", quantityText: "2")
        ingredient.itemID = item.id
        ingredient.unitID = unit.id
        var draft = RecipieDraft()
        draft.name = "Imported apple salad"
        draft.importedIngredients = [ingredient]

        let recipeID = try RecipieStore(context: context).save(draft, id: nil)
        let recipe = try #require(context.fetch(Recipie.descriptor(id: recipeID)).first)
        #expect(recipe.name == draft.name)
        #expect(recipe.ingredients.count == 1)
        #expect(recipe.ingredients.first?.item.id == item.id)
        #expect(recipe.ingredients.first?.quantity == 2)
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Category.self,
            meal_planner_ios.Unit.self,
            Item.self,
            RecipieIngredient.self,
            Recipie.self,
            Meal.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }
}
