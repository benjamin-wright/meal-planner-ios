//
//  Unit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 28/09/2025.
//

import Foundation
import SwiftData

enum UnitType: Int, Codable, LabeledEnum {
    var id: Self { self }
    
    case count
    case weight
    case volume
    
    var label: String {
        switch self {
        case .count:
            return "Count"
        case .weight:
            return "Weight"
        case .volume:
            return "Volume"
        }
    }
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
    enum ValidationError: Hashable, LocalizedError {
        case nameTooShort
        case nonPositiveBase
        case missingMagnitudes
        case invalidMagnitude

        var errorDescription: String? {
            switch self {
            case .nameTooShort:
                return "Unit names must be at least 3 characters."
            case .nonPositiveBase:
                return "The base value must be greater than zero."
            case .missingMagnitudes:
                return "Add at least one magnitude."
            case .invalidMagnitude:
                return "Each magnitude needs singular and plural names and a positive multiplier."
            }
        }
    }

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

    func validate() -> [ValidationError] {
        var errors: [ValidationError] = []
        if name.count < 3 {
            errors.append(.nameTooShort)
        }
        if base <= 0 {
            errors.append(.nonPositiveBase)
        }
        if magnitudes.isEmpty && type != .count {
            errors.append(.missingMagnitudes)
        } else if !magnitudes.allSatisfy({ $0.multiplier > 0 && !$0.singular.isEmpty && !$0.plural.isEmpty }) {
            errors.append(.invalidMagnitude)
        }
        return errors
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

    func convert(_ value: Double, to destination: Unit) -> Double? {
        guard unitType == destination.unitType,
              unitType != .count,
              base > 0,
              destination.base > 0,
              value.isFinite else { return nil }
        return value * base / destination.base
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
