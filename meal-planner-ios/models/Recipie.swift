//
//  Recipie.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 04/10/2025.
//

import Foundation
import SwiftData

enum RecipieType: Int, Codable {
    case breakfast
    case lunch
    case dinner
}

struct RecipieDraft {
    var name: String
    var type: RecipieType
    var summary: String
    var serves: Int
    var time: Int
    var ingredients: [RecipieIngredientDraft]
    var steps: [String]

    init(type: RecipieType) {
        self.name = ""
        self.type = type
        self.summary = ""
        self.serves = 2
        self.time = 15
        self.ingredients = []
        self.steps = []
    }

    init(recipie: Recipie) {
        self.name = recipie.name
        self.type = recipie.recipieType
        self.summary = recipie.summary
        self.serves = recipie.serves
        self.time = recipie.time
        self.ingredients = recipie.ingredients.map(RecipieIngredientDraft.init)
        self.steps = recipie.steps
    }

    func isValid(existingNames: [String] = []) -> Bool {
        name.count >= 3 && !existingNames.contains(name)
    }
}

@Model
final class Recipie {
    @Attribute(.unique)
    var id: UUID = UUID()
    var name: String = ""
    var type: Int
    var recipieType: RecipieType {
        RecipieType(rawValue: type) ?? RecipieType.dinner
    }
    var summary: String = ""
    var serves: Int = 2
    var time: Int = 15
    @Relationship(deleteRule: .cascade)
    var ingredients: [RecipieIngredient]
    var steps: [String]
    
    init(id: UUID = UUID(), name: String = "", type: RecipieType, summary: String = "", serves: Int = 2, time: Int = 15, ingredients: [RecipieIngredient] = [], steps: [String] = []) {
        self.id = id
        self.name = name
        self.type = type.rawValue
        self.summary = summary
        self.serves = serves
        self.time = time
        self.ingredients = ingredients
        self.steps = steps
    }
    
    func isValid() -> Bool {
        if self.name.isEmpty {
            return false
        }
        
        if self.name.count < 3 {
            return false
        }
        
        return true
    }
}

extension Recipie {
    static func descriptor(id: UUID) -> FetchDescriptor<Recipie> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }
}
