//
//  RecipieIngredient.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 06/10/2025.
//

import Foundation
import SwiftData

struct RecipieIngredientDraft: Identifiable, Hashable {
    var id: UUID
    var itemID: UUID
    var unitID: UUID
    var quantity: Double
    var sourceText: String?

    init(id: UUID = UUID(), itemID: UUID, unitID: UUID, quantity: Double, sourceText: String? = nil) {
        self.id = id
        self.itemID = itemID
        self.unitID = unitID
        self.quantity = quantity
        self.sourceText = sourceText
    }

    init(ingredient: RecipieIngredient) {
        self.id = ingredient.id
        self.itemID = ingredient.item.id
        self.unitID = ingredient.unit.id
        self.quantity = ingredient.quantity
        self.sourceText = ingredient.sourceText
    }
}

@Model
final class RecipieIngredient {
    @Attribute(.unique)
    var id: UUID = UUID()
    var item: Item
    var unit: Unit
    var quantity: Double
    var sourceText: String? = nil
    
    init(id: UUID = UUID(), item: Item, unit: Unit, quantity: Double, sourceText: String? = nil) {
        self.id = id
        self.item = item
        self.unit = unit
        self.quantity = quantity
        self.sourceText = sourceText
    }
}
