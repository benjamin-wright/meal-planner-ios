//
//  RecipieIngredient.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 06/10/2025.
//

import Foundation
import SwiftData

@Model
final class RecipieIngredient {
    @Attribute(.unique)
    var id: UUID = UUID()
    var ingredient: Ingredient
    var unit: Measure
    var quantity: Double
    
    init(id: UUID = UUID(), ingredient: Ingredient, unit: Measure, quantity: Double) {
        self.id = id
        self.ingredient = ingredient
        self.unit = unit
        self.quantity = quantity
    }
}
