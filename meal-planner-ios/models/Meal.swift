//
//  Meal.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 26/07/2026.
//

import Foundation
import SwiftData

enum DishID: Identifiable, Hashable {
    case recipe(UUID)
    case readymeal(UUID)
    case ingredient(UUID)

    var id: UUID {
        switch self {
        case .recipe(let id), .readymeal(let id), .ingredient(let id):
            return id
        }
    }
}

struct MealDraft: Hashable {
    enum ValidationError: Hashable, LocalizedError {
        case nameTooShort
        case duplicateName
        case noDishes
        case invalidPortion
        case duplicateComponent

        var errorDescription: String? {
            switch self {
            case .nameTooShort:
                return "Meal names must be at least 3 characters."
            case .duplicateName:
                return "A meal with this name already exists."
            case .noDishes:
                return "Please add at least one dish."
            case .invalidPortion:
                return "Ingredient portions need a valid unit and a finite quantity greater than zero."
            case .duplicateComponent:
                return "Each dish must have its own identifier."
            }
        }
    }

    var name: String
    var mealType: MealType
    var components: [MealComponentDraft]

    init(mealType: MealType = .dinner) {
        self.name = ""
        self.mealType = mealType
        self.components = []
    }

    init(plannedMeal: PlannedMealDraft, mealType: MealType) {
        self.name = ""
        self.mealType = mealType
        self.components = plannedMeal.components.map { MealComponentDraft(copying: $0) }
    }

    init(meal: Meal) {
        self.name = meal.name
        self.mealType = meal.mealType
        self.components = meal.orderedComponents.map { MealComponentDraft(component: $0) }
    }

    func validate(existingNames: [String] = []) -> [ValidationError] {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var errors: [ValidationError] = []

        if name.count < 3 {
            errors.append(.nameTooShort)
        }
        if existingNames.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == name }) {
            errors.append(.duplicateName)
        }
        if components.isEmpty {
            errors.append(.noDishes)
        }
        if !components.allSatisfy(\.hasValidPortion) {
            errors.append(.invalidPortion)
        }
        if Set(components.map(\.id)).count != components.count {
            errors.append(.duplicateComponent)
        }

        return errors
    }
}

@Model
final class Meal {
    @Attribute(.unique)
    var id: UUID = UUID()
    var name: String = ""
    var mealType: MealType
    @Relationship(deleteRule: .cascade, inverse: \MealComponent.meal)
    var components: [MealComponent] = []

    init(
        id: UUID = UUID(),
        name: String = "",
        mealType: MealType,
        components: [MealComponent] = []
    ) {
        self.id = id
        self.name = name
        self.mealType = mealType
        self.components = components
        components.enumerated().forEach { index, component in
            component.sortOrder = index
            component.meal = self
        }
    }

    var orderedComponents: [MealComponent] {
        components.sorted {
            $0.sortOrder == $1.sortOrder ? $0.id.uuidString < $1.id.uuidString : $0.sortOrder < $1.sortOrder
        }
    }

    var isValid: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 && !components.isEmpty && components.allSatisfy {
            $0.source != nil && MealComponentDraft(component: $0).hasValidPortion
        }
    }
}

extension Meal {
    static func descriptor(id: UUID) -> FetchDescriptor<Meal> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }
}
