import Foundation
import SwiftData

@MainActor
final class MealStore {
    enum Error: LocalizedError {
        case notFound
        case invalidDraft([MealDraft.ValidationError])
        case invalidComponent(MealComponentPersistence.Error)

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "This meal no longer exists."
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

    func draft(id: UUID) throws -> MealDraft {
        guard let meal = try context.fetch(Meal.descriptor(id: id)).first else {
            throw Error.notFound
        }
        return MealDraft(meal: meal)
    }

    @discardableResult
    func save(_ draft: MealDraft, id: UUID?) throws -> UUID {
        var draft = draft
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingNames = try context.fetch(FetchDescriptor<Meal>())
            .filter { $0.id != id }
            .map(\.name)
        let validationErrors = draft.validate(existingNames: existingNames)
        guard validationErrors.isEmpty else { throw Error.invalidDraft(validationErrors) }

        let existingMeal: Meal?
        if let id {
            guard let existing = try context.fetch(Meal.descriptor(id: id)).first else { throw Error.notFound }
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
                meal: existingMeal
            )
        } catch let error as MealComponentPersistence.Error {
            throw Error.invalidComponent(error)
        }

        // Validate every source, portion, and owner before changing persisted records.
        let meal = existingMeal ?? Meal(mealType: draft.mealType)
        if existingMeal == nil { context.insert(meal) }
        let retainedIDs = Set(draft.components.map(\.id))
        let removed = meal.components.filter { !retainedIDs.contains($0.id) }
        meal.components = MealComponentPersistence.apply(
            selections,
            context: context,
            existingComponents: meal.components,
            meal: meal
        )
        meal.name = draft.name
        meal.mealType = draft.mealType
        removed.forEach(context.delete)
        try context.save()
        return meal.id
    }

    func delete(ids: [UUID]) throws {
        let selectedIDs = Set(ids)
        let meals = try context.fetch(FetchDescriptor<Meal>())
        meals.filter { selectedIDs.contains($0.id) }.forEach(context.delete)
        try context.save()
    }
}
