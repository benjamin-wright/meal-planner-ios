import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct WhitespaceTrimmingTests {
    @Test(arguments: [" \n\t", " \tab\n "])
    func draftsRejectNamesThatAreTooShortAfterTrimming(_ name: String) {
        var category = CategoryDraft()
        category.name = name
        #expect(category.validate().contains(.nameTooShort))

        var item = ItemDraft(categoryID: UUID())
        item.name = name
        #expect(item.validate().contains(.nameTooShort))

        var unit = UnitDraft(type: .count)
        unit.name = name
        #expect(unit.validate().contains(.nameTooShort))

        var recipe = RecipieDraft()
        recipe.name = name
        #expect(recipe.validate().contains(.nameTooShort))

        var meal = MealDraft()
        meal.name = name
        meal.components = [MealComponentDraft(source: .recipe(UUID()))]
        #expect(meal.validate().contains(.nameTooShort))

        let savedMeal = Meal(name: name, mealType: .dinner,
                             components: [MealComponent(recipe: Recipie(name: "Soup"))])
        #expect(!savedMeal.isValid)
    }

    @Test
    func duplicateValidationTrimsBothNamesAndKeepsCaseSensitivity() {
        let existingNames = [" \nSoup\t "]
        var category = CategoryDraft()
        var item = ItemDraft(categoryID: UUID())
        var recipe = RecipieDraft()
        var meal = MealDraft()
        meal.components = [MealComponentDraft(source: .recipe(UUID()))]

        for name in ["Soup", "\t Soup \n"] {
            category.name = name
            item.name = name
            recipe.name = name
            meal.name = name
            #expect(category.validate(existingNames: existingNames) == [.duplicateName])
            #expect(item.validate(existingNames: existingNames) == [.duplicateName])
            #expect(recipe.validate(existingNames: existingNames) == [.duplicateName])
            #expect(meal.validate(existingNames: existingNames) == [.duplicateName])
        }

        category.name = " soup "
        item.name = " soup "
        recipe.name = " soup "
        meal.name = " soup "
        #expect(category.validate(existingNames: existingNames).isEmpty)
        #expect(item.validate(existingNames: existingNames).isEmpty)
        #expect(recipe.validate(existingNames: existingNames).isEmpty)
        #expect(meal.validate(existingNames: existingNames).isEmpty)
    }

    @Test
    func unitValidationRejectsWhitespaceOnlyMagnitudeLabels() {
        var draft = UnitDraft(type: .weight)
        draft.name = " \tgrams\n "
        draft.magnitudes = [Magnitude(abbreviation: " \n", singular: " gram ", plural: " grams ", multiplier: 1)]
        #expect(draft.validate().isEmpty)

        draft.magnitudes[0].singular = " \n\t"
        #expect(draft.validate() == [.invalidMagnitude])
        draft.magnitudes[0].singular = " gram "
        draft.magnitudes[0].plural = "\n\t "
        #expect(draft.validate() == [.invalidMagnitude])
    }

    @Test
    func categoryStoreTrimsCreatedAndUpdatedNames() throws {
        let context = try makeContext()
        let store = CategoryStore(context: context)
        var draft = CategoryDraft(order: 2)
        draft.name = " \nFresh  produce\t "
        try store.save(draft, id: nil)
        let category = try #require(context.fetch(FetchDescriptor<meal_planner_ios.Category>()).first)
        #expect(category.name == "Fresh  produce")

        draft.name = "\tFresh  produce\n"
        try store.save(draft, id: category.id)
        draft.name = " \tDried  goods\n "
        try store.save(draft, id: category.id)

        let persisted = try #require(ModelContext(context.container).fetch(
            meal_planner_ios.Category.descriptor(id: category.id)
        ).first)
        #expect(persisted.name == "Dried  goods")
        #expect(persisted.order == 2)
    }

    @Test
    func itemStoreTrimsCreatedAndUpdatedNames() throws {
        let context = try makeContext()
        let category = meal_planner_ios.Category(name: "Produce", order: 0)
        context.insert(category)
        try context.save()
        let store = ItemStore(context: context)
        var draft = ItemDraft(categoryID: category.id)
        draft.name = " \nCarrot  sticks\t "
        try store.save(draft, id: nil)
        let item = try #require(context.fetch(FetchDescriptor<Item>()).first)
        #expect(item.name == "Carrot  sticks")

        draft.name = "\tCarrot  sticks\n"
        try store.save(draft, id: item.id)
        draft.name = " \tBaby  carrots\n "
        try store.save(draft, id: item.id)

        let persisted = try #require(ModelContext(context.container).fetch(Item.descriptor(id: item.id)).first)
        #expect(persisted.name == "Baby  carrots")
        #expect(persisted.category.id == category.id)
    }

    @Test
    func unitStoreTrimsNamesAndMagnitudeLabelsWithoutChangingIdentityOrScale() throws {
        let context = try makeContext()
        let store = UnitStore(context: context)
        var draft = UnitDraft(type: .weight)
        draft.name = " \nMetric  weight\t "
        draft.base = 0.001
        draft.magnitudes = [Magnitude(abbreviation: " \tg\n ", singular: " gram ", plural: " grams\n ", multiplier: 1)]
        let magnitudeID = draft.magnitudes[0].id
        try store.save(draft, id: nil)
        let unit = try #require(context.fetch(FetchDescriptor<meal_planner_ios.Unit>()).first)
        #expect(unit.name == "Metric  weight")
        #expect(unit.magnitudes[0].abbreviation == "g")
        #expect(unit.magnitudes[0].singular == "gram")
        #expect(unit.magnitudes[0].plural == "grams")
        #expect(unit.magnitudes[0].id == magnitudeID)
        #expect(unit.magnitudes[0].multiplier == 1)

        draft.name = " \tLarge  weights\n "
        draft.magnitudes[0].abbreviation = "\n kg\t"
        draft.magnitudes[0].singular = " kilo  gram\n "
        draft.magnitudes[0].plural = " kilo  grams\t "
        draft.magnitudes[0].multiplier = 1_000
        try store.save(draft, id: unit.id)

        let persisted = try #require(ModelContext(context.container).fetch(
            meal_planner_ios.Unit.descriptor(id: unit.id)
        ).first)
        #expect(persisted.name == "Large  weights")
        #expect(persisted.base == 0.001)
        #expect(persisted.magnitudes[0].abbreviation == "kg")
        #expect(persisted.magnitudes[0].singular == "kilo  gram")
        #expect(persisted.magnitudes[0].plural == "kilo  grams")
        #expect(persisted.magnitudes[0].id == magnitudeID)
        #expect(persisted.magnitudes[0].multiplier == 1_000)
    }

    @Test
    func recipeStoreTrimsTextWhilePreservingInnerWhitespaceAndStepCount() throws {
        let context = try makeContext()
        let (item, unit) = try addIngredient(in: context)
        let store = RecipieStore(context: context)
        var draft = RecipieDraft()
        draft.name = " \nTomato  soup\t "
        draft.summary = " \tRich  soup\nwith tomatoes.\n "
        draft.steps = [" \nChop  tomatoes.\t ", " \n\t", " Simmer.\nStir  gently. "]
        draft.ingredients = [RecipieIngredientDraft(itemID: item.id, unitID: unit.id, quantity: 2,
                                                    sourceText: " \n2  tomatoes\t ")]
        try store.save(draft, id: nil)
        let recipe = try #require(context.fetch(FetchDescriptor<Recipie>()).first)
        #expect(recipe.name == "Tomato  soup")
        #expect(recipe.summary == "Rich  soup\nwith tomatoes.")
        #expect(recipe.steps == ["Chop  tomatoes.", "", "Simmer.\nStir  gently."])
        #expect(recipe.ingredients[0].sourceText == "2  tomatoes")

        draft.name = "\tTomato  soup\n"
        try store.save(draft, id: recipe.id)
        draft.name = " \tRoasted  tomato soup\n "
        draft.summary = " \nRoast  first.\t "
        draft.steps = [" \tRoast  tomatoes.\n ", " Blend.\nServe  hot. "]
        draft.ingredients[0].sourceText = " \t2  roasted tomatoes\n "
        try store.save(draft, id: recipe.id)

        let persisted = try #require(ModelContext(context.container).fetch(Recipie.descriptor(id: recipe.id)).first)
        #expect(persisted.name == "Roasted  tomato soup")
        #expect(persisted.summary == "Roast  first.")
        #expect(persisted.steps == ["Roast  tomatoes.", "Blend.\nServe  hot."])
        #expect(persisted.ingredients[0].sourceText == "2  roasted tomatoes")
        #expect(persisted.ingredients[0].id == draft.ingredients[0].id)
    }

    @Test
    func mealStoreTrimsCreatedAndUpdatedNames() throws {
        let context = try makeContext()
        let recipe = Recipie(name: "Soup")
        context.insert(recipe)
        try context.save()
        let store = MealStore(context: context)
        var draft = MealDraft(mealType: .dinner)
        draft.name = " \nSoup  supper\t "
        draft.components = [MealComponentDraft(source: .recipe(recipe.id))]
        try store.save(draft, id: nil)
        let meal = try #require(context.fetch(FetchDescriptor<Meal>()).first)
        #expect(meal.name == "Soup  supper")

        draft.name = "\tSoup  supper\n"
        try store.save(draft, id: meal.id)
        draft.name = " \tQuick  supper\n "
        try store.save(draft, id: meal.id)

        let persisted = try #require(ModelContext(context.container).fetch(Meal.descriptor(id: meal.id)).first)
        #expect(persisted.name == "Quick  supper")
        #expect(persisted.components.map(\.id) == draft.components.map(\.id))
    }

    @Test
    func storesRejectNamesMatchingPaddedExistingRecords() throws {
        let context = try makeContext()
        let category = meal_planner_ios.Category(name: " \nProduce\t ", order: 0)
        let item = Item(name: " \nTomatoes\t ", category: category, kind: .ingredient)
        let recipe = Recipie(name: " \nTomato soup\t ")
        let meal = Meal(name: " \nSoup supper\t ", mealType: .dinner,
                        components: [MealComponent(recipe: recipe)])
        context.insert(category)
        context.insert(item)
        context.insert(recipe)
        context.insert(meal)
        try context.save()

        var categoryDraft = CategoryDraft()
        categoryDraft.name = "\tProduce\n"
        #expect(throws: CategoryStore.Error.self) { try CategoryStore(context: context).save(categoryDraft, id: nil) }
        var itemDraft = ItemDraft(categoryID: category.id)
        itemDraft.name = "\tTomatoes\n"
        #expect(throws: ItemStore.Error.self) { try ItemStore(context: context).save(itemDraft, id: nil) }
        var recipeDraft = RecipieDraft()
        recipeDraft.name = "\tTomato soup\n"
        #expect(throws: RecipieStore.Error.self) { try RecipieStore(context: context).save(recipeDraft, id: nil) }
        var mealDraft = MealDraft()
        mealDraft.name = "\tSoup supper\n"
        mealDraft.components = [MealComponentDraft(source: .recipe(recipe.id))]
        #expect(throws: MealStore.Error.self) { try MealStore(context: context).save(mealDraft, id: nil) }

        #expect(try context.fetch(FetchDescriptor<meal_planner_ios.Category>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Item>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Recipie>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Meal>()).count == 1)
    }

    @Test
    func importedRecipeSaveTrimsRecipeAndIngredientText() throws {
        let context = try makeContext()
        let (item, unit) = try addIngredient(in: context)
        var draft = RecipieDraft()
        draft.name = " \nImported  soup\t "
        draft.summary = " \tFresh  tomatoes.\n "
        draft.steps = [" \nChop  tomatoes.\t ", " \n\t", " Simmer.\nStir  gently. "]
        var ingredient = ImportedRecipieIngredient(sourceText: " \n2  tomatoes\t ", name: "tomatoes", quantityText: "2")
        ingredient.itemID = item.id
        ingredient.unitID = unit.id
        draft.importedIngredients = [ingredient]
        try RecipieStore(context: context).save(draft, id: nil)

        let persisted = try #require(ModelContext(context.container).fetch(FetchDescriptor<Recipie>()).first)
        #expect(persisted.name == "Imported  soup")
        #expect(persisted.summary == "Fresh  tomatoes.")
        #expect(persisted.steps == ["Chop  tomatoes.", "", "Simmer.\nStir  gently."])
        #expect(persisted.ingredients[0].sourceText == "2  tomatoes")
        #expect(persisted.ingredients[0].id == ingredient.id)
        #expect(persisted.ingredients[0].quantity == 2)
    }

    private func addIngredient(in context: ModelContext) throws -> (Item, meal_planner_ios.Unit) {
        let category = meal_planner_ios.Category(name: "Produce", order: 0)
        let item = Item(name: "Tomatoes", category: category, kind: .ingredient)
        let unit = meal_planner_ios.Unit(name: "count", type: .count, magnitudes: [])
        context.insert(category)
        context.insert(item)
        context.insert(unit)
        try context.save()
        return (item, unit)
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: meal_planner_ios.Category.self, meal_planner_ios.Unit.self, AppSettings.self, Item.self,
            RecipieIngredient.self, Recipie.self, MealComponent.self, Meal.self,
            PlannedMeal.self, PlannedMiscEntry.self, ShoppingListEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }
}
