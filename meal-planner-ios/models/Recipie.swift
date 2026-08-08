//  Recipie.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 04/10/2025.
//

import Foundation
import SwiftData

struct RecipieDraft {
    enum ValidationError: Hashable, LocalizedError {
        case nameTooShort
        case duplicateName

        var errorDescription: String? {
            switch self {
            case .nameTooShort:
                return "Recipe names must be at least 3 characters."
            case .duplicateName:
                return "A recipe with this name already exists."
            }
        }
    }

    var name: String
    var mealType: MealType
    var course: CourseType
    var summary: String
    var serves: Int
    var time: Int
    var ingredients: [RecipieIngredientDraft]
    var steps: [String]

    init() {
        self.name = ""
        self.mealType = .dinner
        self.course = .main
        self.summary = ""
        self.serves = 2
        self.time = 15
        self.ingredients = []
        self.steps = []
    }

    init(recipie: Recipie) {
        self.name = recipie.name
        self.mealType = recipie.mealTypeEnum
        self.course = recipie.courseEnum
        self.summary = recipie.summary
        self.serves = recipie.serves
        self.time = recipie.time
        self.ingredients = recipie.ingredients.map(RecipieIngredientDraft.init)
        self.steps = recipie.steps
    }

    func validate(existingNames: [String] = []) -> [ValidationError] {
        var errors: [ValidationError] = []

        if name.count < 3 {
            errors.append(.nameTooShort)
        }
        if existingNames.contains(name) {
            errors.append(.duplicateName)
        }

        return errors
    }
}

@Model
final class Recipie {
    @Attribute(.unique)
    var id: UUID = UUID()
    var name: String = ""
    var mealType: Int
    var course: Int
    var summary: String = ""
    var serves: Int = 2
    var time: Int = 15
    @Relationship(deleteRule: .cascade)
    var ingredients: [RecipieIngredient]
    var steps: [String]
    
    init(id: UUID = UUID(), name: String = "", mealType: MealType = .dinner, course: CourseType = .main, summary: String = "", serves: Int = 2, time: Int = 15, ingredients: [RecipieIngredient] = [], steps: [String] = []) {
        self.id = id
        self.name = name
        self.mealType = mealType.rawValue
        self.course = course.rawValue
        self.summary = summary
        self.serves = serves
        self.time = time
        self.ingredients = ingredients
        self.steps = steps
    }
    
    var mealTypeEnum: MealType {
        get { return MealType(rawValue: mealType)! }
        set { mealType = newValue.rawValue }
    }
    
    var courseEnum: CourseType {
        get { return CourseType(rawValue: course)! }
        set { course = newValue.rawValue }
    }
}

extension Recipie {
    static func descriptor(id: UUID) -> FetchDescriptor<Recipie> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }

    private var ingredientDietary: Set<Dietary> {
        ingredients.reduce(into: Set<Dietary>()) { dietary, ingredient in
            dietary.formUnion(ingredient.item.dietary)
        }
    }

    var isVegan: Bool {
        ingredientDietary.isDisjoint(with: [.dairy, .fish, .meat])
    }

    var isVegetarian: Bool {
        ingredientDietary.isDisjoint(with: [.fish, .meat])
    }

    var isPescetarian: Bool {
        !ingredientDietary.contains(.meat)
    }

    var isGlutenFree: Bool {
        !ingredientDietary.contains(.gluten)
    }
    
    var isQuick: Bool {
        time <= 15
    }
}
