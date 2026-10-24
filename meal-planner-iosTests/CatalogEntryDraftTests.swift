import Foundation
import Testing
@testable import meal_planner_ios

struct CatalogEntryDraftTests {
    private let itemID = UUID()
    private let categoryID = UUID()
    private let unitID = UUID()

    private var unit: UnitDefinition {
        UnitDefinition(id: unitID, name: "count", type: .count, base: 1, magnitudes: [])
    }

    @Test(arguments: CatalogEntryDraft.Kind.allCases, [0.0, -1, .infinity, -.infinity, .nan])
    func bothEntryKindsRejectInvalidQuantities(kind: CatalogEntryDraft.Kind, quantity: Double) {
        let draft = CatalogEntryDraft(kind: kind, itemID: itemID, note: "Candles",
                                      categoryID: categoryID, unitID: unitID, quantity: quantity)
        #expect(!draft.isValid(itemIDs: [itemID], categoryIDs: [categoryID], unit: unit))
    }

    @Test(arguments: CatalogEntryDraft.Kind.allCases)
    func bothEntryKindsRequireAnExistingValidUnit(kind: CatalogEntryDraft.Kind) {
        let draft = CatalogEntryDraft(kind: kind, itemID: itemID, note: "Candles",
                                      categoryID: categoryID, unitID: unitID, quantity: 0.5)
        #expect(draft.isValid(itemIDs: [itemID], categoryIDs: [categoryID], unit: unit))
        #expect(!draft.isValid(itemIDs: [itemID], categoryIDs: [categoryID], unit: nil))
        var invalidUnit = unit
        invalidUnit.base = 0
        #expect(!draft.isValid(itemIDs: [itemID], categoryIDs: [categoryID], unit: invalidUnit))
        invalidUnit = unit
        invalidUnit.id = UUID()
        #expect(!draft.isValid(itemIDs: [itemID], categoryIDs: [categoryID], unit: invalidUnit))
    }

    @Test func itemEntryRequiresAnItemButDoesNotRequireNoteFields() {
        let draft = CatalogEntryDraft(itemID: itemID, unitID: unitID)
        #expect(draft.isValid(itemIDs: [itemID], categoryIDs: [], unit: unit))
        #expect(!draft.isValid(itemIDs: [], categoryIDs: [], unit: unit))
    }

    @Test func noteRequiresTextAndCategoryButDoesNotRequireAnItem() {
        var draft = CatalogEntryDraft(kind: .note, note: "  Birthday candles  ",
                                      categoryID: categoryID, unitID: unitID)
        #expect(draft.isValid(itemIDs: [], categoryIDs: [categoryID], unit: unit))
        #expect(!draft.isValid(itemIDs: [], categoryIDs: [], unit: unit))
        draft.note = " \n "
        #expect(!draft.isValid(itemIDs: [], categoryIDs: [categoryID], unit: unit))
    }
}
