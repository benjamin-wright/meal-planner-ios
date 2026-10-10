import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct PlannerInvariantTests {
    @Test
    func anotherMealTypesTemplateCanFillAnExistingDinnerSlot() throws {
        for templateType in [MealType.breakfast, .lunch] {
            let fixture = try makeFixture()
            let context = fixture.context
            let store = PlannedMealStore(context: context)
            try store.save(fixture.draft, id: nil, mealType: .dinner, day: .monday)
            let planned = try #require(context.fetch(FetchDescriptor<PlannedMeal>()).first)
            let template = Meal(name: "Selected template", mealType: templateType, components: [
                MealComponent(readymeal: fixture.readymeal, course: .side)
            ])
            context.insert(template)
            try context.save()

            try store.save(PlannedMealDraft(meal: template), id: planned.id,
                           mealType: .dinner, day: .monday, sourceMealID: template.id)

            let persisted = try #require(ModelContext(context.container)
                .fetch(PlannedMeal.descriptor(id: planned.id)).first)
            #expect(persisted.mealTypeEnum == .dinner)
            #expect(persisted.dayEnum == .monday)
            #expect(persisted.sourceMealID == template.id)
            #expect(persisted.components.first?.courseEnum == .side)
            #expect(persisted.components.first?.id != template.components.first?.id)
            #expect(template.mealType == templateType)
        }
    }

    @Test
    func aDinnerTemplateCanFillAnUndatedPlannerList() throws {
        for mealType in [MealType.breakfast, .lunch] {
            let fixture = try makeFixture()
            let context = fixture.context
            let template = Meal(name: "Dinner template", mealType: .dinner, components: [
                MealComponent(readymeal: fixture.readymeal)
            ])
            context.insert(template)
            try context.save()

            try PlannedMealStore(context: context).save(PlannedMealDraft(meal: template), id: nil,
                                                       mealType: mealType, day: nil, sourceMealID: template.id)

            let persisted = try #require(ModelContext(context.container)
                .fetch(FetchDescriptor<PlannedMeal>()).first)
            #expect(persisted.mealTypeEnum == mealType)
            #expect(persisted.dayEnum == nil)
            #expect(persisted.sourceMealID == template.id)
        }
    }

    @Test
    func creatingAnInvisiblePlannerPlacementIsRejectedBeforeMutation() throws {
        for mealType in MealType.allCases {
            let fixture = try makeFixture()
            let context = fixture.context
            let day: Day? = mealType == .dinner ? nil : .monday

            #expect(throws: PlannedMealStore.Error.self) {
                try PlannedMealStore(context: context).save(fixture.draft, id: nil, mealType: mealType, day: day)
            }

            #expect(!context.hasChanges)
            let verification = ModelContext(context.container)
            #expect(try verification.fetch(FetchDescriptor<PlannedMeal>()).isEmpty)
            #expect(try verification.fetch(FetchDescriptor<MealComponent>()).isEmpty)
        }
    }

    @Test
    func editingToAnInvisiblePlacementLeavesTheSavedDinnerUnchanged() throws {
        for mealType in MealType.allCases {
            let fixture = try makeFixture()
            let context = fixture.context
            let store = PlannedMealStore(context: context)
            try store.save(fixture.draft, id: nil, mealType: .dinner, day: .monday)
            let planned = try #require(context.fetch(FetchDescriptor<PlannedMeal>()).first)
            let componentID = try #require(planned.components.first?.id)
            var draft = try store.draft(id: planned.id)
            draft.servings = 4
            draft.components[0].course = .dessert
            let day: Day? = mealType == .dinner ? nil : .monday

            #expect(throws: PlannedMealStore.Error.self) {
                try store.save(draft, id: planned.id, mealType: mealType, day: day)
            }

            #expect(!context.hasChanges)
            #expect(planned.mealTypeEnum == .dinner)
            #expect(planned.dayEnum == .monday)
            #expect(planned.servings == 2)
            let persisted = try #require(ModelContext(context.container)
                .fetch(PlannedMeal.descriptor(id: planned.id)).first)
            #expect(persisted.mealTypeEnum == .dinner)
            #expect(persisted.dayEnum == .monday)
            #expect(persisted.servings == 2)
            #expect(persisted.components.first?.id == componentID)
            #expect(persisted.components.first?.courseEnum == .main)
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
        let category = meal_planner_ios.Category(name: "Food", order: 0)
        let readymeal = Item(name: "Pasta pot", category: category, kind: .readymeal,
                             readymealData: .default)
        context.insert(category)
        context.insert(readymeal)
        try context.save()
        return Fixture(context: context, readymeal: readymeal)
    }

    private struct Fixture {
        let context: ModelContext
        let readymeal: Item

        var draft: PlannedMealDraft {
            PlannedMealDraft(components: [MealComponentDraft(source: .readymeal(readymeal.id))])
        }
    }
}
