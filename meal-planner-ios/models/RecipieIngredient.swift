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
    var countUnit: CountUnit?
    var continuousUnit: ContinuousUnit?
    var quantity: Double
    
    init(id: UUID = UUID(), ingredient: Ingredient, countUnit: CountUnit? = nil, continuousUnit: ContinuousUnit? = nil, quantity: Double) {
        self.id = id
        self.ingredient = ingredient
        self.countUnit = countUnit
        self.continuousUnit = continuousUnit
        self.quantity = quantity
    }
}
