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
    var item: Item
    var unit: Unit
    var quantity: Double
    
    init(id: UUID = UUID(), item: Item, unit: Unit, quantity: Double) {
        self.id = id
        self.item = item
        self.unit = unit
        self.quantity = quantity
    }
}
