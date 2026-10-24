import SwiftUI
import SwiftData

struct FlowDestination: View {
    let route: FlowRouter.Route

    @Environment(FlowRouter.self) private var router
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \Item.category.order) private var items: [Item]
    @Query(sort: \Unit.name) private var units: [Unit]
    @Query private var recipies: [Recipie]
    @Query private var meals: [Meal]

    var body: some View {
        switch route {
        case .units:
            UnitsView()
        case .categories:
            CategoriesView()
        case .items:
            ItemsView()
        case .recipies:
            RecipiesView()
        case .meals:
            MealsView()
        case .newPlannedMeal(let mealType, let day):
            PlannedMealEdit(mealType: mealType, day: day)
        case .editPlannedMeal(let id):
            PlannedMealEdit(id: id)
        case .newPlannedMisc:
            PlannedMiscEdit()
        case .editPlannedMisc(let id):
            PlannedMiscEdit(id: id)
        case .categoryPicker(let session):
            CategoryPicker(categories: categories, selectedID: session.initialValue) {
                router.complete(session, with: $0)
            }
        case .newCategory:
            CategoryEdit()
        case .editCategory(let id):
            CategoryEdit(id: id)
        case .itemPicker(let session, let kindFilter):
            ItemPicker(items: items, selectedID: session.initialValue, kindFilter: kindFilter) {
                router.complete(session, with: $0)
            }
        case .newItem:
            ItemEdit()
        case .editItem(let id):
            ItemEdit(id: id)
        case .unitPicker(let session, let typeFilter):
            UnitPicker(units: units, selectedID: session.initialValue, typeFilter: typeFilter) {
                router.complete(session, with: $0)
            }
        case .newUnit(let type):
            UnitEdit(type: type)
        case .editUnit(let id, let type):
            UnitEdit(id: id, type: type)
        case .dishPicker(let session, let initialCourse):
            DishPicker(recipies: recipies, items: items, units: units, initialCourse: initialCourse) {
                router.complete(session, with: $0)
            }
        case .mealComponent(let session, let isEditing):
            if let component = session.initialValue {
                MealComponentEdit(
                    value: component, isEditing: isEditing,
                    recipies: recipies, items: items, units: units
                ) { router.complete(session, with: $0) }
            }
        case .plannedRecipe(let session):
            if let component = session.initialValue,
               case .recipe(let id) = component.source,
               let recipe = recipies.first(where: { $0.id == id }) {
                PlannedRecipeEdit(component: component, recipe: recipe, items: items, units: units) {
                    router.complete(session, with: $0)
                }
            } else {
                ContentUnavailableView("Recipe Not Found", systemImage: "exclamationmark.triangle")
            }
        case .newRecipie:
            RecipieEdit()
        case .editRecipie(let id):
            if recipies.contains(where: { $0.id == id }) {
                RecipieEdit(id: id)
            } else {
                ContentUnavailableView("Recipe Not Found", systemImage: "exclamationmark.triangle")
            }
        case .recipieIngredient(let session, let isEditing):
            if let ingredient = session.initialValue {
                RecipieIngredientEdit(edit: isEditing, value: ingredient, items: items, units: units) {
                    router.complete(session, with: $0)
                }
            }
        case .importedRecipieIngredient(let session):
            if let ingredient = session.initialValue {
                ImportedRecipieIngredientEdit(ingredient: ingredient, items: items, units: units) {
                    router.complete(session, with: $0)
                }
            }
        case .mealPicker(let session, let mealType):
            MealPicker(meals: meals, selectedID: session.initialValue, initialMealType: mealType) {
                router.complete(session, with: $0)
            }
        case .mealDiscovery(let session, let mealType, let plannedMealID):
            MealDiscoveryPicker(
                mealType: mealType, plannedMealID: plannedMealID,
                currentDraft: session.initialValue ?? PlannedMealDraft()
            ) {
                router.complete(session, with: $0)
            }
        case .newMeal(let mealType):
            MealEdit(mealType: mealType)
        case .newMealDraft(let draft):
            MealEdit(draft: draft)
        case .editMeal(let id):
            if let meal = meals.first(where: { $0.id == id }) {
                MealEdit(id: id, mealType: meal.mealType)
            } else {
                ContentUnavailableView("Meal Not Found", systemImage: "exclamationmark.triangle")
            }
        case .creation(let screen, let session):
            creation(screen) { router.complete(session, with: $0) }
        }
    }

    @ViewBuilder
    private func creation(_ screen: FlowRouter.CreationScreen, onCreate: @escaping (UUID) -> Void) -> some View {
        switch screen {
        case .category:
            CategoryEdit(onCreate: onCreate)
        case .item(let kind):
            ItemEdit(kind: kind ?? .ingredient, allowsKindChange: kind == nil, onCreate: onCreate)
        case .unit(let type, let allowsTypeChange):
            UnitEdit(type: type, allowsTypeChange: allowsTypeChange, onCreate: onCreate)
        case .recipe:
            RecipieEdit(onCreate: onCreate)
        case .meal(let mealType):
            MealEdit(mealType: mealType, onCreate: onCreate)
        }
    }
}
