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
    enum Error: LocalizedError {
        case missingSettings
        case missingCountUnit
        case invalidRecipe(String)
        case invalidRecipeIngredient(String)
        case invalidMealIngredient(String)
        case invalidMealIngredientItem(String)
        case missingMealComponentReference
        case incompleteMiscEntry(String)
        case incompatibleUnits
        case emptyName
        case missingItem
        case missingCategory
        case missingUnit
        case invalidQuantity

        var errorDescription: String? {
            switch self {
            case .missingSettings:
                return "Choose preferred weight and volume units in Settings first."
            case .missingCountUnit:
                return "Add a count unit before generating ready meals."
            case .invalidRecipe(let name):
                return "\(name) must serve at least one person before the list can be generated."
            case .invalidRecipeIngredient(let name):
                return "\(name) contains an ingredient quantity that must be finite and greater than zero."
            case .invalidMealIngredient(let name):
                return "The portion of \(name) must be a valid quantity greater than zero."
            case .invalidMealIngredientItem(let name):
                return "\(name) must be an ingredient before it can be added directly to a meal."
            case .missingMealComponentReference:
                return "A recipe, item, or unit used in a planned meal no longer exists."
            case .incompleteMiscEntry(let name):
                return "\(name) needs a category, unit, and positive quantity."
            case .incompatibleUnits:
                return "A unit could not be converted to the preferred unit."
            case .emptyName:
                return "Enter a name for the shopping-list entry."
            case .missingItem:
                return "The selected item no longer exists."
            case .missingCategory:
                return "The selected category no longer exists."
            case .missingUnit:
                return "The selected unit no longer exists."
            case .invalidQuantity:
                return "Quantity must be greater than zero."
            }
        }
    }

    private struct AggregationKey: Hashable {
        let itemID: UUID
        let unitType: UnitType
        let countUnitID: UUID?
    }

    private struct PendingEntry {
        var name: String
        var quantity: Double
        var itemID: UUID?
        var categoryID: UUID
        var categoryOrder: Int
        var unitID: UUID
    }

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

        let units = try context.fetch(FetchDescriptor<Unit>())
        let countUnit = Unit.defaultForNewObject(in: units.filter { $0.unitType == .count })
        let meals = try context.fetch(FetchDescriptor<PlannedMeal>())
        let miscEntries = try context.fetch(FetchDescriptor<PlannedMiscEntry>())
        let itemsByID = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<Item>()).map { ($0.id, $0) }
        )
        let recipesByID = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<Recipie>()).map { ($0.id, $0) }
        )
        let unitsByID = Dictionary(uniqueKeysWithValues: units.map { ($0.id, $0) })
        var aggregated: [AggregationKey: PendingEntry] = [:]
        var standalone: [PendingEntry] = []

        func add(item: Item, unit sourceUnit: Unit, quantity: Double) throws {
            guard quantity > 0, quantity.isFinite else { throw Error.invalidQuantity }

            let outputUnit: Unit
            let outputQuantity: Double
            switch sourceUnit.unitType {
            case .weight:
                outputUnit = settings.preferredWeight
                guard let converted = sourceUnit.convert(quantity, to: outputUnit) else {
                    throw Error.incompatibleUnits
                }
                outputQuantity = converted
            case .volume:
                outputUnit = settings.preferredVolume
                guard let converted = sourceUnit.convert(quantity, to: outputUnit) else {
                    throw Error.incompatibleUnits
                }
                outputQuantity = converted
            case .count:
                outputUnit = sourceUnit
                outputQuantity = quantity
            }
            guard outputQuantity > 0, outputQuantity.isFinite else {
                throw Error.invalidQuantity
            }

            let key = AggregationKey(
                itemID: item.id,
                unitType: sourceUnit.unitType,
                countUnitID: sourceUnit.unitType == .count ? sourceUnit.id : nil
            )
            if aggregated[key] != nil {
                let total = aggregated[key]!.quantity + outputQuantity
                guard total.isFinite else { throw Error.invalidQuantity }
                aggregated[key]!.quantity = total
            } else {
                aggregated[key] = PendingEntry(
                    name: item.name,
                    quantity: outputQuantity,
                    itemID: item.id,
                    categoryID: item.category.id,
                    categoryOrder: item.category.order,
                    unitID: outputUnit.id
                )
            }
        }

        for meal in meals {
            for component in meal.components {
                switch component.source {
                case .recipe(let id):
                    guard let recipie = recipesByID[id] else { throw Error.missingMealComponentReference }
                    guard recipie.serves > 0 else { throw Error.invalidRecipe(recipie.name) }
                    let scale = Double(meal.servings) / Double(recipie.serves)
                    for ingredient in recipie.ingredients {
                        guard ingredient.quantity > 0, ingredient.quantity.isFinite else {
                            throw Error.invalidRecipeIngredient(recipie.name)
                        }
                        try add(item: ingredient.item, unit: ingredient.unit, quantity: ingredient.quantity * scale)
                    }
                case .readymeal(let id):
                    guard let readymeal = itemsByID[id], readymeal.itemKind == .readymeal else {
                        throw Error.missingMealComponentReference
                    }
                    guard let countUnit else { throw Error.missingCountUnit }
                    let serves = max(readymeal.readymealData?.serves ?? 1, 1)
                    let quantity = ceil(Double(meal.servings) / Double(serves))
                    try add(item: readymeal, unit: countUnit, quantity: quantity)
                case .ingredient(let id):
                    guard let item = itemsByID[id],
                          let unitID = component.unit?.id,
                          let unit = unitsByID[unitID],
                          UnitType(rawValue: unit.type) != nil,
                          unit.base > 0, unit.base.isFinite else {
                        throw Error.missingMealComponentReference
                    }
                    guard item.itemKind == .ingredient else { throw Error.invalidMealIngredientItem(item.name) }
                    guard let portion = component.quantity, portion > 0, portion.isFinite else {
                        throw Error.invalidMealIngredient(item.name)
                    }
                    let quantity = portion * Double(meal.servings)
                    guard quantity > 0, quantity.isFinite else { throw Error.invalidMealIngredient(item.name) }
                    try add(item: item, unit: unit, quantity: quantity)
                case nil:
                    throw Error.missingMealComponentReference
                }
            }
        }

        for entry in miscEntries.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            guard let category = entry.category,
                  let unit = entry.unit,
                  entry.quantity > 0,
                  entry.quantity.isFinite else {
                throw Error.incompleteMiscEntry(entry.displayName.isEmpty ? "A miscellaneous entry" : entry.displayName)
            }
            if let item = entry.item {
                try add(item: item, unit: unit, quantity: entry.quantity)
            } else {
                standalone.append(PendingEntry(
                    name: entry.displayName,
                    quantity: entry.quantity,
                    itemID: nil,
                    categoryID: category.id,
                    categoryOrder: category.order,
                    unitID: unit.id
                ))
            }
        }

        let pending = (Array(aggregated.values) + standalone).sorted {
            if $0.categoryOrder != $1.categoryOrder { return $0.categoryOrder < $1.categoryOrder }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        try replace(with: pending)
    }

    private func replace(with pending: [PendingEntry]) throws {
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
        guard quantity > 0, quantity.isFinite else { throw Error.invalidQuantity }
        guard let item = try context.fetch(Item.descriptor(id: itemID)).first else { throw Error.missingItem }
        guard let unit = try context.fetch(Unit.descriptor(id: unitID)).first else { throw Error.missingUnit }
        try insert(name: item.name, item: item, category: item.category, unit: unit, quantity: quantity)
    }

    func addNote(_ name: String, categoryID: UUID, unitID: UUID, quantity: Double) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw Error.emptyName }
        guard quantity > 0, quantity.isFinite else { throw Error.invalidQuantity }
        guard let category = try context.fetch(Category.descriptor(id: categoryID)).first else {
            throw Error.missingCategory
        }
        guard let unit = try context.fetch(Unit.descriptor(id: unitID)).first else { throw Error.missingUnit }
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
