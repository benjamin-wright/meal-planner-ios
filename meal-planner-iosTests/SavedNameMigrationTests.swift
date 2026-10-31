import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct SavedNameMigrationTests {
    @Test func legacyFileStoreMigratesNamesWithoutLosingRecordsOrContent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Names.store")
        // This is the actual previous schema: all existing models, without the
        // new migration-record entity. It does not modify current model metadata.
        let oldSchema = Schema([
            meal_planner_ios.Category.self, meal_planner_ios.Unit.self,
            AppSettings.self, Item.self, RecipieIngredient.self,
            Recipie.self, MealComponent.self, Meal.self, PlannedMeal.self, MealHistory.self,
            PlannedMiscEntry.self, ShoppingListEntry.self,
        ])
        #expect(oldSchema.entitiesByName["SavedNameMigrationRecord"] == nil)
        let expected = try autoreleasepool {
            let configuration = ModelConfiguration("Names", schema: oldSchema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: oldSchema, configurations: [configuration])
            let context = ModelContext(container)
            let weight = makeUnit(.weight, name: "Grams")
            let volume = makeUnit(.volume, name: "Litres")
            let count = makeUnit(.count, name: "Count")
            let magnitude = Magnitude(abbreviation: "mL", singular: "Millilitre", plural: "Millilitres", multiplier: 0.001)
            let customUnit = meal_planner_ios.Unit(name: "Custom Volume", type: .volume,
                                                   base: 2, magnitudes: [magnitude])
            let category = meal_planner_ios.Category(name: "Fresh Food", order: 7)
            let item = Item(name: "Tomatoes", category: category, kind: .ingredient)
            let ingredient = RecipieIngredient(item: item, unit: weight, quantity: 200,
                                               sourceText: "200 g Tomatoes, Chopped")
            let recipe = Recipie(name: "Tomato Soup", summary: "Keep This Summary.",
                                  serves: 4, time: 30, ingredients: [ingredient],
                                  steps: ["Keep This Step."])
            let duplicate = Recipie(name: "tomato soup", summary: "Keep The Duplicate.")
            let meal = Meal(name: "Family Dinner", mealType: .dinner,
                            components: [MealComponent(recipe: recipe)])
            let history = try MealHistory(name: "Remembered Dinner", mealType: .dinner,
                                           servings: 4, components: meal.components.map { MealComponentDraft(component: $0) },
                                           savedAt: Date(timeIntervalSince1970: 123_456))
            let note = PlannedMiscEntry(note: PlannedMiscNote(text: "Keep This Note.", category: category),
                                        quantity: 3, unit: count, sortOrder: 8)
            let shopping = ShoppingListEntry(name: "Tomatoes", quantity: 200, sortOrder: 9,
                                              isChecked: true, item: item, category: category, unit: weight)
            let shoppingNote = ShoppingListEntry(name: "Birthday Candles", quantity: 12,
                                                  category: category, unit: count)
            context.insert(AppSettings(preferredVolume: volume, preferredWeight: weight))
            context.insert(count)
            context.insert(customUnit)
            context.insert(recipe)
            context.insert(duplicate)
            context.insert(meal)
            context.insert(history)
            context.insert(note)
            context.insert(shopping)
            context.insert(shoppingNote)
            try context.save()
            return LegacySnapshot(recipeID: recipe.id, duplicateID: duplicate.id, ingredientID: ingredient.id,
                                  componentID: meal.components[0].id, historyID: history.id,
                                  historyData: history.componentData, shoppingID: shopping.id,
                                  customUnitID: customUnit.id, weightID: weight.id, magnitude: magnitude)
        }
        let configuration = ModelConfiguration("Names", schema: Models.schema, url: url, cloudKitDatabase: .none)
        try autoreleasepool {
            let models = Models(configuration: configuration)
            let context = models.context
            let settings = try #require(context.fetch(FetchDescriptor<AppSettings>()).first)
            let records = try context.fetch(FetchDescriptor<SavedNameMigrationRecord>())
            #expect(records.map(\.id) == [SavedNameMigration.identifier])
            let categories = try context.fetch(FetchDescriptor<meal_planner_ios.Category>())
            let category = try #require(categories.first)
            #expect(categories.count == 1 && category.name == "fresh food" && category.order == 7)
            let items = try context.fetch(FetchDescriptor<Item>())
            let item = try #require(items.first)
            #expect(items.count == 1 && item.name == "tomatoes" && item.category.id == category.id)
            let recipes = try context.fetch(FetchDescriptor<Recipie>())
            #expect(Set(recipes.map(\.id)) == [expected.recipeID, expected.duplicateID])
            #expect(recipes.allSatisfy { $0.name == "tomato soup" })
            let recipe = try #require(recipes.first { $0.id == expected.recipeID })
            #expect(recipe.summary == "Keep This Summary." && recipe.steps == ["Keep This Step."])
            #expect(recipe.serves == 4 && recipe.time == 30)
            #expect(recipes.first { $0.id == expected.duplicateID }?.summary == "Keep The Duplicate.")
            let ingredient = try #require(recipe.ingredients.first)
            #expect(ingredient.id == expected.ingredientID && ingredient.item.id == item.id)
            #expect(ingredient.unit.id == expected.weightID && ingredient.quantity == 200)
            #expect(ingredient.sourceText == "200 g Tomatoes, Chopped")
            let meal = try #require(context.fetch(FetchDescriptor<Meal>()).first)
            #expect(meal.name == "family dinner" && meal.components.count == 1)
            #expect(meal.components.first?.id == expected.componentID)
            #expect(meal.components.first?.recipe?.id == recipe.id)
            let history = try #require(context.fetch(MealHistory.descriptor(id: expected.historyID)).first)
            #expect(history.name == "remembered dinner" && history.servings == 4)
            #expect(history.componentData == expected.historyData)
            #expect(history.savedAt == Date(timeIntervalSince1970: 123_456))
            let note = try #require(context.fetch(FetchDescriptor<PlannedMiscEntry>()).first)
            #expect(note.noteText == "Keep This Note." && note.quantity == 3 && note.sortOrder == 8)
            let shopping = try context.fetch(FetchDescriptor<ShoppingListEntry>())
            #expect(Set(shopping.map(\.name)) == ["tomatoes", "birthday candles"])
            let linked = try #require(shopping.first { $0.id == expected.shoppingID })
            #expect(linked.isChecked && linked.quantity == 200 && linked.sortOrder == 9)
            #expect(linked.item?.id == item.id && linked.category?.id == category.id)
            #expect(linked.unit?.id == expected.weightID)
            let units = try context.fetch(FetchDescriptor<meal_planner_ios.Unit>())
            #expect(Set(units.map(\.name)) == ["count", "grams", "litres", "custom volume"])
            #expect(units.count == 4)
            #expect(units.first { $0.id == expected.weightID }?.isBaseUnit == true)
            #expect(settings.preferredWeight.id == expected.weightID)
            let custom = try #require(units.first { $0.id == expected.customUnitID })
            #expect(custom.base == 2 && custom.magnitudes == [expected.magnitude])

            recipe.name = "Later Name"
            try context.save()
        }
        try autoreleasepool {
            let models = Models(configuration: configuration)
            let recipe = try #require(models.context.fetch(Recipie.descriptor(id: expected.recipeID)).first)
            let records = try models.context.fetch(FetchDescriptor<SavedNameMigrationRecord>())
            #expect(recipe.name == "Later Name")
            #expect(records.map(\.id) == [SavedNameMigration.identifier])
        }
    }

    @Test func migrationMarkerIsScopedToEachStore() throws {
        let first = try makeStore(name: "First Recipe")
        let second = try makeStore(name: "Second Recipe")
        try SavedNameMigration.apply(in: first.context)
        try first.context.save()
        #expect(first.recipe.name == "first recipe")
        #expect(try migrationIDs(in: first.context) == [SavedNameMigration.identifier])
        #expect(second.recipe.name == "Second Recipe")
        #expect(try migrationIDs(in: second.context).isEmpty)

        first.recipe.name = "Later Name"
        try first.context.save()
        try SavedNameMigration.apply(in: first.context)
        #expect(first.recipe.name == "Later Name" && !first.context.hasChanges)
        #expect(try migrationIDs(in: first.context) == [SavedNameMigration.identifier])
        try SavedNameMigration.apply(in: second.context)
        try second.context.save()
        #expect(second.recipe.name == "second recipe")
        #expect(try migrationIDs(in: second.context) == [SavedNameMigration.identifier])
    }

    @Test func stagedMigrationCanRollBackAndRetryWithoutMarkingTheStoreComplete() throws {
        let fixture = try makeStore(name: "Retry Recipe")
        let unrelatedIdentifier = "unrelated-migration"
        fixture.context.insert(SavedNameMigrationRecord(id: unrelatedIdentifier))
        try fixture.context.save()

        try SavedNameMigration.apply(in: fixture.context)
        #expect(fixture.recipe.name == "retry recipe")
        #expect(try migrationIDs(in: fixture.context) == [unrelatedIdentifier, SavedNameMigration.identifier])
        #expect(fixture.context.hasChanges)
        let beforeCommit = ModelContext(fixture.context.container)
        #expect(try beforeCommit.fetch(Recipie.descriptor(id: fixture.recipe.id)).first?.name == "Retry Recipe")
        #expect(try migrationIDs(in: beforeCommit) == [unrelatedIdentifier])

        fixture.context.rollback()
        #expect(fixture.recipe.name == "Retry Recipe" && !fixture.context.hasChanges)
        #expect(try migrationIDs(in: fixture.context) == [unrelatedIdentifier])
        try SavedNameMigration.apply(in: fixture.context)
        try fixture.context.save()
        let persisted = ModelContext(fixture.context.container)
        #expect(try persisted.fetch(Recipie.descriptor(id: fixture.recipe.id)).first?.name == "retry recipe")
        #expect(try migrationIDs(in: persisted) == [unrelatedIdentifier, SavedNameMigration.identifier])
    }

    private func makeUnit(_ type: UnitType, name: String) -> meal_planner_ios.Unit {
        let definition = UnitDefinition.baseUnit(for: type)
        return meal_planner_ios.Unit(name: name, type: type, base: definition.base,
                                     magnitudes: definition.magnitudes)
    }

    private func makeStore(name: String) throws -> (context: ModelContext, recipe: Recipie) {
        let context = try makeTestContext(autosaveEnabled: false)
        let settings = AppSettings(preferredVolume: makeUnit(.volume, name: "Litres"),
                                    preferredWeight: makeUnit(.weight, name: "Grams"))
        let recipe = Recipie(name: name)
        context.insert(settings)
        context.insert(recipe)
        try context.save()
        return (context, recipe)
    }

    private func migrationIDs(in context: ModelContext) throws -> Set<String> {
        Set(try context.fetch(FetchDescriptor<SavedNameMigrationRecord>()).map(\.id))
    }

    private struct LegacySnapshot {
        let recipeID: UUID
        let duplicateID: UUID
        let ingredientID: UUID
        let componentID: UUID
        let historyID: UUID
        let historyData: Data
        let shoppingID: UUID
        let customUnitID: UUID
        let weightID: UUID
        let magnitude: Magnitude
    }
}
