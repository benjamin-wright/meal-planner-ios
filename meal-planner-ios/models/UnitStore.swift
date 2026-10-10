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

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "This unit no longer exists."
            case .invalidDraft(let errors):
                return errors.compactMap(\.errorDescription).joined(separator: " ")
            case .inUse(let name):
                return "\(name) is used by settings, a recipe, a meal, a planner entry, or the shopping list and cannot be deleted."
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
        ids.formUnion(try context.fetch(FetchDescriptor<RecipieIngredient>()).map { $0.unit.id })
        ids.formUnion(try context.fetch(FetchDescriptor<MealComponent>()).compactMap { $0.unit?.id })
        ids.formUnion(try context.fetch(FetchDescriptor<PlannedMiscEntry>()).compactMap { $0.unit?.id })
        ids.formUnion(try context.fetch(FetchDescriptor<ShoppingListEntry>()).compactMap { $0.unit?.id })
        return ids
    }
}
