import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct MealHistoryTests {
    @Test func repeatedSavesKeepOneUsageAndIdenticalSavesKeepItsDate() throws {
        let fixture = try Fixture()
        let store = PlannedMealStore(context: fixture.context)
        try store.save(fixture.draft, id: nil, mealType: .dinner, day: .monday)
        let plan = try #require(fixture.context.fetch(FetchDescriptor<PlannedMeal>()).first)
        let history = try #require(fixture.context.fetch(MealHistory.descriptor(id: plan.id)).first)
        let originalDate = Date(timeIntervalSince1970: 1_000)
        history.savedAt = originalDate
        try fixture.context.save()

        let unchanged = try store.draft(id: plan.id)
        try store.save(unchanged, id: plan.id, mealType: .dinner, day: .monday)
        try store.save(unchanged, id: plan.id, mealType: .dinner, day: .tuesday)

        let verification = ModelContext(fixture.context.container)
        let histories = try verification.fetch(FetchDescriptor<MealHistory>())
        #expect(histories.count == 1)
        #expect(histories.first?.id == plan.id)
        #expect(histories.first?.savedAt == originalDate)
        #expect(histories.first?.name == fixture.recipe.name)
        #expect(histories.first?.mealTypeEnum == .dinner)
    }

    @Test func editingRecipeCourseAndServingsReplacesTheOriginalChoice() throws {
        let fixture = try Fixture()
        let store = PlannedMealStore(context: fixture.context)
        try store.save(fixture.draft, id: nil, mealType: .dinner, day: .monday)
        let plan = try #require(fixture.context.fetch(FetchDescriptor<PlannedMeal>()).first)
        let history = try #require(fixture.context.fetch(MealHistory.descriptor(id: plan.id)).first)
        history.savedAt = Date(timeIntervalSince1970: 1_000)
        try fixture.context.save()
        var changed = try store.draft(id: plan.id)
        changed.components[0].source = .recipe(fixture.otherRecipe.id)
        changed.components[0].course = .side
        changed.servings = 4

        try store.save(changed, id: plan.id, mealType: .lunch, day: nil)

        let histories = try ModelContext(fixture.context.container).fetch(FetchDescriptor<MealHistory>())
        let saved = try #require(histories.first)
        #expect(histories.count == 1)
        #expect(saved.id == plan.id)
        #expect(saved.name == fixture.otherRecipe.name)
        #expect(saved.mealTypeEnum == .lunch)
        #expect(saved.servings == 4)
        #expect(saved.savedAt > Date(timeIntervalSince1970: 1_000))
        #expect(saved.components.map(\.draft) == changed.components)
        #expect(saved.components.first?.course == .side)
        #expect(saved.components.first?.sourceID == fixture.otherRecipe.id)
    }

    @Test func reusingHistoryCreatesIndependentComponentsAndAnotherUsage() throws {
        let fixture = try Fixture()
        let store = PlannedMealStore(context: fixture.context)
        try store.save(fixture.draft, id: nil, mealType: .lunch, day: nil)
        let original = try #require(fixture.context.fetch(FetchDescriptor<PlannedMeal>()).first)
        let history = try #require(fixture.context.fetch(MealHistory.descriptor(id: original.id)).first)
        let firstCopy = history.draft
        let secondCopy = history.draft
        #expect(firstCopy.components.first?.id != original.components.first?.id)
        #expect(firstCopy.components.first?.id != secondCopy.components.first?.id)
        #expect(firstCopy.components.first?.source == .recipe(fixture.recipe.id))

        try store.save(firstCopy, id: nil, mealType: .lunch, day: nil)

        let verification = ModelContext(fixture.context.container)
        let plans = try verification.fetch(FetchDescriptor<PlannedMeal>())
        let histories = try verification.fetch(FetchDescriptor<MealHistory>())
        #expect(plans.count == 2)
        #expect(Set(histories.map(\.id)) == Set(plans.map(\.id)))
        #expect(histories.allSatisfy { $0.components.first?.sourceID == fixture.recipe.id })
    }

    @Test func clearBackfillsActivePlansAndRetainsHistoryWithoutSavingTemplates() throws {
        let fixture = try Fixture()
        let plan = PlannedMeal(mealType: .dinner, day: .friday,
                               components: [MealComponent(recipe: fixture.recipe, course: .side)])
        let template = Meal(name: "A named meal", mealType: .lunch,
                            components: [MealComponent(recipe: fixture.otherRecipe)])
        fixture.context.insert(plan)
        fixture.context.insert(template)
        try fixture.context.save()
        let planID = plan.id
        let templateID = template.id

        try PlannerStore(context: fixture.context).clear()

        let verification = ModelContext(fixture.context.container)
        #expect(try verification.fetch(FetchDescriptor<PlannedMeal>()).isEmpty)
        let histories = try verification.fetch(FetchDescriptor<MealHistory>())
        #expect(histories.map(\.id) == [planID])
        #expect(histories.first?.components.first?.course == .side)
        #expect(histories.first?.name == fixture.recipe.name)
        #expect(try verification.fetch(Meal.descriptor(id: templateID)).count == 1)
        #expect(try verification.fetch(FetchDescriptor<MealComponent>()).count == 1)
    }

    @Test func explicitDeletionRetractsOnlyThatPlansHistory() throws {
        let fixture = try Fixture()
        let store = PlannedMealStore(context: fixture.context)
        try store.save(fixture.draft, id: nil, mealType: .lunch, day: nil)
        try store.save(fixture.draft, id: nil, mealType: .lunch, day: nil)
        let plans = try fixture.context.fetch(FetchDescriptor<PlannedMeal>())
        let deletedID = try #require(plans.first?.id)
        let retainedID = try #require(plans.last?.id)

        try store.delete(id: deletedID)

        let verification = ModelContext(fixture.context.container)
        #expect(try verification.fetch(FetchDescriptor<PlannedMeal>()).map(\.id) == [retainedID])
        #expect(try verification.fetch(FetchDescriptor<MealHistory>()).map(\.id) == [retainedID])
    }

    @Test func failedValidationDoesNotCreateOrChangeHistory() throws {
        let fixture = try Fixture()
        let store = PlannedMealStore(context: fixture.context)
        var invalid = fixture.draft
        invalid.servings = 0
        #expect(throws: PlannedMealStore.Error.self) {
            try store.save(invalid, id: nil, mealType: .lunch, day: nil)
        }
        #expect(try fixture.context.fetch(FetchDescriptor<MealHistory>()).isEmpty)
        #expect(!fixture.context.hasChanges)
        try store.save(fixture.draft, id: nil, mealType: .lunch, day: nil)
        let plan = try #require(fixture.context.fetch(FetchDescriptor<PlannedMeal>()).first)
        let history = try #require(fixture.context.fetch(MealHistory.descriptor(id: plan.id)).first)
        let snapshot = history.componentData
        let date = history.savedAt
        var missingSource = try store.draft(id: plan.id)
        missingSource.components[0].source = .recipe(UUID())
        #expect(throws: PlannedMealStore.Error.self) {
            try store.save(missingSource, id: plan.id, mealType: .lunch, day: nil)
        }
        #expect(!fixture.context.hasChanges)
        let persisted = try #require(ModelContext(fixture.context.container)
            .fetch(MealHistory.descriptor(id: plan.id)).first)
        #expect(persisted.componentData == snapshot)
        #expect(persisted.savedAt == date)
    }

    @Test func snapshotsAndSubstitutionsSurviveClearingAndReopeningTheFileStore() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration("History", schema: Models.schema,
                                               url: directory.appendingPathComponent("store"), cloudKitDatabase: .none)
        let expected = try autoreleasepool {
            let container = try ModelContainer(for: Models.schema, configurations: [configuration])
            let fixture = try Fixture(context: ModelContext(container))
            var recipe = MealComponentDraft(source: .recipe(fixture.recipe.id), course: .main)
            recipe.updateIngredient(RecipieIngredientDraft(
                id: fixture.ingredient.id, itemID: fixture.substitute.id,
                unitID: fixture.count.id, quantity: 3
            ), in: fixture.recipe)
            let portion = MealComponentDraft(source: .ingredient(fixture.item.id), course: .side,
                                             quantity: 0.5, unitID: fixture.count.id)
            let readymeal = MealComponentDraft(source: .readymeal(fixture.readymeal.id), course: .starter)
            try PlannedMealStore(context: fixture.context).save(
                PlannedMealDraft(components: [recipe, portion, readymeal], servings: 5),
                id: nil, mealType: .dinner, day: .sunday
            )
            let history = try #require(fixture.context.fetch(FetchDescriptor<MealHistory>()).first)
            let result = (id: history.id, name: history.name, components: history.components)
            try PlannerStore(context: fixture.context).clear()
            return result
        }

        try autoreleasepool {
            let container = try ModelContainer(for: Models.schema, configurations: [configuration])
            let context = ModelContext(container)
            let history = try #require(context.fetch(MealHistory.descriptor(id: expected.id)).first)
            #expect(try context.fetch(FetchDescriptor<PlannedMeal>()).isEmpty)
            #expect(try context.fetch(FetchDescriptor<MealComponent>()).isEmpty)
            #expect(history.components == expected.components)
            #expect(history.name == expected.name)
            #expect(history.mealTypeEnum == .dinner)
            #expect(history.servings == 5)
            #expect(history.components.map(\.kind) == [.readymeal, .recipe, .ingredient])
            #expect(history.components[1].ingredientOverrides.first?.quantity == 3)
            #expect(history.components[2].quantity == 0.5)
            #expect(history.draft.validate().isEmpty)

            for recipe in try context.fetch(FetchDescriptor<Recipie>()) { context.delete(recipe) }
            for item in try context.fetch(FetchDescriptor<Item>()) { context.delete(item) }
            try context.save()
            let retained = try #require(ModelContext(container).fetch(MealHistory.descriptor(id: expected.id)).first)
            #expect(retained.components == expected.components)
            #expect(retained.name == expected.name)
        }
    }

    @Test func startupMigratesAndBackfillsLegacyPlansOnceWithoutChangingNamedMeals() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("store")
        let legacySchema = Schema([
            meal_planner_ios.Category.self, meal_planner_ios.Unit.self, AppSettings.self, Item.self,
            RecipieIngredient.self, Recipie.self, MealComponent.self, Meal.self,
            PlannedMeal.self, PlannedMiscEntry.self, ShoppingListEntry.self,
        ])
        let expected = try autoreleasepool {
            let configuration = ModelConfiguration("Legacy", schema: legacySchema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: legacySchema, configurations: [configuration])
            let fixture = try Fixture(context: ModelContext(container))
            let plan = PlannedMeal(mealType: .lunch, components: [MealComponent(recipe: fixture.recipe)])
            let template = Meal(name: "Keep this saved meal", mealType: .dinner,
                                components: [MealComponent(recipe: fixture.otherRecipe, course: .side)])
            fixture.context.insert(plan)
            fixture.context.insert(template)
            try fixture.context.save()
            return (planID: plan.id, templateID: template.id, recipeID: fixture.recipe.id)
        }
        let configuration = ModelConfiguration("Legacy", schema: Models.schema, url: url, cloudKitDatabase: .none)
        let firstDate = try autoreleasepool {
            let models = Models(configuration: configuration)
            let histories = try models.context.fetch(FetchDescriptor<MealHistory>())
            let history = try #require(histories.first)
            #expect(histories.count == 1)
            #expect(history.id == expected.planID)
            #expect(history.components.first?.sourceID == expected.recipeID)
            #expect(try models.context.fetch(Meal.descriptor(id: expected.templateID)).first?.name == "Keep this saved meal")
            #expect(try models.context.fetch(FetchDescriptor<PlannedMeal>()).count == 1)
            return history.savedAt
        }
        try autoreleasepool {
            let models = Models(configuration: configuration)
            let histories = try models.context.fetch(FetchDescriptor<MealHistory>())
            #expect(histories.count == 1)
            #expect(histories.first?.savedAt == firstDate)
            #expect(histories.first?.id == expected.planID)
        }
    }

    @Test func fullResetRemovesRememberedChoices() throws {
        let fixture = try Fixture()
        try PlannedMealStore(context: fixture.context).save(fixture.draft, id: nil, mealType: .lunch, day: nil)
        #expect(try fixture.context.fetch(FetchDescriptor<MealHistory>()).count == 1)

        Models.reset(fixture.context)

        #expect(try ModelContext(fixture.context.container).fetch(FetchDescriptor<MealHistory>()).isEmpty)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MealHistoryTests-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @MainActor private struct Fixture {
        let context: ModelContext
        let count: meal_planner_ios.Unit
        let item: Item
        let substitute: Item
        let readymeal: Item
        let ingredient: RecipieIngredient
        let recipe: Recipie
        let otherRecipe: Recipie

        init(context: ModelContext? = nil) throws {
            self.context = try context ?? makeTestContext(autosaveEnabled: false)
            self.context.autosaveEnabled = false
            let units = try UnitStore.ensureBaseUnits(in: self.context)
            count = units.count
            let category = meal_planner_ios.Category(name: "Food", order: 0)
            item = Item(name: "Carrots", category: category, kind: .ingredient)
            substitute = Item(name: "Peas", category: category, kind: .ingredient)
            readymeal = Item(name: "Soup pot", category: category, kind: .readymeal, readymealData: .default)
            ingredient = RecipieIngredient(item: item, unit: count, quantity: 2)
            recipe = Recipie(name: "Carrot soup", serves: 2, ingredients: [ingredient])
            otherRecipe = Recipie(name: "Pea soup", serves: 2,
                                  ingredients: [RecipieIngredient(item: substitute, unit: count, quantity: 1)])
            self.context.insert(category)
            self.context.insert(item)
            self.context.insert(substitute)
            self.context.insert(readymeal)
            self.context.insert(recipe)
            self.context.insert(otherRecipe)
            self.context.insert(AppSettings(preferredVolume: units.volume, preferredWeight: units.weight))
            try self.context.save()
        }

        var draft: PlannedMealDraft {
            PlannedMealDraft(components: [MealComponentDraft(source: .recipe(recipe.id))])
        }
    }
}
