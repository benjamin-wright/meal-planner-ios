//
//  Meal.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 26/07/2026.
//

import Foundation
import SwiftData

struct MealDraft {
    enum ValidationError: Hashable, LocalizedError {
        case invalidServings
        case missingDays
        case noDishes

        var errorDescription: String? {
            switch self {
            case .invalidServings:
                return "Meals must serve at least one person."
            case .missingDays:
                return "Dinners must be assigned to at least one day."
            case .noDishes:
                return "Please add at least one dish."
            }
        }
    }

    var servings: Int
    var mealType: MealType
    var dishes: [Dish]
    var days: [Day]

    init(mealType: MealType = .dinner) {
        self.servings = 2
        self.mealType = mealType
        self.dishes = []
        self.days = []
    }

    init(meal: Meal) {
        self.servings = meal.servings
        self.mealType = meal.mealType
        self.dishes = meal.dishes
        self.days = meal.days
    }

    /// Mirrors the `validate` function from the TS model.
    func validate() -> [ValidationError] {
        var errors: [ValidationError] = []

        if servings <= 0 {
            errors.append(.invalidServings)
        }
        if mealType == .dinner && days.isEmpty {
            errors.append(.missingDays)
        }
        if dishes.isEmpty {
            errors.append(.noDishes)
        }

        return errors
    }
}

@Model
final class Meal {
    @Attribute(.unique)
    var id: UUID = UUID()
    var servings: Int = 2
    var mealType: MealType
    var dishes: [Dish]
    var days: [Day]

    init(id: UUID = UUID(), servings: Int = 2, mealType: MealType, dishes: [Dish] = [], days: [Day] = []) {
        self.id = id
        self.servings = servings
        self.mealType = mealType
        self.dishes = dishes
        self.days = days
    }

    /// Mirrors the `validate` function from the TS model.
    var isValid: Bool {
        if servings <= 0 { return false }
        if mealType == .dinner && days.isEmpty { return false }
        if dishes.isEmpty { return false }
        return true
    }
}

extension Meal {
    static func descriptor(id: UUID) -> FetchDescriptor<Meal> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }
}
