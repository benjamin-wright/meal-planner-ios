import Foundation
import SwiftData

struct PlannedMealDraft {
    enum ValidationError: Hashable, LocalizedError {
        case noDishes
        case invalidServings
        case invalidPortion
        case duplicateComponent

        var errorDescription: String? {
            switch self {
            case .noDishes:
                return "Please add at least one dish."
            case .invalidServings:
                return "Planned meals must serve at least one person."
            case .invalidPortion:
                return "Ingredient portions need a valid unit and a finite quantity greater than zero."
            case .duplicateComponent:
                return "Each dish must have its own identifier."
            }
        }
    }

    var components: [MealComponentDraft]
    var servings: Int

    init(components: [MealComponentDraft] = [], servings: Int = 2) {
        self.components = components
        self.servings = servings
    }

    init(meal: Meal) {
        self.components = meal.orderedComponents.map { MealComponentDraft(copying: $0) }
        self.servings = 2
    }

    func validate() -> [ValidationError] {
        var errors: [ValidationError] = []
        if components.isEmpty { errors.append(.noDishes) }
        if servings < 1 { errors.append(.invalidServings) }
        if !components.allSatisfy(\.hasValidPortion) { errors.append(.invalidPortion) }
        if Set(components.map(\.id)).count != components.count { errors.append(.duplicateComponent) }
        return errors
    }
}

@Model
final class PlannedMeal {
    @Attribute(.unique) var id: UUID = UUID()
    var mealType: Int
    var day: Int?
    var sortOrder: Int
    var sourceMealID: UUID?
    var servings: Int = 2
    @Relationship(deleteRule: .cascade, inverse: \MealComponent.plannedMeal)
    var components: [MealComponent] = []

    var mealTypeEnum: MealType {
        get { MealType(rawValue: mealType) ?? .dinner }
        set { mealType = newValue.rawValue }
    }

    var dayEnum: Day? {
        get { day.flatMap(Day.init(rawValue:)) }
        set { day = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        mealType: MealType,
        day: Day? = nil,
        sortOrder: Int = 0,
        sourceMealID: UUID? = nil,
        servings: Int = 2,
        components: [MealComponent] = []
    ) {
        self.id = id
        self.mealType = mealType.rawValue
        self.day = day?.rawValue
        self.sortOrder = sortOrder
        self.sourceMealID = sourceMealID
        self.servings = servings
        self.components = components
        components.enumerated().forEach { index, component in
            component.sortOrder = index
            component.plannedMeal = self
        }
    }

    var orderedComponents: [MealComponent] {
        components.sorted {
            $0.sortOrder == $1.sortOrder ? $0.id.uuidString < $1.id.uuidString : $0.sortOrder < $1.sortOrder
        }
    }

    var displayName: String {
        let ordered = orderedComponents
        let mainAndSides = ordered.filter { $0.courseEnum == .main }
            + ordered.filter { $0.courseEnum == .side }
        let displayed = mainAndSides.isEmpty ? ordered : mainAndSides
        return displayed.isEmpty ? "No dishes" : displayed.map(\.displayName).joined(separator: ", ")
    }
}

extension PlannedMeal {
    static func descriptor(id: UUID) -> FetchDescriptor<PlannedMeal> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }
}

