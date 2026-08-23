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
        var item: Item?
        var category: Category
        var unit: Unit
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func regenerate() throws {
        guard let settings = try context.fetch(FetchDescriptor<AppSettings>()).first else {
            throw Error.missingSettings
        }

        let units = try context.fetch(FetchDescriptor<Unit>())
        let countUnit = units.first { $0.unitType == .count && $0.magnitudes.isEmpty }
            ?? units.first { $0.unitType == .count }
        let meals = try context.fetch(FetchDescriptor<PlannedMeal>())
        let miscEntries = try context.fetch(FetchDescriptor<PlannedMiscEntry>())
        var aggregated: [AggregationKey: PendingEntry] = [:]
        var standalone: [PendingEntry] = []

        func add(item: Item, unit sourceUnit: Unit, quantity: Double) throws {
            guard quantity > 0, quantity.isFinite else { return }

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

            let key = AggregationKey(
                itemID: item.id,
                unitType: sourceUnit.unitType,
                countUnitID: sourceUnit.unitType == .count ? sourceUnit.id : nil
            )
            if aggregated[key] != nil {
                aggregated[key]!.quantity += outputQuantity
            } else {
                aggregated[key] = PendingEntry(
                    name: item.name,
                    quantity: outputQuantity,
                    item: item,
                    category: item.category,
                    unit: outputUnit
                )
            }
        }

        for meal in meals {
            for recipie in meal.recipies {
                guard recipie.serves > 0 else { throw Error.invalidRecipe(recipie.name) }
                let scale = Double(meal.servings) / Double(recipie.serves)
                for ingredient in recipie.ingredients {
                    try add(
                        item: ingredient.item,
                        unit: ingredient.unit,
                        quantity: ingredient.quantity * scale
                    )
                }
            }

            for readymeal in meal.readymeals {
                guard let countUnit else { throw Error.missingCountUnit }
                let serves = max(readymeal.readymealData?.serves ?? 1, 1)
                let quantity = ceil(Double(meal.servings) / Double(serves))
                try add(item: readymeal, unit: countUnit, quantity: quantity)
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
                    item: nil,
                    category: category,
                    unit: unit
                ))
            }
        }

        let pending = (Array(aggregated.values) + standalone).sorted {
            if $0.category.order != $1.category.order { return $0.category.order < $1.category.order }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        try context.fetch(FetchDescriptor<ShoppingListEntry>()).forEach(context.delete)
        for (sortOrder, value) in pending.enumerated() {
            context.insert(ShoppingListEntry(
                name: value.name,
                quantity: value.quantity,
                sortOrder: sortOrder,
                item: value.item,
                category: value.category,
                unit: value.unit
            ))
        }
        try context.save()
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
