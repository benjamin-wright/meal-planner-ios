//
//  UnitStore.swift
//  meal-planner-ios
//

import Foundation
import SwiftData

@MainActor
final class UnitStore {
    enum Error: LocalizedError {
        case notFound
        case invalidDraft([UnitDraft.ValidationError])
        case inUse(String)
        case missingPreferredUnit(UnitType)

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "This unit no longer exists."
            case .invalidDraft(let errors):
                return errors.compactMap(\.errorDescription).joined(separator: " ")
            case .inUse(let name):
                return "\(name) is used by settings, a recipe, a meal, a planner entry, or the shopping list and cannot be deleted."
            case .missingPreferredUnit(let type):
                return "Add another valid \(type.label.lowercased()) unit before changing this preferred unit's type."
            }
        }
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func draft(id: UUID) throws -> UnitDraft {
        guard let unit = try context.fetch(Unit.descriptor(id: id)).first else {
            throw Error.notFound
        }
        return UnitDraft(unit: unit)
    }

    @discardableResult
    func save(_ draft: UnitDraft, id: UUID?) throws -> UUID {
        var draft = draft
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.magnitudes = draft.magnitudes.map { magnitude in
            var magnitude = magnitude
            magnitude.abbreviation = magnitude.abbreviation.trimmingCharacters(in: .whitespacesAndNewlines)
            magnitude.singular = magnitude.singular.trimmingCharacters(in: .whitespacesAndNewlines)
            magnitude.plural = magnitude.plural.trimmingCharacters(in: .whitespacesAndNewlines)
            return magnitude
        }
        let validationErrors = draft.validate()
        guard validationErrors.isEmpty else {
            throw Error.invalidDraft(validationErrors)
        }

        // Plan settings repairs before changing either the unit or its dependants.
        let preferenceReplacements = try preferredUnitReplacements(for: id, newType: draft.type)
        let unit: Unit
        if let id {
            guard let existing = try context.fetch(Unit.descriptor(id: id)).first else {
                throw Error.notFound
            }
            unit = existing
        } else {
            unit = Unit(name: draft.name, type: draft.type, base: draft.base, magnitudes: draft.magnitudes)
            context.insert(unit)
        }
        unit.name = draft.name
        unit.type = draft.type.rawValue
        unit.base = draft.type == .count ? 1 : draft.base
        unit.magnitudes = draft.magnitudes
        for replacement in preferenceReplacements {
            switch replacement.type {
            case .weight: replacement.settings.preferredWeight = replacement.unit
            case .volume: replacement.settings.preferredVolume = replacement.unit
            case .count: break
            }
        }
        try context.save()
        return unit.id
    }

    func delete(ids: [UUID]) throws {
        let selectedIDs = Set(ids)
        let units = try context.fetch(FetchDescriptor<Unit>())
        let referencedIDs = try referencedUnitIDs()

        if let unit = units.first(where: { unit in
            selectedIDs.contains(unit.id) && referencedIDs.contains(unit.id)
        }) {
            throw Error.inUse(unit.name)
        }

        units.filter { selectedIDs.contains($0.id) }.forEach(context.delete)
        try context.save()
    }

    /// Required references prevent deletion while allowing corrections to unit conversion.
    private func referencedUnitIDs() throws -> Set<UUID> {
        var ids = Set<UUID>()
        for settings in try context.fetch(FetchDescriptor<AppSettings>()) {
            ids.insert(settings.preferredWeight.id)
            ids.insert(settings.preferredVolume.id)
        }
        ids.formUnion(try IngredientDependencies(context: context).unitIDs)
        ids.formUnion(try context.fetch(FetchDescriptor<PlannedMiscEntry>()).compactMap { $0.unit?.id })
        ids.formUnion(try context.fetch(FetchDescriptor<ShoppingListEntry>()).compactMap { $0.unit?.id })
        return ids
    }

    private struct PreferredUnitReplacement {
        let settings: AppSettings
        let type: UnitType
        let unit: Unit
    }

    private func preferredUnitReplacements(for id: UUID?, newType: UnitType) throws -> [PreferredUnitReplacement] {
        guard let id else { return [] }
        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        let affected = settings.flatMap { setting in
            [(UnitType.weight, setting.preferredWeight), (.volume, setting.preferredVolume)]
                .filter { $0.1.id == id && $0.0 != newType }
                .map { (setting, $0.0) }
        }
        guard !affected.isEmpty else { return [] }
        let units = try context.fetch(FetchDescriptor<Unit>()).filter {
            $0.id != id && $0.definition?.isValid == true
        }.sorted {
            $0.name == $1.name ? $0.id.uuidString < $1.id.uuidString : $0.name < $1.name
        }
        return try affected.map { setting, type in
            guard let replacement = units.first(where: { $0.definition?.type == type }) else {
                throw Error.missingPreferredUnit(type)
            }
            return PreferredUnitReplacement(settings: setting, type: type, unit: replacement)
        }
    }
}
