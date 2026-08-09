//
//  FlowDestination.swift
//  meal-planner-ios
//

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
        @Bindable var router = router

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
        case .plannerDay, .plannerMeal:
            ContentUnavailableView("Planner Navigation", systemImage: "calendar")
        case .categoryPicker:
            CategoryPicker(categories: categories, selectedID: $router.selectedCategoryID)
        case .newCategory:
            CategoryEdit()
        case .editCategory(let id):
            CategoryEdit(id: id)
        case .itemPicker:
            ItemPicker(items: items, selectedID: $router.selectedItemID)
        case .newItem:
            ItemEdit()
        case .editItem(let id):
            ItemEdit(id: id)
        case .unitPicker:
            UnitPicker(units: units, selectedID: $router.selectedUnitID)
        case .newUnit(let type):
            UnitEdit(type: type)
        case .editUnit(let id, let type):
            UnitEdit(id: id, type: type)
        case .dishPicker(let courseFilter):
            DishPicker(
                recipies: recipies,
                readymeals: items,
                selectedID: $router.selectedDishID,
                initialCourseFilter: courseFilter
            )
        case .newRecipie(let mealType):
            RecipieEdit(mealType: mealType)
        case .editRecipie(let id):
            if let recipie = recipies.first(where: { $0.id == id }) {
                RecipieEdit(id: id, mealType: recipie.mealTypeEnum)
            } else {
                ContentUnavailableView("Recipe Not Found", systemImage: "exclamationmark.triangle")
            }
        case .recipieIngredient:
            if let ingredient = router.recipieIngredient {
                RecipieIngredientEdit(
                    edit: router.isEditingRecipieIngredient,
                    value: ingredient,
                    items: items,
                    units: units,
                    action: router.saveRecipieIngredient
                )
            } else {
                ContentUnavailableView("Ingredient Not Found", systemImage: "exclamationmark.triangle")
            }
        case .mealPicker:
            MealPicker(meals: meals, selectedID: $router.selectedMealID)
        case .newMeal(let mealType):
            MealEdit(mealType: mealType)
        case .editMeal(let id):
            if let meal = meals.first(where: { $0.id == id }) {
                MealEdit(id: id, mealType: meal.mealType)
            } else {
                ContentUnavailableView("Meal Not Found", systemImage: "exclamationmark.triangle")
            }
        }
    }
}
