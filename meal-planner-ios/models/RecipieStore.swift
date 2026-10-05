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
        case unresolvedImport

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "This recipe no longer exists."
            case .invalidDraft(let errors):
                return errors.compactMap(\.errorDescription).joined(separator: " ")
            case .missingIngredientReference:
                return "An ingredient item or unit no longer exists."
            case .unresolvedImport:
                return "Review each imported ingredient's item, unit and quantity before saving."
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
        if draft.importedIngredients != nil {
            try saveImported(draft, id: id)
            return
        }
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
                ingredient.sourceText = ingredientDraft.sourceText
                return ingredient
            }

            let ingredient = RecipieIngredient(
                id: ingredientDraft.id,
                item: item,
                unit: unit,
                quantity: ingredientDraft.quantity,
                sourceText: ingredientDraft.sourceText
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

    private func saveImported(_ draft: RecipieDraft, id: UUID?) throws {
        let items = try context.fetch(FetchDescriptor<Item>())
        let units = try context.fetch(FetchDescriptor<Unit>())
        var resolved = draft
        resolved.importedIngredients = nil
        resolved.ingredients = []
        for ingredient in draft.importedIngredients ?? [] {
            guard ingredient.isResolved(items: items, units: units),
                  let itemID = ingredient.itemID, let unitID = ingredient.unitID,
                  let quantity = ingredient.quantity(units: units) else {
                throw Error.unresolvedImport
            }
            resolved.ingredients.append(RecipieIngredientDraft(
                id: ingredient.id, itemID: itemID, unitID: unitID, quantity: quantity,
                sourceText: ingredient.sourceText
            ))
        }
        try save(resolved, id: id)
    }

    func delete(id: UUID) throws {
        guard let recipie = try context.fetch(Recipie.descriptor(id: id)).first else {
            throw Error.notFound
        }
        context.delete(recipie)
        try context.save()
    }
}
