//
//  Unit.swift
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

struct Magnitude: Codable, Identifiable, Hashable {
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

struct UnitDraft {
    var name: String
    var type: UnitType
    var base: Double
    var magnitudes: [Magnitude]

    init(type: UnitType) {
        self.name = ""
        self.type = type
        self.base = 1
        self.magnitudes = []
    }

    init(unit: Unit) {
        self.name = unit.name
        self.type = unit.unitType
        self.base = unit.base
        self.magnitudes = unit.magnitudes
    }

    func isValid() -> Bool {
        guard name.count >= 3, base > 0, !magnitudes.isEmpty else {
            return false
        }

        return magnitudes.allSatisfy {
            $0.multiplier > 0 && !$0.singular.isEmpty && !$0.plural.isEmpty
        }
    }
}

@Model
final class Unit {
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
    
    func toString(forValue value: Double) -> String {
        let magnitude = self.selectMagnitude(forValue: value)
        
        return magnitude?.toString(forValue: value) ?? String(format: "%g", value)
    }
    
    func selectMagnitude(forValue value: Double) -> Magnitude? {
        if magnitudes.count < 1 {
            return nil
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
        
        return bestMagnitude
    }
}

extension Unit {
    static func descriptor(id: UUID) -> FetchDescriptor<Unit> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }
}
