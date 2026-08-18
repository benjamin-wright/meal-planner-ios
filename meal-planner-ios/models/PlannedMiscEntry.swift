import Foundation
import SwiftData

@Model
final class PlannedMiscEntry {
    @Attribute(.unique)
    var id: UUID = UUID()
    var sortOrder: Int
    var note: String?
    @Relationship(deleteRule: .nullify)
    var item: Item?

    init(id: UUID = UUID(), item: Item? = nil, note: String? = nil, sortOrder: Int = 0) {
        self.id = id
        self.item = item
        self.note = note
        self.sortOrder = sortOrder
    }

    var displayName: String {
        item?.name ?? note ?? ""
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

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "This planner entry no longer exists."
            case .emptyNote:
                return "Enter a description for the miscellaneous entry."
            case .missingItem:
                return "The selected item no longer exists."
            }
        }
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func saveNote(_ note: String, id: UUID? = nil) throws {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else { throw Error.emptyNote }
        let entry = try entry(id: id)
        entry.item = nil
        entry.note = trimmedNote
        try context.save()
    }

    func saveItem(_ itemID: UUID, id: UUID? = nil) throws {
        guard let item = try context.fetch(Item.descriptor(id: itemID)).first else {
            throw Error.missingItem
        }
        let entry = try entry(id: id)
        entry.item = item
        entry.note = nil
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
