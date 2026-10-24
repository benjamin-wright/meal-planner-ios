import Foundation
import SwiftData

@Model
final class ShoppingListEntry {
    @Attribute(.unique)
    var id: UUID = UUID()
    var name: String
    var quantity: Double
    var sortOrder: Int
    var isChecked: Bool
    @Relationship(deleteRule: .nullify)
    var item: Item?
    @Relationship(deleteRule: .nullify)
    var category: Category?
    @Relationship(deleteRule: .nullify)
    var unit: Unit?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        sortOrder: Int = 0,
        isChecked: Bool = false,
        item: Item? = nil,
        category: Category? = nil,
        unit: Unit? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.sortOrder = sortOrder
        self.isChecked = isChecked
        self.item = item
        self.category = category
        self.unit = unit
    }

    var formattedQuantity: String {
        unit?.toString(forValue: quantity) ?? String(format: "%g", quantity)
    }
}

struct ShoppingListEntrySnapshot {
    let id: UUID
    let name: String
    let quantity: Double
    let sortOrder: Int
    let itemID: UUID?
    let categoryID: UUID?
    let unitID: UUID?

    init(_ entry: ShoppingListEntry) {
        id = entry.id
        name = entry.name
        quantity = entry.quantity
        sortOrder = entry.sortOrder
        itemID = entry.item?.id
        categoryID = entry.category?.id
        unitID = entry.unit?.id
    }
}

@MainActor
final class ShoppingListStore {
    typealias Error = ShoppingListError

    private let context: ModelContext
    private let saveRegeneratedList: (ModelContext) throws -> Void

    init(context: ModelContext, saveRegeneratedList: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.context = context
        self.saveRegeneratedList = saveRegeneratedList
    }

    func regenerate() throws {
        guard let settings = try context.fetch(FetchDescriptor<AppSettings>()).first else {
            throw Error.missingSettings
        }
        let units = try context.fetch(FetchDescriptor<Unit>()).compactMap(\.definition)
        let items = try context.fetch(FetchDescriptor<Item>())
        let recipes = try context.fetch(FetchDescriptor<Recipie>())
        let meals = try context.fetch(FetchDescriptor<PlannedMeal>())
        let misc = try context.fetch(FetchDescriptor<PlannedMiscEntry>())
        let input = ShoppingListInput(
            units: Dictionary(uniqueKeysWithValues: units.map { ($0.id, $0) }),
            items: Dictionary(uniqueKeysWithValues: items.compactMap { item -> (UUID, ShoppingListInput.Item)? in
                guard let kind = ItemKind(rawValue: item.kind) else { return nil }
                return (item.id, ShoppingListInput.Item(
                    name: item.name, kind: kind,
                    category: .init(id: item.category.id, order: item.category.order),
                    servings: item.readymealData?.serves
                ))
            }),
            recipes: Dictionary(uniqueKeysWithValues: recipes.map {
                ($0.id, ShoppingListInput.Recipe(name: $0.name, servings: $0.serves,
                                                 ingredients: $0.ingredients.map(RecipieIngredientDraft.init)))
            }),
            meals: try meals.map { meal in
                .init(servings: meal.servings, components: try meal.components.map { component in
                    guard component.source != nil else { throw Error.missingMealComponentReference }
                    return MealComponentDraft(component: component)
                })
            },
            miscellaneous: misc.sorted { $0.sortOrder < $1.sortOrder }.map {
                .init(name: $0.displayName, itemID: $0.item?.id,
                      category: $0.category.map { .init(id: $0.id, order: $0.order) },
                      unitID: $0.unit?.id, quantity: $0.quantity)
            },
            preferredWeightID: settings.preferredWeight.id,
            preferredVolumeID: settings.preferredVolume.id
        )
        try replace(with: ShoppingListCalculator.generate(from: input))
    }

