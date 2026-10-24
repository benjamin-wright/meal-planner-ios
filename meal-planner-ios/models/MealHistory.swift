import Foundation
import SwiftData

/// A value snapshot, deliberately independent of the catalogue's deletion rules.
struct MealHistoryComponent: Codable, Hashable {
    var id: UUID
    var kind: MealComponentKind
    var sourceID: UUID
    var course: CourseType
    var quantity: Double?
    var unitID: UUID?
    var ingredientOverrides: [RecipeIngredientOverride]

    init(_ component: MealComponentDraft) {
        id = component.id
        switch component.source {
        case .recipe: kind = .recipe
        case .readymeal: kind = .readymeal
        case .ingredient: kind = .ingredient
        }
        sourceID = component.source.id
        course = component.course
        quantity = component.quantity
        unitID = component.unitID
        ingredientOverrides = component.ingredientOverrides
    }

    var draft: MealComponentDraft {
        MealComponentDraft(
            id: id, source: kind.source(id: sourceID), course: course,
            quantity: quantity, unitID: unitID, ingredientOverrides: ingredientOverrides
        )
    }
}

/// One remembered choice per planned meal, retained when the planner is cleared.
@Model
final class MealHistory {
    @Attribute(.unique) var id: UUID
    var name: String
    var mealType: Int
    var servings: Int
    var savedAt: Date
    // Explicit encoding keeps nested snapshots as one value, with no model relationships.
    var componentData: Data

    var mealTypeEnum: MealType {
        MealType(rawValue: mealType) ?? .dinner
    }

    var components: [MealHistoryComponent] {
        // An unreadable snapshot produces an invalid draft, never a partial remembered meal.
        (try? JSONDecoder().decode([MealHistoryComponent].self, from: componentData)) ?? []
    }

    var draft: PlannedMealDraft {
        PlannedMealDraft(
            components: components.map { MealComponentDraft(copying: $0.draft) },
            servings: servings
        )
    }

    init(
        id: UUID = UUID(), name: String, mealType: MealType, servings: Int = 2,
        components: [MealComponentDraft], savedAt: Date = .now
    ) throws {
        let data = try Self.encode(components)
        self.id = id
        self.name = name
        self.mealType = mealType.rawValue
        self.servings = servings
        self.savedAt = savedAt
        self.componentData = data
    }

    fileprivate init(plannedMeal: PlannedMeal, componentData: Data, savedAt: Date) {
        id = plannedMeal.id
        name = plannedMeal.displayName
        mealType = plannedMeal.mealType
        servings = plannedMeal.servings
        self.savedAt = savedAt
        self.componentData = componentData
    }

    static func descriptor(id: UUID) -> FetchDescriptor<MealHistory> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }

    static func encode(_ components: [MealComponentDraft]) throws -> Data {
        let ordered = components.enumerated().sorted {
            if $0.element.course != $1.element.course {
                return $0.element.course.rawValue < $1.element.course.rawValue
            }
            return $0.offset < $1.offset
        }.map { MealHistoryComponent($0.element) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(ordered)
    }
}

@MainActor
final class MealHistoryStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Stages a history update alongside its planned meal; the caller saves both together.
    /// Fetches and encoding happen before the caller mutates the active plan.
    func remember(
        _ plannedMeal: PlannedMeal, existing: MealHistory?, componentData: Data,
        at date: Date = .now
    ) {
        guard let existing else {
            context.insert(MealHistory(plannedMeal: plannedMeal, componentData: componentData, savedAt: date))
            return
        }
        guard existing.name != plannedMeal.displayName
            || existing.mealType != plannedMeal.mealType
            || existing.servings != plannedMeal.servings
            || existing.componentData != componentData else { return }
        existing.name = plannedMeal.displayName
        existing.mealType = plannedMeal.mealType
        existing.servings = plannedMeal.servings
        existing.componentData = componentData
        existing.savedAt = date
    }

    /// Backfills only active plans that predate history support, never saved meal templates.
    /// Existing snapshots and their timestamps remain unchanged on subsequent launches.
    func synchronizeExisting(at date: Date = .now) throws {
        let plannedMeals = try context.fetch(FetchDescriptor<PlannedMeal>())
        try synchronize(plannedMeals, at: date)
    }

    func synchronize(_ plannedMeals: [PlannedMeal], at date: Date = .now) throws {
        let rememberedIDs = Set(try context.fetch(FetchDescriptor<MealHistory>()).map(\.id))
        let additions: [MealHistory] = try plannedMeals.filter { !rememberedIDs.contains($0.id) }.compactMap { meal in
            let components = meal.orderedComponents
            // Catalogue deletion can leave an empty or incomplete active meal behind.
            guard components.allSatisfy({ $0.source != nil }) else { return nil }
            let draft = PlannedMealDraft(
                components: components.map { MealComponentDraft(component: $0) }, servings: meal.servings
            )
            guard draft.validate().isEmpty else { return nil }
            return MealHistory(plannedMeal: meal, componentData: try MealHistory.encode(draft.components), savedAt: date)
        }
        // Complete every fetch/encoding before staging changes to avoid a partial backfill.
        additions.forEach(context.insert)
    }
}
