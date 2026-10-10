import Foundation
import SwiftData

enum MealComponentKind: Int, Codable {
    case recipe
    case readymeal
    case ingredient

    func source(id: UUID) -> DishID {
        switch self {
        case .recipe: return .recipe(id)
        case .readymeal: return .readymeal(id)
        case .ingredient: return .ingredient(id)
        }
    }
}

struct MealComponentDraft: Identifiable, Hashable {
    var id: UUID
    var source: DishID
    var course: CourseType
    /// Direct ingredient quantity per person; recipes and ready meals use their own yield.
    var quantity: Double?
    var unitID: UUID?

    init(
        id: UUID = UUID(),
        source: DishID,
        course: CourseType = .main,
        quantity: Double? = nil,
        unitID: UUID? = nil
    ) {
        self.id = id
        self.source = source
        self.course = course
        self.quantity = quantity
        self.unitID = unitID
    }

    init(component: MealComponent) {
        self.init(
            id: component.id,
            source: component.source ?? component.kindEnum.source(id: component.id),
            course: component.courseEnum,
            quantity: component.quantity,
            unitID: component.unit?.id
        )
    }

    init(copying component: MealComponentDraft) {
        self = component
        id = UUID()
    }

    init(copying component: MealComponent) {
        self.init(copying: MealComponentDraft(component: component))
    }

    var hasValidPortion: Bool {
        switch source {
        case .ingredient:
            return quantity.map { $0 > 0 && $0.isFinite } == true && unitID != nil
        case .recipe, .readymeal:
            return quantity == nil && unitID == nil
        }
    }
}

/// An occurrence of a recipe, ready meal, or direct ingredient in one meal.
@Model
final class MealComponent {
    @Attribute(.unique) var id: UUID = UUID()
    var kind: Int
    var course: Int
    var sortOrder: Int = 0
    var recipe: Recipie?
    var item: Item?
    var quantity: Double?
    var unit: Unit?
    var meal: Meal?
    var plannedMeal: PlannedMeal?

    var kindEnum: MealComponentKind {
        MealComponentKind(rawValue: kind) ?? .ingredient
    }

    var courseEnum: CourseType {
        get { CourseType(rawValue: course) ?? .main }
        set { course = newValue.rawValue }
    }

    var source: DishID? {
        guard let kind = MealComponentKind(rawValue: kind) else { return nil }
        switch kind {
        case .recipe:
            guard let recipe, item == nil else { return nil }
            return .recipe(recipe.id)
        case .readymeal:
            guard recipe == nil, let item, item.kind == ItemKind.readymeal.rawValue else { return nil }
            return .readymeal(item.id)
        case .ingredient:
            guard recipe == nil, let item, item.kind == ItemKind.ingredient.rawValue else { return nil }
            return .ingredient(item.id)
        }
    }

    var displayName: String { recipe?.name ?? item?.name ?? "Missing dish" }

    init(
        id: UUID = UUID(),
        kind: MealComponentKind,
        course: CourseType = .main,
        sortOrder: Int = 0,
        recipe: Recipie? = nil,
        item: Item? = nil,
        quantity: Double? = nil,
        unit: Unit? = nil,
        meal: Meal? = nil,
        plannedMeal: PlannedMeal? = nil
    ) {
        self.id = id
        self.kind = kind.rawValue
        self.course = course.rawValue
        self.sortOrder = sortOrder
        self.recipe = recipe
        self.item = item
        self.quantity = quantity
        self.unit = unit
        self.meal = meal
        self.plannedMeal = plannedMeal
    }

    convenience init(id: UUID = UUID(), recipe: Recipie, course: CourseType = .main, sortOrder: Int = 0) {
        self.init(id: id, kind: .recipe, course: course, sortOrder: sortOrder, recipe: recipe)
    }

    convenience init(id: UUID = UUID(), readymeal: Item, course: CourseType = .main, sortOrder: Int = 0) {
        self.init(id: id, kind: .readymeal, course: course, sortOrder: sortOrder, item: readymeal)
    }

