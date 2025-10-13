//
//  WeightUnit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 28/09/2025.
//

import Foundation
import SwiftData

enum UnitType: Int, Codable {
    case count
    case weight
    case volume
}

struct Magnitude: Codable, Identifiable {
    var id: UUID
    var abbreviation: String
    var singular: String
    var plural: String
    var multiplier: Double
    
    init(abbreviation: String = "", singular: String, plural: String, multiplier: Double) {
        self.id = UUID()
        self.abbreviation = abbreviation
        self.singular = singular
        self.plural = plural
        self.multiplier = multiplier
    }
}

@Model
final class Measure {
    @Attribute(.unique)
    var id: UUID
    var name: String
    var type: Int
    var unitType: UnitType {
        UnitType(rawValue: type) ?? UnitType.weight
    }
    var base: Double
    var magnitudes: [Magnitude]
    
    init(id: UUID? = UUID(), name: String, type: UnitType, base: Double = 1, magnitudes: [Magnitude]) {
        self.id = id ?? UUID()
        self.name = name
        self.type = type.rawValue
        self.base = base
        self.magnitudes = magnitudes
    }
    
    func isValid() -> Bool {
        if self.name.isEmpty || self.name.count < 3 {
            return false
        }
        
        if self.magnitudes.count < 1 {
            return false
        }
        
        for magnitude in self.magnitudes {
            if magnitude.multiplier <= 0 || magnitude.singular.isEmpty || magnitude.plural.isEmpty {
                return false
            }
        }
        
        return true
    }
}
