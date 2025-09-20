//
//  Unit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 20/09/2025.
//

//
//  Category.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 09/09/2025.
//

import Foundation
import SwiftData

@Model
final class CountUnitCollective {
    @Relationship(inverse: \CountUnit.id)
    var unit: CountUnit?
    var singular: String
    var plural: String
    var multiplier: Double
    
    init(unit: CountUnit, singular: String, plural: String, multiplier: Double = 1.0) {
        self.unit = unit
        self.singular = singular
        self.plural = plural
        self.multiplier = multiplier
    }
}

@Model
final class CountUnit {
    @Attribute(.unique)
    var id: UUID
    var name: String
    
    @Relationship(deleteRule: .cascade, inverse: \CountUnitCollective.unit)
    var collectives: [CountUnitCollective]?
    
    init(id: UUID = UUID(), name: String, collectives: [CountUnitCollective]? = nil) {
        self.id = id
        self.name = name
        self.collectives = collectives
    }
    
    static let sampleData: [CountUnit] = [
        CountUnit(
            name: "count"
        )
    ]
}
