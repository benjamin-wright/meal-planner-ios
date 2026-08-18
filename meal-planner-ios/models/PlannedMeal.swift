import Foundation
import SwiftData

@Model
final class PlannedMeal {
    @Attribute(.unique)
    var id: UUID = UUID()
    var mealType: Int
    var day: Int?
    var sortOrder: Int
    var sourceMealID: UUID?
    var name: String
    @Relationship(deleteRule: .nullify)
    var recipies: [Recipie]
    @Relationship(deleteRule: .nullify)
    var readymeals: [Item]

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
        name: String = "",
        recipies: [Recipie] = [],
        readymeals: [Item] = []
    ) {
        self.id = id
        self.mealType = mealType.rawValue
        self.day = day?.rawValue
        self.sortOrder = sortOrder
        self.sourceMealID = sourceMealID
        self.name = name
        self.recipies = recipies
        self.readymeals = readymeals
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
        case invalidDraft([MealDraft.ValidationError])
        case missingDishReference

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "This planned meal no longer exists."
            case .invalidDraft(let errors):
                return errors.compactMap(\.errorDescription).joined(separator: " ")
            case .missingDishReference:
                return "A selected recipe or ready meal no longer exists."
            }
        }
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func draft(id: UUID) throws -> MealDraft {
        guard let meal = try context.fetch(PlannedMeal.descriptor(id: id)).first else {
            throw Error.notFound
        }
        return MealDraft(
            name: meal.name,
            mealType: meal.mealTypeEnum,
            dishes: meal.recipies.map { .recipe($0.id) } + meal.readymeals.map { .readymeal($0.id) }
        )
    }

    func save(
        _ draft: MealDraft,
        id: UUID?,
        mealType: MealType,
        day: Day?,
        sourceMealID: UUID? = nil
    ) throws {
        let validationErrors = draft.validate()
        guard validationErrors.isEmpty else { throw Error.invalidDraft(validationErrors) }

        let recipies = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<Recipie>()).map { ($0.id, $0) }
        )
        let readymeals = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<Item>())
                .filter { $0.itemKind == .readymeal }
                .map { ($0.id, $0) }
        )
        var selectedRecipies: [Recipie] = []
        var selectedReadymeals: [Item] = []

        for dish in draft.dishes {
            switch dish {
            case .recipe(let id):
                guard let recipie = recipies[id] else { throw Error.missingDishReference }
                selectedRecipies.append(recipie)
            case .readymeal(let id):
                guard let readymeal = readymeals[id] else { throw Error.missingDishReference }
                selectedReadymeals.append(readymeal)
            }
        }

        let plannedMeal: PlannedMeal
        if let id {
            guard let existing = try context.fetch(PlannedMeal.descriptor(id: id)).first else {
                throw Error.notFound
            }
            plannedMeal = existing
        } else {
            let nextOrder = try context.fetch(FetchDescriptor<PlannedMeal>())
                .filter { $0.mealTypeEnum == mealType && $0.dayEnum == nil }
                .map(\.sortOrder)
                .max()
                .map { $0 + 1 } ?? 0
            plannedMeal = PlannedMeal(mealType: mealType, day: day, sortOrder: nextOrder)
            context.insert(plannedMeal)
        }

        plannedMeal.name = draft.name
        plannedMeal.mealTypeEnum = mealType
        plannedMeal.dayEnum = day
        plannedMeal.sourceMealID = sourceMealID ?? plannedMeal.sourceMealID
        plannedMeal.recipies = selectedRecipies
        plannedMeal.readymeals = selectedReadymeals
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

    func moveDinner(id: UUID, to day: Day) throws {
        guard let meal = try context.fetch(PlannedMeal.descriptor(id: id)).first else {
            throw Error.notFound
        }
        guard meal.mealTypeEnum == .dinner,
              let sourceDay = meal.dayEnum,
              sourceDay != day,
              let sourceIndex = Day.allCases.firstIndex(of: sourceDay),
              let destinationIndex = Day.allCases.firstIndex(of: day) else { return }

        let dinners = try context.fetch(FetchDescriptor<PlannedMeal>())
            .filter { $0.id != id && $0.mealTypeEnum == .dinner }

        func dinner(for slot: Day) -> PlannedMeal? {
            dinners.first { $0.dayEnum == slot }
        }

        if sourceIndex < destinationIndex {
            for index in (sourceIndex + 1)...destinationIndex {
                dinner(for: Day.allCases[index])?.dayEnum = Day.allCases[index - 1]
            }
        } else {
            for index in stride(from: sourceIndex - 1, through: destinationIndex, by: -1) {
                dinner(for: Day.allCases[index])?.dayEnum = Day.allCases[index + 1]
            }
        }

        meal.dayEnum = day
        try context.save()
    }
}

private extension MealDraft {
    init(name: String, mealType: MealType, dishes: [DishID]) {
        self.name = name
        self.mealType = mealType
        self.dishes = dishes
    }
}
