//
//  Category.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 09/09/2025.
//

import Foundation
import SwiftData

struct CategoryDraft {
    enum ValidationError: Hashable, LocalizedError {
        case nameTooShort
        case duplicateName

        var errorDescription: String? {
            switch self {
            case .nameTooShort:
                return "Category names must be at least 3 characters."
            case .duplicateName:
                return "A category with this name already exists."
            }
        }
    }

    var name: String
    var order: Int

    init(order: Int = 0) {
        self.name = ""
        self.order = order
    }

    init(category: Category) {
        self.name = category.name
        self.order = category.order
    }

    func validate(existingNames: [String] = []) -> [ValidationError] {
        var errors: [ValidationError] = []
        if name.count < 3 {
            errors.append(.nameTooShort)
        }
        if existingNames.contains(name) {
            errors.append(.duplicateName)
        }
        return errors
    }

}

@Model
final class Category: Identifiable {
    @Attribute(.unique)
    var id: UUID
    var name: String
    var order: Int
    @Relationship(deleteRule: .cascade, inverse: \Item.category)
    var items: [Item]
    
    init(id: UUID = UUID(), name: String, order: Int, items: [Item] = []) {
        self.id = id
        self.name = name
        self.order = order
        self.items = items
    }
    
}

extension Category {
    static var orderedDescriptor: FetchDescriptor<Category> {
        FetchDescriptor(sortBy: [SortDescriptor(\.order)])
    }

    static func descriptor(id: UUID) -> FetchDescriptor<Category> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }

    /// Creates and returns a blank category with the next available order index.
    /// Does NOT insert into the context — caller must do that when confirmed.
    static func makeNew(in context: ModelContext) -> Category {
        let existing = (try? context.fetch(Category.orderedDescriptor)) ?? []
        return Category(name: "", order: existing.count)
    }
}
