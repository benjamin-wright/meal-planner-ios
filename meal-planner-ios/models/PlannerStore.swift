import SwiftData

@MainActor
final class PlannerStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func clear() throws {
        let meals = try context.fetch(FetchDescriptor<PlannedMeal>())
        let miscEntries = try context.fetch(FetchDescriptor<PlannedMiscEntry>())
        meals.forEach(context.delete)
        miscEntries.forEach(context.delete)
        try context.save()
    }
}
