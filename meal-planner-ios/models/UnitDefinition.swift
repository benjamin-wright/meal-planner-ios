import Foundation

/// Unit calculation and formatting rules, usable without a SwiftData model.
struct UnitDefinition: Identifiable, Hashable {
    var id: UUID
    var name: String
    var type: UnitType
    var base: Double
    var magnitudes: [Magnitude]

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
        let valid = units.filter(\.isValid)
        let count = valid.filter { $0.type == .count }
        return count.first {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare("count") == .orderedSame
        } ?? count.first { $0.magnitudes.isEmpty } ?? count.first ?? valid.first
    }
}
