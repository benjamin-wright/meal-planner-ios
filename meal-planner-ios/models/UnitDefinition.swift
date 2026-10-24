import Foundation

/// Unit calculation and formatting rules, usable without a SwiftData model.
struct UnitDefinition: Identifiable, Hashable {
    var id: UUID
    var name: String
    var type: UnitType
    var base: Double
    var magnitudes: [Magnitude]
    var isBaseUnit: Bool = false

    static func baseUnit(for type: UnitType) -> UnitDefinition {
        switch type {
        case .count:
            return .init(id: UUID(), name: "count", type: type, base: 1, magnitudes: [], isBaseUnit: true)
        case .weight:
            return .init(id: UUID(), name: "grams", type: type, base: 1, magnitudes: [
                Magnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1),
                Magnitude(abbreviation: "kg", singular: "kilogram", plural: "kilograms", multiplier: 1000),
            ], isBaseUnit: true)
        case .volume:
            return .init(id: UUID(), name: "litres", type: type, base: 1, magnitudes: [
                Magnitude(abbreviation: "ml", singular: "millilitre", plural: "millilitres", multiplier: 0.001),
                Magnitude(abbreviation: "l", singular: "litre", plural: "litres", multiplier: 1),
            ], isBaseUnit: true)
        }
    }

    /// Ignore generated identifiers when recognizing the original seeded definitions.
    func matchesBaseUnit(_ other: UnitDefinition) -> Bool {
        name == other.name && type == other.type && base == other.base
            && magnitudes.count == other.magnitudes.count
            && zip(magnitudes, other.magnitudes).allSatisfy { lhs, rhs in
                lhs.abbreviation == rhs.abbreviation && lhs.singular == rhs.singular
                    && lhs.plural == rhs.plural && lhs.multiplier == rhs.multiplier
            }
    }

    var isValid: Bool {
        DomainValidation.isPositiveFinite(base)
            && magnitudes.allSatisfy { DomainValidation.isPositiveFinite($0.multiplier) }
    }

    func convert(_ value: Double, to destination: UnitDefinition) -> Double? {
        guard type == destination.type, type != .count,
              isValid, destination.isValid, value.isFinite else { return nil }
        let converted = value * base / destination.base
        return converted.isFinite ? converted : nil
    }

    func toString(forValue value: Double) -> String {
        selectMagnitude(forValue: value)?.toString(forValue: value) ?? String(format: "%g", value)
    }

    func selectMagnitude(forValue value: Double) -> Magnitude? {
        let validMagnitudes = magnitudes.filter { DomainValidation.isPositiveFinite($0.multiplier) }
        guard var best = validMagnitudes.first else { return nil }
        var closest = Double.greatestFiniteMagnitude
        for magnitude in validMagnitudes {
            let adjusted = value / magnitude.multiplier
            if adjusted >= 1 && adjusted < closest {
                best = magnitude
                closest = adjusted
            }
        }
        return best
    }

    static func defaultForNewObject(in units: [UnitDefinition]) -> UnitDefinition? {
        units.first { $0.isBaseUnit && $0.type == .count && $0.isValid }
    }
}
