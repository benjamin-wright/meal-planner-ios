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
