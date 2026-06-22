//
//  Item.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 01/10/2025.
//

import Foundation
import SwiftData

enum ItemKind: Int, Codable {
    case ingredient
    case readymeal
    case misc
}

@Model
final class Item {
    @Attribute(.unique)
    var id: UUID
    var name: String
    var category: Category
    var kind: Int
    var itemKind: ItemKind {
        ItemKind(rawValue: kind) ?? ItemKind.ingredient
    }
    
    init(id: UUID = UUID(), name: String = "", category: Category, kind: ItemKind) {
        self.id = id
        self.name = name
        self.category = category
        self.kind = kind.rawValue
    }
}

extension Item {
    static func descriptor(id: UUID) -> FetchDescriptor<Item> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }
    
    /// Creates and returns a blank item using the first available
    /// category (sorted by order). Returns nil if no categories exist yet.
    /// Does NOT insert into the context - caller must do that when confirmed.
    static func makeNew(in context: ModelContext) -> Item? {
        guard let defaultCategory = try? context.fetch(Category.orderedDescriptor).first
        else { return nil }
        let item = Item(name: "", category: defaultCategory, kind: .ingredient)
        return item
    }
    
    func isValid() -> Bool {
        !name.isEmpty && name.count >= 3
    }
}
