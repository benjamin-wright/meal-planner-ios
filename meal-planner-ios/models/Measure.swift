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
    
    func toString(forValue value: Double) -> String {
        if singular == "" || plural == "" {
            return String(format: "%g", value)
        }
        
        let adjusted = value / self.multiplier
        let formatted = String(format: "%g", adjusted)
            
        if self.abbreviation != "" {
            return "\(formatted)\(self.abbreviation)"
        } else if adjusted.isNaN || adjusted.isInfinite || adjusted == 1 {
            return "\(formatted) \(self.singular)"
        } else {
            return "\(formatted) \(self.plural)"
        }
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
    
    func toString(forValue value: Double) -> String {
        if magnitudes.count < 1 {
            return String(format: "%g", value)
        }
        
        var closestAdjusted = Double.greatestFiniteMagnitude
        var bestMagnitude = self.magnitudes[0]
        for magnitude in self.magnitudes {
            let adjusted = value / magnitude.multiplier
            if adjusted >= 1 && adjusted < closestAdjusted {
                bestMagnitude = magnitude
                closestAdjusted = adjusted
            }
        }

        return bestMagnitude.toString(forValue: value)
    }
}