    private func replace(with pending: [GeneratedShoppingEntry]) throws {
        // Snapshot shared inputs first, then mutate only this context so a failed
        // replacement can be rolled back without discarding pending editor changes.
        let replacementContext = ModelContext(context.container)
        replacementContext.autosaveEnabled = false
        do {
            // Related replacements can register immediately, so capture the old rows first.
            let existingEntries = try replacementContext.fetch(FetchDescriptor<ShoppingListEntry>())
            let itemsByID = Dictionary(uniqueKeysWithValues:
                try replacementContext.fetch(FetchDescriptor<Item>()).map { ($0.id, $0) })
            let categoriesByID = Dictionary(uniqueKeysWithValues:
                try replacementContext.fetch(FetchDescriptor<Category>()).map { ($0.id, $0) })
            let unitsByID = Dictionary(uniqueKeysWithValues:
                try replacementContext.fetch(FetchDescriptor<Unit>()).map { ($0.id, $0) })
            let replacements = try pending.enumerated().map { sortOrder, value in
                let item = value.itemID.flatMap { itemsByID[$0] }
                guard value.itemID == nil || item != nil else { throw Error.missingItem }
                guard let category = categoriesByID[value.categoryID] else { throw Error.missingCategory }
                guard let unit = unitsByID[value.unitID] else { throw Error.missingUnit }
                return ShoppingListEntry(
                    name: value.name, quantity: value.quantity, sortOrder: sortOrder,
                    item: item, category: category, unit: unit
                )
            }

            existingEntries.forEach(replacementContext.delete)
            replacements.forEach(replacementContext.insert)
            try saveRegeneratedList(replacementContext)
        } catch {
            replacementContext.rollback()
            throw error
        }
    }

    func addItem(itemID: UUID, unitID: UUID, quantity: Double) throws {
        guard DomainValidation.isPositiveFinite(quantity) else { throw Error.invalidQuantity }
        guard let item = try context.fetch(Item.descriptor(id: itemID)).first else { throw Error.missingItem }
        guard let unit = try context.fetch(Unit.descriptor(id: unitID)).first,
              unit.definition?.isValid == true else { throw Error.missingUnit }
        try insert(name: item.name, item: item, category: item.category, unit: unit, quantity: quantity)
    }

    func addNote(_ name: String, categoryID: UUID, unitID: UUID, quantity: Double) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw Error.emptyName }
        guard DomainValidation.isPositiveFinite(quantity) else { throw Error.invalidQuantity }
        guard let category = try context.fetch(Category.descriptor(id: categoryID)).first else {
            throw Error.missingCategory
        }
        guard let unit = try context.fetch(Unit.descriptor(id: unitID)).first,
              unit.definition?.isValid == true else { throw Error.missingUnit }
        try insert(name: trimmedName, category: category, unit: unit, quantity: quantity)
    }

    func setChecked(_ isChecked: Bool, id: UUID) throws {
        let descriptor = FetchDescriptor<ShoppingListEntry>(predicate: #Predicate { $0.id == id })
        guard let entry = try context.fetch(descriptor).first else { return }
        entry.isChecked = isChecked
        try context.save()
    }

    func uncheckAll() throws {
        let checked = try context.fetch(FetchDescriptor<ShoppingListEntry>()).filter(\.isChecked)
        checked.forEach { $0.isChecked = false }
        try context.save()
    }

    func hasCheckedEntries() throws -> Bool {
        var descriptor = FetchDescriptor<ShoppingListEntry>(predicate: #Predicate { $0.isChecked })
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }

    func removeChecked() throws -> [ShoppingListEntrySnapshot] {
        let checked = try context.fetch(FetchDescriptor<ShoppingListEntry>()).filter(\.isChecked)
        let snapshots = checked.map(ShoppingListEntrySnapshot.init)
        checked.forEach(context.delete)
        try context.save()
        return snapshots
    }

    func restore(_ snapshots: [ShoppingListEntrySnapshot]) throws {
        let itemsByID = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<Item>()).map { ($0.id, $0) }
        )
        let categoriesByID = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<Category>()).map { ($0.id, $0) }
        )
        let unitsByID = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<Unit>()).map { ($0.id, $0) }
        )

        for snapshot in snapshots {
            context.insert(ShoppingListEntry(
                id: snapshot.id,
                name: snapshot.name,
                quantity: snapshot.quantity,
                sortOrder: snapshot.sortOrder,
                item: snapshot.itemID.flatMap { itemsByID[$0] },
                category: snapshot.categoryID.flatMap { categoriesByID[$0] },
                unit: snapshot.unitID.flatMap { unitsByID[$0] }
            ))
        }
        try context.save()
    }

    private func insert(
        name: String,
        item: Item? = nil,
        category: Category,
        unit: Unit,
        quantity: Double
    ) throws {
        let nextOrder = (try context.fetch(FetchDescriptor<ShoppingListEntry>()).map(\.sortOrder).max() ?? -1) + 1
        context.insert(ShoppingListEntry(
            name: name,
            quantity: quantity,
            sortOrder: nextOrder,
            item: item,
            category: category,
            unit: unit
        ))
        try context.save()
    }
}
