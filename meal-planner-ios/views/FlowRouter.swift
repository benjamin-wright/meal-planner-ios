//
//  FlowRouter.swift
//  meal-planner-ios
//

import Observation
import SwiftUI

@MainActor
@Observable
final class FlowRouter {
    enum Route: Hashable {
        // Data roots
        case units
        case categories
        case items
        case recipies
        case meals

        // Planner destinations.
        case newPlannedMeal(mealType: MealType, day: Day?)
        case editPlannedMeal(UUID)
        case plannerMealPicker(MealType)
        case newPlannedMisc
        case editPlannedMisc(UUID)

        // Shared catalog and editor destinations.
        case categoryPicker
        case newCategory
        case editCategory(UUID)
        case itemPicker
        case newItem
        case editItem(UUID)
        case unitPicker
        case newUnit(UnitType)
        case editUnit(id: UUID, type: UnitType)
        case dishPicker(courseFilter: CourseType, mealFilter: MealType)
        case newRecipie(MealType)
        case editRecipie(UUID)
        case recipieIngredient
        case mealPicker
        case newMeal(MealType)
        case editMeal(UUID)
    }

    var path: [Route] = []
    var selectedCategoryID = UUID()
    var selectedItemID = UUID()
    var selectedUnitID = UUID()
    var selectedDishID: DishID = .recipe(UUID())
    var selectedMealID = UUID()
    private(set) var recipieIngredient: RecipieIngredientDraft?
    private(set) var isEditingRecipieIngredient = false

    private var onCategorySelected: ((UUID) -> Void)?
    private var onItemSelected: ((UUID) -> Void)?
    private var onUnitSelected: ((UUID) -> Void)?
    private var onDishSelected: ((DishID) -> Void)?
    private var onMealSelected: ((UUID) -> Void)?
    private var onRecipieIngredientSaved: ((RecipieIngredientDraft) -> Void)?

    func showCategoryPicker(selectedID: UUID, onSelect: @escaping (UUID) -> Void) {
        selectedCategoryID = selectedID
        onCategorySelected = onSelect
        path.append(.categoryPicker)
    }

    func selectCategory(_ id: UUID) {
        selectedCategoryID = id
        onCategorySelected?(id)
    }

    func showItemPicker(selectedID: UUID, onSelect: @escaping (UUID) -> Void) {
        selectedItemID = selectedID
        onItemSelected = onSelect
        path.append(.itemPicker)
    }

    func selectItem(_ id: UUID) {
        selectedItemID = id
        onItemSelected?(id)
    }

    func showUnitPicker(selectedID: UUID, onSelect: @escaping (UUID) -> Void) {
        selectedUnitID = selectedID
        onUnitSelected = onSelect
        path.append(.unitPicker)
    }

    func selectUnit(_ id: UUID) {
        selectedUnitID = id
        onUnitSelected?(id)
    }
    
    func showDishPicker(
        selectedID: DishID,
        courseFilter: CourseType,
        mealFilter: MealType,
        onSelect: @escaping (DishID) -> Void
    ) {
        selectedDishID = selectedID
        onDishSelected = onSelect
        path.append(.dishPicker(courseFilter: courseFilter, mealFilter: mealFilter))
    }

    func selectDish(_ dish: DishID) {
        selectedDishID = dish
        onDishSelected?(dish)
    }

    func showMealPicker(selectedID: UUID, onSelect: @escaping (UUID) -> Void) {
        selectedMealID = selectedID
        onMealSelected = onSelect
        path.append(.mealPicker)
    }

    func selectMeal(_ id: UUID) {
        selectedMealID = id
        onMealSelected?(id)
    }

    func showPlannerMealPicker(mealType: MealType, onSelect: @escaping (UUID) -> Void) {
        selectedMealID = UUID()
        onMealSelected = onSelect
        path.append(.plannerMealPicker(mealType))
    }

    func showRecipieIngredient(
        _ ingredient: RecipieIngredientDraft,
        isEditing: Bool,
        onSave: @escaping (RecipieIngredientDraft) -> Void
    ) {
        recipieIngredient = ingredient
        isEditingRecipieIngredient = isEditing
        onRecipieIngredientSaved = onSave
        path.append(.recipieIngredient)
    }

    func saveRecipieIngredient(_ ingredient: RecipieIngredientDraft) {
        onRecipieIngredientSaved?(ingredient)
    }
}
