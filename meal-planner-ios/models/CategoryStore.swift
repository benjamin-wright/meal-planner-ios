//
//  CategoryStore.swift
//  meal-planner-ios
//

import Foundation
import SwiftData

@MainActor
final class CategoryStore {
    enum Error: LocalizedError {
        case notFound
        case invalidDraft([CategoryDraft.ValidationError])
        case itemUsedInRecipe(category: String, item: String)

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "This category no longer exists."
            case .invalidDraft(let errors):
                return errors.compactMap(\.errorDescription).joined(separator: " ")
            case .itemUsedInRecipe(let category, let item):
                return "\"\(category)\" contains \"\(item)\", which is used in a recipe. Remove it from its recipes before deleting this category."
            }
        }
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func newDraft() throws -> CategoryDraft {
        CategoryDraft(order: try context.fetch(Category.orderedDescriptor).count)
    }

    func draft(id: UUID) throws -> CategoryDraft {
        guard let category = try context.fetch(Category.descriptor(id: id)).first else {
            throw Error.notFound
        }
        return CategoryDraft(category: category)
    }

    @discardableResult
    func save(_ draft: CategoryDraft, id: UUID?) throws -> UUID {
        var draft = draft
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingNames = try context.fetch(FetchDescriptor<Category>())
            .filter { $0.id != id }
            .map(\.name)
        let validationErrors = draft.validate(existingNames: existingNames)
        guard validationErrors.isEmpty else {
            throw Error.invalidDraft(validationErrors)
        }

        let category: Category
        if let id {
            guard let existing = try context.fetch(Category.descriptor(id: id)).first else {
                throw Error.notFound
            }
            category = existing
        } else {
            category = Category(name: draft.name, order: draft.order)
            context.insert(category)
        }
        category.name = draft.name
        category.order = draft.order
        try context.save()
        return category.id
    }

    func delete(ids: [UUID]) throws {
        let selectedIDs = Set(ids)
        let categories = try context.fetch(Category.orderedDescriptor)
        let ingredients = try context.fetch(FetchDescriptor<RecipieIngredient>())
        if let ingredient = ingredients.first(where: { selectedIDs.contains($0.item.category.id) }) {
            throw Error.itemUsedInRecipe(category: ingredient.item.category.name, item: ingredient.item.name)
        }
        categories.filter { selectedIDs.contains($0.id) }.forEach(context.delete)

        for (index, category) in categories.filter({ !selectedIDs.contains($0.id) }).enumerated() {
            category.order = index
        }
        try context.save()
    }

    func move(fromOffsets: IndexSet, toOffset: Int) throws {
        var categories = try context.fetch(Category.orderedDescriptor)
        categories.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (index, category) in categories.enumerated() {
            category.order = index
        }
        try context.save()
    }
}
