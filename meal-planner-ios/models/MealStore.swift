import Foundation
import SwiftData

@MainActor
final class MealStore {
    enum Error: LocalizedError {
        case notFound
        case invalidDraft([MealDraft.ValidationError])
        case missingDishReference

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "This meal no longer exists."
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
        guard let meal = try context.fetch(Meal.descriptor(id: id)).first else {
            throw Error.notFound
        }
        return MealDraft(meal: meal)
    }

    func save(_ draft: MealDraft, id: UUID?) throws {
        let existingNames = try context.fetch(FetchDescriptor<Meal>())
            .filter { $0.id != id }
            .map(\.name)
        let validationErrors = draft.validate(existingNames: existingNames)
        guard validationErrors.isEmpty else {
            throw Error.invalidDraft(validationErrors)
        }

        let recipiesByID = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<Recipie>()).map { ($0.id, $0) }
        )
        let readyMealsByID = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<Item>())
                .filter { $0.itemKind == .readymeal }
                .map { ($0.id, $0) }
        )
        var recipies: [Recipie] = []
        var readymeals: [Item] = []

        for dish in draft.dishes {
            switch dish {
            case .recipe(let id):
                guard let recipie = recipiesByID[id] else { throw Error.missingDishReference }
                recipies.append(recipie)
            case .readymeal(let id):
                guard let readymeal = readyMealsByID[id] else { throw Error.missingDishReference }
                readymeals.append(readymeal)
            }
        }

        let meal: Meal
        if let id {
            guard let existing = try context.fetch(Meal.descriptor(id: id)).first else {
                throw Error.notFound
            }
            meal = existing
        } else {
            meal = Meal(mealType: draft.mealType)
            context.insert(meal)
        }

        meal.name = draft.name
        meal.mealType = draft.mealType
        meal.recipies = recipies
        meal.readymeals = readymeals
        try context.save()
    }

    func delete(ids: [UUID]) throws {
        let selectedIDs = Set(ids)
        let meals = try context.fetch(FetchDescriptor<Meal>())
        meals.filter { selectedIDs.contains($0.id) }.forEach(context.delete)
        try context.save()
    }
}
