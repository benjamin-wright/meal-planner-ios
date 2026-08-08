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

        // Planner roots, reserved for the forthcoming planner flow.
        case plannerDay(Date)
        case plannerMeal(UUID)

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
        case newRecipie(MealType)
        case editRecipie(UUID)
        case recipieIngredient
    }

    var path: [Route] = []
    var selectedCategoryID = UUID()
    var selectedItemID = UUID()
    var selectedUnitID = UUID()
    private(set) var recipieIngredient: RecipieIngredientDraft?
    private(set) var isEditingRecipieIngredient = false

    private var onCategorySelected: ((UUID) -> Void)?
    private var onItemSelected: ((UUID) -> Void)?
    private var onUnitSelected: ((UUID) -> Void)?
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
