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
    @Attribute(.unique)
    var id: UUID
    var unit: CountUnit?
    var singular: String
    var plural: String
    var multiplier: Double
    
    init(id: UUID = UUID(), unit: CountUnit?, singular: String, plural: String, multiplier: Double = 1.0) {
        self.id = id
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
    var collectives: [CountUnitCollective]
    
    init(id: UUID? = UUID(), name: String, collectives: [CountUnitCollective] = []) {
        self.id = id ?? UUID()
        self.name = name
        self.collectives = collectives
    }
    
    func isValid() -> Bool {
        if self.name.isEmpty || self.name.count < 3 {
            return false
        }
        
        for collective in self.collectives {
            if collective.multiplier <= 0 || collective.singular.isEmpty || collective.plural.isEmpty {
                return false
            }
        }
        
        return true
    }
    
    func clone() -> CountUnit {
        CountUnit(
            id: self.id,
            name: self.name,
            collectives: self.collectives.map { c in
                CountUnitCollective(
                    id: c.id,
                    unit: c.unit,
                    singular: c.singular,
                    plural: c.plural,
                    multiplier: c.multiplier
                )
            }
        )
    }
    
    static let sampleData: [CountUnit] = [
        CountUnit(
            name: "count"
        ),
        CountUnit(
            name: "loaves",
            collectives: [
                CountUnitCollective(
                    unit: nil,
                    singular: "slice",
                    plural: "slices",
                    multiplier: 0.1
                ),
                CountUnitCollective(
                    unit: nil,
                    singular: "loaf",
                    plural: "loaves",
                    multiplier: 1
                )
            ]
        )
    ]
}
