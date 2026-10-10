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
        case .newPlannedMeal(let mealType, let day):
            PlannedMealEdit(mealType: mealType, day: day)
        case .editPlannedMeal(let id):
            PlannedMealEdit(id: id)
        case .plannerMealPicker(let mealType):
            MealPicker(
                meals: meals,
                selectedID: $router.selectedMealID,
                initialMealType: mealType
            )
        case .newPlannedMisc:
            PlannedMiscEdit()
        case .editPlannedMisc(let id):
            PlannedMiscEdit(id: id)
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
        case .newItemOfKind(let kind):
            ItemEdit(kind: kind)
        case .editItem(let id):
            ItemEdit(id: id)
        case .unitPicker(let typeFilter):
            UnitPicker(units: units, selectedID: $router.selectedUnitID, typeFilter: typeFilter)
        case .newUnit(let type):
            UnitEdit(type: type)
        case .editUnit(let id, let type):
            UnitEdit(id: id, type: type)
        case .dishPicker(let course):
            DishPicker(
                recipies: recipies,
                items: items,
                units: units,
                selectedID: $router.selectedDishID,
                course: course
            )
        case .mealComponent:
            if let component = router.mealComponent {
                MealComponentEdit(
                    value: component,
                    isEditing: router.isEditingMealComponent,
                    recipies: recipies,
                    items: items,
                    units: units,
                    onSave: router.saveMealComponent
                )
            } else {
                ContentUnavailableView("Dish Not Found", systemImage: "exclamationmark.triangle")
            }
        case .newRecipie:
            RecipieEdit()
        case .editRecipie(let id):
            if recipies.contains(where: { $0.id == id }) {
                RecipieEdit(id: id)
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
        case .importedRecipieIngredient:
            if let ingredient = router.importedRecipieIngredient {
                ImportedRecipieIngredientEdit(
                    ingredient: ingredient, items: items, units: units,
                    onSave: router.saveImportedRecipieIngredient
                )
            } else {
                ContentUnavailableView("Ingredient Not Found", systemImage: "exclamationmark.triangle")
            }
        case .mealPicker:
            MealPicker(meals: meals, selectedID: $router.selectedMealID)
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
        }
    }
}
