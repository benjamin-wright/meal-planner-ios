import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct PickerCreationTests {
    @Test func repeatedNestedCreationCompletionCannotSelectTheParent() {
        let router = FlowRouter()
        var selectedItemID: UUID?
        var selectedCategoryID: UUID?
        let itemPicker = router.showItemPicker(selectedID: UUID()) { selectedItemID = $0 }
        let itemCreation = router.showCreation(.item(kind: nil)) { router.complete(itemPicker, with: $0) }
        let itemEditorPath = router.path
        let categoryPicker = router.showCategoryPicker(selectedID: UUID()) { selectedCategoryID = $0 }
        let categoryCreation = router.showCreation(.category) { router.complete(categoryPicker, with: $0) }

        let categoryID = UUID()
        #expect(router.complete(categoryCreation, with: categoryID))
        #expect(selectedCategoryID == categoryID)
        #expect(selectedItemID == nil)
        #expect(router.path == itemEditorPath)
        // A retained save callback belongs only to its original editor.
        #expect(!router.complete(categoryCreation, with: categoryID))
        #expect(selectedItemID == nil)
        #expect(router.path == itemEditorPath)

        let itemID = UUID()
        #expect(router.complete(itemCreation, with: itemID))
        #expect(selectedItemID == itemID)
        #expect(router.path.isEmpty)
        #expect(!router.complete(itemCreation, with: itemID))
    }

    @Test func cancelledCreationDoesNotSelectAReplacementEditor() {
        let router = FlowRouter()
        var cancelledSelections: [UUID] = []
        var replacementSelections: [UUID] = []
        router.showItemPicker(selectedID: UUID()) { _ in }
        let pickerPath = router.path
        let cancelled = router.showCreation(.item(kind: nil)) { cancelledSelections.append($0) }
        router.path.removeLast()

        // A direct editor has no inherited completion from the cancelled session.
        router.path.append(.newItem)
        #expect(!router.complete(cancelled, with: UUID()))
        #expect(cancelledSelections.isEmpty)
        #expect(router.path == pickerPath + [.newItem])
        router.path.removeLast()

        let replacement = router.showCreation(.item(kind: nil)) { replacementSelections.append($0) }
        #expect(!router.complete(cancelled, with: UUID()))
        let itemID = UUID()
        #expect(router.complete(replacement, with: itemID))
        #expect(cancelledSelections.isEmpty)
        #expect(replacementSelections == [itemID])
        #expect(router.path == pickerPath)
    }

    @Test func cancelledSelectionCannotCompleteAReplacementOfTheSameKind() {
        let router = FlowRouter()
        var values: [UUID] = []
        let cancelled = router.showUnitPicker(selectedID: UUID()) { values.append($0) }
        router.path.removeLast()
        let replacement = router.showUnitPicker(selectedID: UUID()) { values.append($0) }
        let replacementPath = router.path
        #expect(!router.complete(cancelled, with: UUID()))
        #expect(values.isEmpty)
        #expect(router.path == replacementPath)
        let selectedID = UUID()
        #expect(router.complete(replacement, with: selectedID))
        #expect(!router.complete(replacement, with: UUID()))
        #expect(values == [selectedID])
        #expect(router.path.isEmpty)
    }

    @Test func nestedRecipeCreationSelectsADishWithoutCompletingItsMeal() {
        let router = FlowRouter()
        var selectedMealID: UUID?
        var components: [MealComponentDraft] = []
        let picker = router.showPlannerMealPicker(mealType: .lunch) { selectedMealID = $0 }
        let mealCreation = router.showCreation(.meal(.lunch)) { router.complete(picker, with: $0) }
        let mealEditorPath = router.path
        let dishPicker = router.showDishPicker(course: .main) { components.append($0) }
        let recipeCreation = router.showCreation(.recipe) {
            router.complete(dishPicker, with: MealComponentDraft(source: .recipe($0)))
        }

        let recipeID = UUID()
        #expect(router.complete(recipeCreation, with: recipeID))
        #expect(components.map(\.source) == [.recipe(recipeID)])
        #expect(selectedMealID == nil)
        #expect(router.path == mealEditorPath)
        #expect(!router.complete(recipeCreation, with: recipeID))
        #expect(selectedMealID == nil)
        let mealID = UUID()
        #expect(router.complete(mealCreation, with: mealID))
        #expect(selectedMealID == mealID)
        #expect(router.path.isEmpty)
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
        #expect(unit.id == unitID)
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
        try makeTestContext([
            Category.self, meal_planner_ios.Unit.self, Item.self, RecipieIngredient.self,
            Recipie.self, Meal.self,
        ])
    }
}
