//
//  WeightUnit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 28/09/2025.
//

import Foundation
import SwiftData

struct ContinuousUnitMagnitude: Codable, Identifiable {
    var id: UUID
    var abbreviation: String
    var singular: String
    var plural: String
    var multiplier: Double
    
    init(abbreviation: String, singular: String, plural: String, multiplier: Double) {
        self.id = UUID()
        self.abbreviation = abbreviation
        self.singular = singular
        self.plural = plural
        self.multiplier = multiplier
    }
}

enum ContinuousUnitType: Int, Codable {
    case weight
    case volume
}

@Model
final class ContinuousUnit {
    @Attribute(.unique)
    var id: UUID
    var name: String
    var type: Int
    var base: Double
    var magnitudes: [ContinuousUnitMagnitude]
    
    init(id: UUID? = UUID(), name: String, type: ContinuousUnitType, base: Double, magnitudes: [ContinuousUnitMagnitude]) {
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
        
        for magnitude in self.magnitudes {
            if magnitude.multiplier <= 0 || magnitude.singular.isEmpty || magnitude.plural.isEmpty {
                return false
            }
        }
        
        return true
    }
    
    func clone() -> ContinuousUnit {
        ContinuousUnit(
            id: self.id,
            name: self.name,
            type: ContinuousUnitType(rawValue: self.type) ?? .weight,
            base: self.base,
            magnitudes: self.magnitudes.map { c in
                ContinuousUnitMagnitude(
                    abbreviation: c.abbreviation,
                    singular: c.singular,
                    plural: c.plural,
                    multiplier: c.multiplier
                )
            }
        )
    }
    
    func update(updated: ContinuousUnit) {
        self.name = updated.name
        self.type = updated.type
        self.base = updated.base
        self.magnitudes = updated.magnitudes
    }
    
    static let sampleData: [ContinuousUnit] = [
        ContinuousUnit(
            name: "grams",
            type: .weight,
            base: 1,
            magnitudes: [
                ContinuousUnitMagnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1),
                ContinuousUnitMagnitude(abbreviation: "kg", singular: "kilogram", plural: "kilograms", multiplier: 1000),
            ]
        ),
        ContinuousUnit(
            name: "litre",
            type: .volume,
            base: 1,
            magnitudes: []
        ),
    ]
}
