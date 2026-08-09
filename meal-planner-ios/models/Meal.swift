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

    var id: UUID {
        switch self {
        case .recipe(let id), .readymeal(let id):
            return id
        }
    }
}

struct MealDraft {
    enum ValidationError: Hashable, LocalizedError {
        case nameTooShort
        case duplicateName
        case invalidServings
        case missingDays
        case noDishes

        var errorDescription: String? {
            switch self {
            case .nameTooShort:
                return "Meal names must be at least 3 characters."
            case .duplicateName:
                return "A meal with this name already exists."
            case .invalidServings:
                return "Meals must serve at least one person."
            case .missingDays:
                return "Meals must be assigned to at least one day."
            case .noDishes:
                return "Please add at least one dish."
            }
        }
    }

    var name: String
    var mealType: MealType
    var dishes: [DishID]

    init(mealType: MealType = .dinner) {
        self.name = ""
        self.mealType = mealType
        self.dishes = []
    }

    init(meal: Meal) {
        self.name = meal.name
        self.mealType = meal.mealType
        self.dishes = meal.recipies.map { .recipe($0.id) }
            + meal.readymeals.map { .readymeal($0.id) }
    }

    /// Mirrors the `validate` function from the TS model.
    func validate(existingNames: [String] = []) -> [ValidationError] {
        var errors: [ValidationError] = []

        if name.count < 3 {
            errors.append(.nameTooShort)
        }
        if existingNames.contains(name) {
            errors.append(.duplicateName)
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
    var name: String = ""
    var mealType: MealType
    @Relationship(deleteRule: .nullify)
    var recipies: [Recipie]
    @Relationship(deleteRule: .nullify)
    var readymeals: [Item]

    init(
        id: UUID = UUID(),
        name: String = "",
        mealType: MealType,
        recipies: [Recipie] = [],
        readymeals: [Item] = []
    ) {
        self.id = id
        self.name = name
        self.mealType = mealType
        self.recipies = recipies
        self.readymeals = readymeals
    }

    /// Mirrors the `validate` function from the TS model.
    var isValid: Bool {
        if name.count < 3 { return false }
        if recipies.isEmpty && readymeals.isEmpty { return false }
        return true
    }
}

extension Meal {
    static func descriptor(id: UUID) -> FetchDescriptor<Meal> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }
}
