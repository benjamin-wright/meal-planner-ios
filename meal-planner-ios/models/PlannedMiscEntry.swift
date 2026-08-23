import Foundation
import SwiftData

struct PlannedMiscNote {
    var text: String
    var category: Category
}

@Model
final class PlannedMiscEntry {
    @Attribute(.unique)
    var id: UUID = UUID()
    var sortOrder: Int
    var quantity: Double = 1
    @Attribute(originalName: "note")
    var noteText: String?
    @Relationship(deleteRule: .nullify)
    var item: Item?
    @Relationship(deleteRule: .nullify)
    var noteCategory: Category?
    @Relationship(deleteRule: .nullify)
    var unit: Unit?

    init(
        id: UUID = UUID(),
        item: Item? = nil,
        note: PlannedMiscNote? = nil,
        quantity: Double = 1,
        unit: Unit? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.item = item
        self.noteText = note?.text
        self.noteCategory = note?.category
        self.quantity = quantity
        self.unit = unit
        self.sortOrder = sortOrder
    }

    var note: PlannedMiscNote? {
        get {
            guard let noteText, let noteCategory else { return nil }
            return PlannedMiscNote(text: noteText, category: noteCategory)
        }
        set {
            noteText = newValue?.text
            noteCategory = newValue?.category
        }
    }

    var category: Category? {
        item?.category ?? noteCategory
    }

    var displayName: String {
        item?.name ?? noteText ?? ""
    }
}

extension PlannedMiscEntry {
    static func descriptor(id: UUID) -> FetchDescriptor<PlannedMiscEntry> {
        FetchDescriptor(predicate: #Predicate { $0.id == id })
    }
}

@MainActor
final class PlannedMiscStore {
    enum Error: LocalizedError {
        case notFound
        case emptyNote
        case missingItem
        case missingCategory
        case missingUnit
        case invalidQuantity

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "This planner entry no longer exists."
            case .emptyNote:
                return "Enter a description for the miscellaneous entry."
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

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func saveNote(
        _ note: String,
        categoryID: UUID,
        unitID: UUID,
        quantity: Double,
        id: UUID? = nil
    ) throws {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else { throw Error.emptyNote }
        guard quantity > 0 && quantity.isFinite else { throw Error.invalidQuantity }
        guard let category = try context.fetch(Category.descriptor(id: categoryID)).first else {
            throw Error.missingCategory
        }
        guard let unit = try context.fetch(Unit.descriptor(id: unitID)).first else {
            throw Error.missingUnit
        }
        let entry = try entry(id: id)
        entry.item = nil
        entry.note = PlannedMiscNote(text: trimmedNote, category: category)
        entry.quantity = quantity
        entry.unit = unit
        try context.save()
    }

    func saveItem(_ itemID: UUID, unitID: UUID, quantity: Double, id: UUID? = nil) throws {
        guard quantity > 0 && quantity.isFinite else { throw Error.invalidQuantity }
        guard let item = try context.fetch(Item.descriptor(id: itemID)).first else {
            throw Error.missingItem
        }
        guard let unit = try context.fetch(Unit.descriptor(id: unitID)).first else {
            throw Error.missingUnit
        }
        let entry = try entry(id: id)
        entry.item = item
        entry.note = nil
        entry.quantity = quantity
        entry.unit = unit
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let entry = try context.fetch(PlannedMiscEntry.descriptor(id: id)).first else {
            throw Error.notFound
        }
        context.delete(entry)
        try context.save()
    }

    private func entry(id: UUID?) throws -> PlannedMiscEntry {
        if let id {
            guard let entry = try context.fetch(PlannedMiscEntry.descriptor(id: id)).first else {
                throw Error.notFound
            }
            return entry
        }
        let sortOrder = (try context.fetch(FetchDescriptor<PlannedMiscEntry>()).map(\.sortOrder).max() ?? -1) + 1
        let entry = PlannedMiscEntry(sortOrder: sortOrder)
        context.insert(entry)
        return entry
    }
}
