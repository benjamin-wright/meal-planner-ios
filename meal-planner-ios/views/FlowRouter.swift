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
        case newItemOfKind(ItemKind)
        case editItem(UUID)
        case unitPicker(typeFilter: UnitType?)
        case newUnit(UnitType)
        case editUnit(id: UUID, type: UnitType)
        case dishPicker(course: CourseType)
        case mealComponent
        case newRecipie
        case editRecipie(UUID)
        case recipieIngredient
        case importedRecipieIngredient
        case mealPicker
        case newMeal(MealType)
        case newMealDraft(MealDraft)
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
    private(set) var importedRecipieIngredient: ImportedRecipieIngredient?
    private(set) var mealComponent: MealComponentDraft?
    private(set) var isEditingMealComponent = false

    private var onCategorySelected: ((UUID) -> Void)?
    private var onItemSelected: ((UUID) -> Void)?
    private var onUnitSelected: ((UUID) -> Void)?
    private var onDishSelected: ((MealComponentDraft) -> Void)?
    private var onMealSelected: ((UUID) -> Void)?
    private var onRecipieIngredientSaved: ((RecipieIngredientDraft) -> Void)?
    private var onImportedRecipieIngredientSaved: ((ImportedRecipieIngredient) -> Void)?
    private var onMealComponentSaved: ((MealComponentDraft) -> Void)?
    private var mealComponentReturnDepth = 0

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

    func showUnitPicker(selectedID: UUID, typeFilter: UnitType? = nil, onSelect: @escaping (UUID) -> Void) {
        selectedUnitID = selectedID
        onUnitSelected = onSelect
        path.append(.unitPicker(typeFilter: typeFilter))
    }

    func selectUnit(_ id: UUID) {
        selectedUnitID = id
        onUnitSelected?(id)
    }
    
    func showDishPicker(
        course: CourseType,
        onSelect: @escaping (MealComponentDraft) -> Void
    ) {
        selectedDishID = .recipe(UUID())
        onDishSelected = onSelect
        path.append(.dishPicker(course: course))
    }

    func selectDishComponent(_ component: MealComponentDraft) {
        selectedDishID = component.source
        onDishSelected?(component)
    }

    func showMealComponent(
        _ component: MealComponentDraft,
        isEditing: Bool,
        dismissDishPickerOnSave: Bool = false,
        onSave: @escaping (MealComponentDraft) -> Void
    ) {
        mealComponent = component
        isEditingMealComponent = isEditing
        onMealComponentSaved = onSave
        mealComponentReturnDepth = path.count
        if dismissDishPickerOnSave,
           let pickerIndex = path.lastIndex(where: {
               if case .dishPicker = $0 { return true }
               return false
           }) {
            mealComponentReturnDepth = pickerIndex
        }
        path.append(.mealComponent)
    }

    func saveMealComponent(_ component: MealComponentDraft) {
        onMealComponentSaved?(component)
        path = Array(path.prefix(mealComponentReturnDepth))
        onMealComponentSaved = nil
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

    func showImportedRecipieIngredient(
        _ ingredient: ImportedRecipieIngredient,
        onSave: @escaping (ImportedRecipieIngredient) -> Void
    ) {
        importedRecipieIngredient = ingredient
        onImportedRecipieIngredientSaved = onSave
        path.append(.importedRecipieIngredient)
    }

    func saveImportedRecipieIngredient(_ ingredient: ImportedRecipieIngredient) {
        onImportedRecipieIngredientSaved?(ingredient)
    }
}
