//
//  ItemStore.swift
//  meal-planner-ios
//

import Foundation
import SwiftData

@MainActor
final class ItemStore {
    enum Error: LocalizedError {
        case notFound
        case invalidDraft([ItemDraft.ValidationError])
        case missingCategory
        case itemInUse
        case usedInRecipe(String)
        case usedInSubstitution(String)

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "This item no longer exists."
            case .invalidDraft(let errors):
                return errors.compactMap(\.errorDescription).joined(separator: " ")
            case .missingCategory:
                return "The selected category no longer exists."
            case .itemInUse:
                return "This item is used in a meal. Remove it from its meals before changing its kind."
            case .usedInRecipe(let name):
                return "\"\(name)\" is used in a recipe. Remove it from its recipes before deleting it."
            case .usedInSubstitution(let name):
                return "\"\(name)\" is used in a recipe substitution. Remove the substitution before deleting it."
            }
        }
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func newDraft() throws -> ItemDraft {
        guard let categoryID = try context.fetch(Category.orderedDescriptor).first?.id else {
            throw Error.missingCategory
        }
        return ItemDraft(categoryID: categoryID)
    }

    func draft(id: UUID) throws -> ItemDraft {
        guard let item = try context.fetch(Item.descriptor(id: id)).first else {
            throw Error.notFound
        }
        return ItemDraft(item: item)
    }

    @discardableResult
    func save(_ draft: ItemDraft, id: UUID?) throws -> UUID {
        var draft = draft
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingNames = try context.fetch(FetchDescriptor<Item>())
            .filter { $0.id != id }
            .map(\.name)
        let validationErrors = draft.validate(existingNames: existingNames)
        guard validationErrors.isEmpty else {
            throw Error.invalidDraft(validationErrors)
        }
        guard let category = try context.fetch(Category.descriptor(id: draft.categoryID)).first else {
            throw Error.missingCategory
        }

        let item: Item
        if let id {
            guard let existing = try context.fetch(Item.descriptor(id: id)).first else {
                throw Error.notFound
            }
            let usedInSubstitution = try context.fetch(FetchDescriptor<MealComponent>())
                .contains { $0.ingredientOverrides?.contains { $0.itemID == id } == true }
            if draft.kind.rawValue != existing.kind && (!existing.mealComponents.isEmpty || usedInSubstitution) {
                throw Error.itemInUse
            }
            item = existing
        } else {
            item = Item(name: draft.name, category: category, kind: draft.kind)
            context.insert(item)
        }
        item.name = draft.name
        item.category = category
        item.kind = draft.kind.rawValue
        item.dietary = draft.dietary.toSet()
        item.readymealData = draft.kind == .readymeal ? draft.readymealData : nil
        try context.save()
        return item.id
    }

    func delete(ids: [UUID]) throws {
        let selectedIDs = Set(ids)
        let items = try context.fetch(FetchDescriptor<Item>())
        let itemsToDelete = items.filter { selectedIDs.contains($0.id) }
        let referencedItemIDs = Set(try context.fetch(FetchDescriptor<RecipieIngredient>()).map { $0.item.id })
        if let referencedItem = itemsToDelete.first(where: { referencedItemIDs.contains($0.id) }) {
            throw Error.usedInRecipe(referencedItem.name)
        }
        let substitutionItemIDs = Set(try context.fetch(FetchDescriptor<MealComponent>())
            .flatMap { ($0.ingredientOverrides ?? []).map(\.itemID) })
        if let item = itemsToDelete.first(where: { substitutionItemIDs.contains($0.id) }) {
            throw Error.usedInSubstitution(item.name)
        }
        itemsToDelete.forEach(context.delete)
        try context.save()
    }
}
