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
                return "\(name) is used by settings or a recipe and cannot be deleted."
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

    func save(_ draft: UnitDraft, id: UUID?) throws {
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
        unit.base = draft.base
        unit.magnitudes = draft.magnitudes
        try context.save()
    }

    func delete(ids: [UUID]) throws {
        let selectedIDs = Set(ids)
        let units = try context.fetch(FetchDescriptor<Unit>())
        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        let recipies = try context.fetch(FetchDescriptor<Recipie>())

        if let unit = units.first(where: { unit in
            selectedIDs.contains(unit.id) && (
                settings.contains { $0.preferredWeight.id == unit.id || $0.preferredVolume.id == unit.id }
                    || recipies.contains { $0.ingredients.contains { $0.unit.id == unit.id } }
            )
        }) {
            throw Error.inUse(unit.name)
        }

        units.filter { selectedIDs.contains($0.id) }.forEach(context.delete)
        try context.save()
    }
}
