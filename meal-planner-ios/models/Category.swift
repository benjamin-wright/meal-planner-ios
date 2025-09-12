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
    var id: UUID
    var name: String
    
    init(id: UUID?, name: String) {
        self.id = id ?? UUID()
        self.name = name
    }
}
