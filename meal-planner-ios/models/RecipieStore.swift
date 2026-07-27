//
//  RecipieStore.swift
//  meal-planner-ios
//

import Foundation
import SwiftData

@MainActor
final class RecipieStore {
    enum Error: LocalizedError {
        case notFound
        case invalidDraft([RecipieDraft.ValidationError])
        case missingIngredientReference

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "This recipe no longer exists."
            case .invalidDraft(let errors):
                return errors.compactMap(\.errorDescription).joined(separator: " ")
            case .missingIngredientReference:
                return "An ingredient item or unit no longer exists."
            }
        }
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func draft(id: UUID) throws -> RecipieDraft {
        guard let recipie = try context.fetch(Recipie.descriptor(id: id)).first else {
            throw Error.notFound
        }
        return RecipieDraft(recipie: recipie)
    }

    func save(_ draft: RecipieDraft, id: UUID?) throws {
        let existingNames = try context.fetch(FetchDescriptor<Recipie>())
            .filter { $0.id != id }
            .map(\.name)
        let validationErrors = draft.validate(existingNames: existingNames)
        guard validationErrors.isEmpty else {
            throw Error.invalidDraft(validationErrors)
        }

        let itemsByID = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Item>()).map { ($0.id, $0) })
        let unitsByID = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Unit>()).map { ($0.id, $0) })
        let resolvedIngredients = try draft.ingredients.map { ingredientDraft in
            guard let item = itemsByID[ingredientDraft.itemID],
                  let unit = unitsByID[ingredientDraft.unitID] else {
                throw Error.missingIngredientReference
            }
            return (ingredientDraft, item, unit)
        }

        let recipie: Recipie
        if let id {
            guard let existing = try context.fetch(Recipie.descriptor(id: id)).first else {
                throw Error.notFound
            }
            recipie = existing
        } else {
            recipie = Recipie()
            context.insert(recipie)
        }

        let oldIngredientsByID = Dictionary(uniqueKeysWithValues: recipie.ingredients.map { ($0.id, $0) })

        let ingredients = resolvedIngredients.map { ingredientDraft, item, unit in
            if let ingredient = oldIngredientsByID[ingredientDraft.id] {
                ingredient.item = item
                ingredient.unit = unit
                ingredient.quantity = ingredientDraft.quantity
                return ingredient
            }

            let ingredient = RecipieIngredient(
                id: ingredientDraft.id,
                item: item,
                unit: unit,
                quantity: ingredientDraft.quantity
            )
            context.insert(ingredient)
            return ingredient
        }

        recipie.name = draft.name
        recipie.mealTypeEnum = draft.mealType
        recipie.courseEnum = draft.course
        recipie.summary = draft.summary
        recipie.serves = draft.serves
        recipie.time = draft.time
        recipie.steps = draft.steps
        recipie.ingredients = ingredients

        let retainedIDs = Set(draft.ingredients.map(\.id))
        oldIngredientsByID.values
            .filter { !retainedIDs.contains($0.id) }
            .forEach(context.delete)

        try context.save()
    }

    func delete(id: UUID) throws {
        guard let recipie = try context.fetch(Recipie.descriptor(id: id)).first else {
            throw Error.notFound
        }
        context.delete(recipie)
        try context.save()
    }
}
