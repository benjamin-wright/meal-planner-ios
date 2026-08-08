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

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "This item no longer exists."
            case .invalidDraft(let errors):
                return errors.compactMap(\.errorDescription).joined(separator: " ")
            case .missingCategory:
                return "The selected category no longer exists."
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

    func save(_ draft: ItemDraft, id: UUID?) throws {
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
    }

    func delete(ids: [UUID]) throws {
        let selectedIDs = Set(ids)
        let items = try context.fetch(FetchDescriptor<Item>())
        items.filter { selectedIDs.contains($0.id) }.forEach(context.delete)
        try context.save()
    }
}
