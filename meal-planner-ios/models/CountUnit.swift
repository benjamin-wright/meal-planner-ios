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

struct CountUnitCollective: Codable, Identifiable {
    var id: UUID
    var singular: String
    var plural: String
    var multiplier: Double
    
    init(singular: String, plural: String, multiplier: Double) {
        self.id = UUID()
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
                    singular: c.singular,
                    plural: c.plural,
                    multiplier: c.multiplier
                )
            }
        )
    }
    
    func update(updated: CountUnit) {
        self.name = updated.name
        self.collectives = updated.collectives
    }
}
