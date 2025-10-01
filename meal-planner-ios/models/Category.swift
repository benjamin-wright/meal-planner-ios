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
    
    init(id: UUID = UUID(), name: String, order: Int) {
        self.id = id
        self.name = name
        self.order = order
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
    
    func clone() -> Category {
        return Category(
            id: self.id,
            name: self.name,
            order: self.order
        )
    }
}
