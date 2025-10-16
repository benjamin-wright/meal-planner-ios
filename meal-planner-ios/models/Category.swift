//
//  Category.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 09/09/2025.
//

import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique)
    var id: UUID
    var name: String
    var order: Int
    @Relationship(deleteRule: .cascade, inverse: \Ingredient.category)
    var ingredients: [Ingredient]
    
    init(id: UUID = UUID(), name: String, order: Int, ingredients: [Ingredient] = []) {
        self.id = id
        self.name = name
        self.order = order
        self.ingredients = ingredients
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