@MainActor
final class PlannedMealStore {
    enum Error: LocalizedError {
        case notFound
        case invalidPlacement
        case invalidDraft([PlannedMealDraft.ValidationError])
        case invalidComponent(MealComponentPersistence.Error)

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "This planned meal no longer exists."
            case .invalidPlacement:
                return "Dinners need a day. Breakfasts and lunches must be planned without a day."
            case .invalidDraft(let errors):
                return errors.compactMap(\.errorDescription).joined(separator: " ")
            case .invalidComponent(let error):
                return error.localizedDescription
            }
        }
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func draft(id: UUID) throws -> PlannedMealDraft {
        guard let meal = try context.fetch(PlannedMeal.descriptor(id: id)).first else { throw Error.notFound }
        return PlannedMealDraft(
            components: meal.orderedComponents.map { MealComponentDraft(component: $0) },
            servings: meal.servings
        )
    }

    func save(
        _ draft: PlannedMealDraft,
        id: UUID?,
        mealType: MealType,
        day: Day?,
        sourceMealID: UUID? = nil
    ) throws {
        guard (mealType == .dinner) == (day != nil) else { throw Error.invalidPlacement }
        let validationErrors = draft.validate()
        guard validationErrors.isEmpty else { throw Error.invalidDraft(validationErrors) }

        let existingMeal: PlannedMeal?
        if let id {
            guard let existing = try context.fetch(PlannedMeal.descriptor(id: id)).first else { throw Error.notFound }
            existingMeal = existing
        } else {
            existingMeal = nil
        }
        let selections: [MealComponentPersistence.Selection]
        do {
            selections = try MealComponentPersistence.resolve(
                draft.components,
                context: context,
                existingComponents: existingMeal?.components ?? [],
                plannedMeal: existingMeal
            )
        } catch let error as MealComponentPersistence.Error {
            throw Error.invalidComponent(error)
        }

        let plannedMeal: PlannedMeal
        if let existingMeal {
            plannedMeal = existingMeal
        } else {
            let nextOrder = try context.fetch(FetchDescriptor<PlannedMeal>())
                .filter { $0.mealTypeEnum == mealType && $0.dayEnum == nil }
                .map(\.sortOrder).max().map { $0 + 1 } ?? 0
            plannedMeal = PlannedMeal(mealType: mealType, day: day, sortOrder: nextOrder)
            context.insert(plannedMeal)
        }
        let retainedIDs = Set(draft.components.map(\.id))
        let removed = plannedMeal.components.filter { !retainedIDs.contains($0.id) }
        plannedMeal.components = MealComponentPersistence.apply(
            selections,
            context: context,
            existingComponents: plannedMeal.components,
            plannedMeal: plannedMeal
        )
        plannedMeal.mealTypeEnum = mealType
        plannedMeal.dayEnum = day
        plannedMeal.sourceMealID = sourceMealID ?? plannedMeal.sourceMealID
        plannedMeal.servings = draft.servings
        removed.forEach(context.delete)
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let meal = try context.fetch(PlannedMeal.descriptor(id: id)).first else {
            throw Error.notFound
        }
        context.delete(meal)
        try context.save()
    }

    func swapDinnerDays(_ firstID: UUID, _ secondID: UUID) throws {
        guard firstID != secondID,
              let first = try context.fetch(PlannedMeal.descriptor(id: firstID)).first,
              let second = try context.fetch(PlannedMeal.descriptor(id: secondID)).first,
              first.mealTypeEnum == .dinner,
              second.mealTypeEnum == .dinner else { return }
        let firstDay = first.day
        first.day = second.day
        second.day = firstDay
        try context.save()
    }

    /// Moves the dinner slot at `sourceDay` to `day`, shifting intervening slots.
    /// The source may be empty, in which case the empty slot itself is moved.
    func moveDinner(from sourceDay: Day, to day: Day) throws {
        guard sourceDay != day,
              let sourceIndex = Day.allCases.firstIndex(of: sourceDay),
              let destinationIndex = Day.allCases.firstIndex(of: day) else { return }

        let dinners = try context.fetch(FetchDescriptor<PlannedMeal>())
            .filter { $0.mealTypeEnum == .dinner }

        func dinner(for slot: Day) -> PlannedMeal? {
            dinners.first { $0.dayEnum == slot }
        }

        let movingMeal = dinner(for: sourceDay)

        if sourceIndex < destinationIndex {
            for index in (sourceIndex + 1)...destinationIndex {
                dinner(for: Day.allCases[index])?.dayEnum = Day.allCases[index - 1]
            }
        } else {
            for index in stride(from: sourceIndex - 1, through: destinationIndex, by: -1) {
                dinner(for: Day.allCases[index])?.dayEnum = Day.allCases[index + 1]
            }
        }

        movingMeal?.dayEnum = day
        try context.save()
    }
}
