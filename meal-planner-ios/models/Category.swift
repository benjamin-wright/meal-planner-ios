//
//  Category.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 09/09/2025.
//

import Foundation
import SwiftData

@Model
final class Category: Identifiable {
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

extension Category {
    static var orderedDescriptor: FetchDescriptor<Category> {
        FetchDescriptor(sortBy: [SortDescriptor(\.order)])
    }

    static func descriptor(id: UUID) -> FetchDescriptor<Category> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }

    /// Creates and returns a blank category with the next available order index.
    /// Does NOT insert into the context — caller must do that when confirmed.
    static func makeNew(in context: ModelContext) -> Category {
        let existing = (try? context.fetch(Category.orderedDescriptor)) ?? []
        return Category(name: "", order: existing.count)
    }
}
