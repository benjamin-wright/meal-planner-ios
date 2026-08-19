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

enum Dietary: Int, Codable, CaseIterable, LabeledEnum {
    var id: Self { self }
    
    case dairy
    case gluten
    case fish
    case meat
    
    var label: String {
        switch self {
        case .dairy:
            return "Dairy"
        case .gluten:
            return "Gluten"
        case .fish:
            return "Fish"
        case .meat:
            return "Meat"
        }
    }
}

struct DietaryItems {
    var dairy: Bool = false
    var gluten: Bool = false
    var fish: Bool = false
    var meat: Bool = false
    
    func toSet() -> Set<Dietary> {
        var set = Set<Dietary>()
        if dairy { set.insert(.dairy) }
        if gluten { set.insert(.gluten) }
        if fish { set.insert(.fish) }
        if meat { set.insert(.meat) }
        return set
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
        case duplicateName

        var errorDescription: String? {
            switch self {
            case .nameTooShort:
                return "Item names must be at least 3 characters."
            case .duplicateName:
                return "An item with this name already exists."
            }
        }
    }

    var name: String
    var categoryID: UUID
    var kind: ItemKind
    var dietary: DietaryItems
    var readymealData: ReadymealData

    init(categoryID: UUID, kind: ItemKind = .ingredient, dietary: Set<Dietary> = [],  readymealData: ReadymealData = .default) {
        self.name = ""
        self.categoryID = categoryID
        self.kind = kind
        self.dietary = DietaryItems(
            dairy: dietary.contains(.dairy),
            gluten: dietary.contains(.gluten),
            fish: dietary.contains(.fish),
            meat: dietary.contains(.meat)
        )
        self.readymealData = readymealData
    }

    init(item: Item) {
        self.name = item.name
        self.categoryID = item.category.id
        self.kind = item.itemKind
        self.dietary = DietaryItems(
            dairy: item.dietary.contains(.dairy),
            gluten: item.dietary.contains(.gluten),
            fish: item.dietary.contains(.fish),
            meat: item.dietary.contains(.meat)
        )
        self.readymealData = item.readymealData ?? .default
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
final class Item {
    @Attribute(.unique)
    var id: UUID
    var name: String
    var category: Category
    var kind: Int
    var dietary: Set<Dietary>
    var readymealData: Optional<ReadymealData>
    @Relationship(inverse: \Meal.readymeals)
    var meals: [Meal] = []
    @Relationship(inverse: \PlannedMeal.readymeals)
    var plannedMeals: [PlannedMeal] = []
    
    var itemKind: ItemKind {
        ItemKind(rawValue: kind) ?? ItemKind.ingredient
    }
    
    init(id: UUID = UUID(), name: String = "", category: Category, kind: ItemKind, dietary: Set<Dietary> = [], readymealData: ReadymealData? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.kind = kind.rawValue
        self.dietary = dietary
        self.readymealData = readymealData
    }
}

struct ItemFilter {
    var search: String = ""
    var ingredients: Bool = false
    var readymeals: Bool = false
    var misc: Bool = false
    
    func filter(item: Item) -> Bool {
        var searchFound = false
        var filtered = false
        
        if search.isEmpty {
            searchFound = true
        } else {
            searchFound = item.name.lowercased().contains(search.lowercased())
                || item.category.name.lowercased().contains(search.lowercased())
        }
        
        if !ingredients && !readymeals && !misc {
            filtered = false
        } else {
            switch item.itemKind {
            case .ingredient:
                filtered = !ingredients
            case .readymeal:
                filtered = !readymeals
            case .misc:
                filtered = !misc
            }
        }
        
        return searchFound && !filtered
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
