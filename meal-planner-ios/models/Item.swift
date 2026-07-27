//
//  Item.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 01/10/2025.
//

import Foundation
import SwiftData

enum ItemKind: Int, Codable, CaseIterable, LabeledEnum {
    var id: Self { self }
    
    case ingredient
    case readymeal
    case misc
    
    var label: String {
        switch self {
        case .ingredient:
            return "Ingredient"
        case .readymeal:
            return "Ready Meal"
        case .misc:
            return "Misc"
        }
    }
}

struct ReadymealData: Codable {
    var mealType: Int
    var course: Int
    var serves: Int
    var time: Int
    
    init(mealType: Int = 0, course: Int = 0, serves: Int = 1, time: Int = 0) {
        self.mealType = mealType
        self.course = course
        self.serves = serves
        self.time = time
    }
    
    var mealTypeEnum: MealType {
        get { MealType(rawValue: mealType)! }
        set { mealType = newValue.rawValue }
    }
    
    var courseEnum: CourseType {
        get { CourseType(rawValue: course)! }
        set { course = newValue.rawValue }
    }

    static var `default`: ReadymealData {
        ReadymealData(mealType: MealType.dinner.rawValue, course: CourseType.main.rawValue, serves: 1, time: 30)
    }
}

struct ItemDraft {
    enum ValidationError: Hashable, LocalizedError {
        case nameTooShort
        case missingCategory
        case duplicateName

        var errorDescription: String? {
            switch self {
            case .nameTooShort:
                return "Item names must be at least 3 characters."
            case .missingCategory:
                return "Please choose a category."
            case .duplicateName:
                return "An item with this name already exists."
            }
        }
    }

    var name: String
    var categoryID: UUID?
    var kind: ItemKind
    var readymealData: ReadymealData

    init(categoryID: UUID? = nil, kind: ItemKind = .ingredient, readymealData: ReadymealData = .default) {
        self.name = ""
        self.categoryID = categoryID
        self.kind = kind
        self.readymealData = readymealData
    }

    init(item: Item) {
        self.name = item.name
        self.categoryID = item.category.id
        self.kind = item.itemKind
        self.readymealData = item.readymealData ?? .default
    }

    func validate(existingNames: [String] = []) -> [ValidationError] {
        var errors: [ValidationError] = []
        if name.count < 3 {
            errors.append(.nameTooShort)
        }
        if categoryID == nil {
            errors.append(.missingCategory)
        }
        if existingNames.contains(name) {
            errors.append(.duplicateName)
        }
        return errors
    }

}

@Model
final class Item {
    @Attribute(.unique)
    var id: UUID
    var name: String
    var category: Category
    var kind: Int
    var readymealData: Optional<ReadymealData>
    
    var itemKind: ItemKind {
        ItemKind(rawValue: kind) ?? ItemKind.ingredient
    }
    
    init(id: UUID = UUID(), name: String = "", category: Category, kind: ItemKind, readymealData: ReadymealData? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.kind = kind.rawValue
        self.readymealData = readymealData
    }
}

extension Item {
    static func descriptor(id: UUID) -> FetchDescriptor<Item> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }

    static func makeNew(in context: ModelContext) -> Item? {
        guard let defaultCategory = try? context.fetch(Category.orderedDescriptor).first
        else { return nil }
        let item = Item(name: "", category: defaultCategory, kind: .ingredient)
        return item
    }
    
}
