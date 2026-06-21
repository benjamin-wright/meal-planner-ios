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
}

extension Ingredient {
    static func descriptor(id: UUID) -> FetchDescriptor<Ingredient> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }
    
    /// Creates and returns a blank ingredient using the first available
    /// category (sorted by order). Returns nil if no categories exist yet.
    /// Does NOT insert into the context - caller must do that when confirmed.
    static func makeNew(in context: ModelContext) -> Ingredient? {
        guard let defaultCategory = try? context.fetch(Category.orderedDescriptor).first
        else { return nil }
        let ingredient = Ingredient(name: "", category: defaultCategory)
        return ingredient
    }
    
    func isValid() -> Bool {
        !name.isEmpty && name.count >= 3
    }
}
