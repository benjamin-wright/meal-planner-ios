import SwiftData
@testable import meal_planner_ios

func makeTestContext(
    _ models: [any PersistentModel.Type] = [
        meal_planner_ios.Category.self, meal_planner_ios.Unit.self, AppSettings.self, Item.self,
        RecipieIngredient.self, Recipie.self, MealComponent.self, Meal.self,
        PlannedMeal.self, MealHistory.self, PlannedMiscEntry.self, ShoppingListEntry.self,
    ],
    autosaveEnabled: Bool? = nil
) throws -> ModelContext {
    var models = models
    // Older focused fixtures list their planner models explicitly.
    if models.contains(where: { ObjectIdentifier($0) == ObjectIdentifier(PlannedMeal.self) }),
       !models.contains(where: { ObjectIdentifier($0) == ObjectIdentifier(MealHistory.self) }) {
        models.append(MealHistory.self)
    }
    let container = try ModelContainer(
        for: Schema(models), configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    if let autosaveEnabled {
        context.autosaveEnabled = autosaveEnabled
    }
    return context
}
