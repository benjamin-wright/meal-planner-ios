import SwiftData

@Model
final class SavedNameMigrationRecord {
    @Attribute(.unique) var id: String

    init(id: String) {
        self.id = id
    }
}

@MainActor
enum SavedNameMigration {
    static let identifier = "lowercase-saved-names-v1"

    /// Stages the one-time migration and its marker; the caller saves them together.
    static func apply(in context: ModelContext) throws {
        let records = try context.fetch(FetchDescriptor<SavedNameMigrationRecord>())
        guard !records.contains(where: { $0.id == identifier }) else { return }

        // Finish every fetch before mutating so a failed fetch cannot leave a partial migration.
        let categories = try context.fetch(FetchDescriptor<Category>())
        let items = try context.fetch(FetchDescriptor<Item>())
        let recipes = try context.fetch(FetchDescriptor<Recipie>())
        let meals = try context.fetch(FetchDescriptor<Meal>())
        let units = try context.fetch(FetchDescriptor<Unit>())
        let histories = try context.fetch(FetchDescriptor<MealHistory>())
        let shoppingEntries = try context.fetch(FetchDescriptor<ShoppingListEntry>())

        // Update in place: case-colliding names must not merge records or their relationships.
        categories.forEach { $0.name = $0.name.lowercased() }
        items.forEach { $0.name = $0.name.lowercased() }
        recipes.forEach { $0.name = $0.name.lowercased() }
        meals.forEach { $0.name = $0.name.lowercased() }
        units.forEach { $0.name = $0.name.lowercased() }
        histories.forEach { $0.name = $0.name.lowercased() }
        shoppingEntries.forEach { $0.name = $0.name.lowercased() }
        context.insert(SavedNameMigrationRecord(id: identifier))
    }
}
