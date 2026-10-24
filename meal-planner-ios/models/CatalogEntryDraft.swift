import Foundation

/// The editable input shared by planned extras and direct shopping-list entries.
/// Where the entry is saved remains the responsibility of the calling flow.
struct CatalogEntryDraft {
    enum Kind: String, CaseIterable, Identifiable {
        case item, note
        var id: Self { self }
    }

    var kind: Kind = .item
    var itemID: UUID?
    var note = ""
    var categoryID: UUID?
    var unitID: UUID?
    var quantity = 1.0

    func isValid(itemIDs: Set<UUID>, categoryIDs: Set<UUID>, unit: UnitDefinition?) -> Bool {
        guard DomainValidation.isPositiveFinite(quantity),
              let unit, unit.id == unitID, unit.isValid else { return false }
        switch kind {
        case .item:
            return itemID.map(itemIDs.contains) == true
        case .note:
            return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && categoryID.map(categoryIDs.contains) == true
        }
    }

    func isValid(items: [Item], categories: [Category], units: [Unit]) -> Bool {
        isValid(itemIDs: Set(items.map(\.id)), categoryIDs: Set(categories.map(\.id)),
                unit: units.first { $0.id == unitID }?.definition)
    }
}
