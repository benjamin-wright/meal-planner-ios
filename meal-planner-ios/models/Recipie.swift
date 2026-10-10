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
    var summary: String
    var serves: Int
    var time: Int
    var ingredients: [RecipieIngredientDraft]
    var importedIngredients: [ImportedRecipieIngredient]? = nil
    var steps: [String]

    init() {
        self.name = ""
        self.summary = ""
        self.serves = 2
        self.time = 15
        self.ingredients = []
        self.steps = []
    }

    init(recipie: Recipie) {
        self.name = recipie.name
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
    var summary: String = ""
    var serves: Int = 2
    var time: Int = 15
    @Relationship(deleteRule: .cascade)
    var ingredients: [RecipieIngredient]
    @Relationship(deleteRule: .cascade, inverse: \MealComponent.recipe)
    var mealComponents: [MealComponent] = []
    var steps: [String]
    
    init(id: UUID = UUID(), name: String = "", summary: String = "", serves: Int = 2, time: Int = 15, ingredients: [RecipieIngredient] = [], steps: [String] = []) {
        self.id = id
        self.name = name
        self.summary = summary
        self.serves = serves
        self.time = time
        self.ingredients = ingredients
        self.steps = steps
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

struct RecipieFilter {
    var search: String = ""
    var quick = false
    var vegan = false
    var vegetarian = false
    var pescetarian = false
    var glutenFree = false

    var hasActiveFilters: Bool {
        quick || vegan || vegetarian || pescetarian || glutenFree
    }

    mutating func clearFilters() {
        quick = false
        vegan = false
        vegetarian = false
        pescetarian = false
        glutenFree = false
    }

    func filter(recipie: Recipie) -> Bool {
        (search.isEmpty || recipie.name.localizedCaseInsensitiveContains(search))
            && (!quick || recipie.isQuick)
            && (!vegan || recipie.isVegan)
            && (!vegetarian || recipie.isVegetarian)
            && (!pescetarian || recipie.isPescetarian)
            && (!glutenFree || recipie.isGlutenFree)
    }
}
