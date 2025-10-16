//
//  Ingredient.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 01/10/2025.
//

import Foundation
import SwiftData

@Model
final class Ingredient {
    @Attribute(.unique)
    var id: UUID
    var name: String
    var category: Category
    
    init(id: UUID = UUID(), name: String = "", category: Category) {
        self.id = id
        self.name = name
        self.category = category
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