    convenience init(
        id: UUID = UUID(), ingredient: Item, unit: Unit, quantity: Double, course: CourseType = .side,
        sortOrder: Int = 0
    ) {
        self.init(id: id, kind: .ingredient, course: course, sortOrder: sortOrder,
                  item: ingredient, quantity: quantity, unit: unit)
    }

    convenience init(copying component: MealComponent) {
        self.init(
            kind: component.kindEnum,
            course: component.courseEnum,
            sortOrder: component.sortOrder,
            recipe: component.recipe,
            item: component.item,
            quantity: component.quantity,
            unit: component.unit
        )
    }
}

@MainActor
enum MealComponentPersistence {
    enum Error: LocalizedError {
        case missingSource
        case missingUnit
        case ownershipConflict

        var errorDescription: String? {
            switch self {
            case .missingSource:
                return "A selected recipe or item no longer exists or has changed kind."
            case .missingUnit:
                return "Choose a valid unit for every ingredient portion."
            case .ownershipConflict:
                return "A dish belongs to another meal. Add a new dish instead."
            }
        }
    }

    struct Selection {
        let draft: MealComponentDraft
        let kind: MealComponentKind
        let recipe: Recipie?
        let item: Item?
        let unit: Unit?
    }

    static func resolve(
        _ drafts: [MealComponentDraft],
        context: ModelContext,
        existingComponents: [MealComponent],
        meal: Meal? = nil,
        plannedMeal: PlannedMeal? = nil
    ) throws -> [Selection] {
        let recipes = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Recipie>()).map { ($0.id, $0) })
        let items = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Item>()).map { ($0.id, $0) })
        let units = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Unit>()).map { ($0.id, $0) })
        let allComponents = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<MealComponent>()).map { ($0.id, $0) })
        let ownedIDs = Set(existingComponents.map(\.id))

        return try drafts.map { draft in
            if let row = allComponents[draft.id] {
                guard ownedIDs.contains(row.id),
                      row.meal?.id == meal?.id,
                      row.plannedMeal?.id == plannedMeal?.id else {
                    throw Error.ownershipConflict
                }
            }
            switch draft.source {
            case .recipe(let id):
                guard let recipe = recipes[id] else { throw Error.missingSource }
                return Selection(draft: draft, kind: .recipe, recipe: recipe, item: nil, unit: nil)
            case .readymeal(let id):
                guard let item = items[id], item.kind == ItemKind.readymeal.rawValue else { throw Error.missingSource }
                return Selection(draft: draft, kind: .readymeal, recipe: nil, item: item, unit: nil)
            case .ingredient(let id):
                guard let item = items[id], item.kind == ItemKind.ingredient.rawValue else { throw Error.missingSource }
                guard let unitID = draft.unitID, let unit = units[unitID],
                      UnitType(rawValue: unit.type) != nil,
                      unit.base > 0, unit.base.isFinite else { throw Error.missingUnit }
                return Selection(draft: draft, kind: .ingredient, recipe: nil, item: item, unit: unit)
            }
        }
    }

    static func apply(
        _ selections: [Selection],
        context: ModelContext,
        existingComponents: [MealComponent],
        meal: Meal? = nil,
        plannedMeal: PlannedMeal? = nil
    ) -> [MealComponent] {
        let existing = Dictionary(uniqueKeysWithValues: existingComponents.map { ($0.id, $0) })
        return selections.enumerated().map { index, selection in
            let row: MealComponent
            if let current = existing[selection.draft.id] {
                row = current
            } else {
                row = MealComponent(id: selection.draft.id, kind: selection.kind)
                context.insert(row)
            }
            row.kind = selection.kind.rawValue
            row.recipe = selection.recipe
            row.item = selection.item
            row.courseEnum = selection.draft.course
            row.sortOrder = index
            row.quantity = selection.draft.quantity
            row.unit = selection.unit
            row.meal = meal
            row.plannedMeal = plannedMeal
            return row
        }
    }
}
