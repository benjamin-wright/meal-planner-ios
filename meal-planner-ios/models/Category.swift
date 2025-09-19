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
    var name: String
    var order: Int
    
    init(name: String, order: Int) {
        self.name = name
        self.order = order
    }
    
    static let sampleData = [
        Category(name: "bakery", order: 3),
        Category(name: "fruit", order: 1),
        Category(name: "vegetables", order: 2)
    ]
}
