import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct UnitDependencyTests {
    @Test(arguments: UnitReference.allCases)
    func referencedUnitsAllowTypeAndBaseCorrections(reference: UnitReference) throws {
        let fixture = try makeFixture(reference: reference)
        let context = fixture.context
        let store = UnitStore(context: context)
        var draft = UnitDraft(unit: fixture.unit)
        draft.name = "Corrected unit"
        draft.type = draft.type == .weight ? .volume : .weight
        draft.base = 2

        try store.save(draft, id: fixture.unit.id)

        let verification = ModelContext(context.container)
        let persisted = try #require(verification.fetch(
            meal_planner_ios.Unit.descriptor(id: fixture.unit.id)
        ).first)
        #expect(persisted.name == draft.name)
        #expect(persisted.unitType == draft.type)
        #expect(persisted.base == draft.base)
        #expect(try verification.fetch(FetchDescriptor<RecipieIngredient>()).allSatisfy { $0.quantity == 3 })
        #expect(try verification.fetch(FetchDescriptor<MealComponent>()).allSatisfy { $0.quantity == 3 })
        #expect(try verification.fetch(FetchDescriptor<PlannedMiscEntry>()).allSatisfy { $0.quantity == 3 })
        #expect(try verification.fetch(FetchDescriptor<ShoppingListEntry>()).allSatisfy { $0.quantity == 3 })
        for settings in try verification.fetch(FetchDescriptor<AppSettings>()) {
            #expect(settings.preferredWeight.unitType == .weight)
            #expect(settings.preferredVolume.unitType == .volume)
        }
    }

    @Test(arguments: UnitReference.allCases)
    func referencedUnitsAllowNameAndMagnitudeFormattingChanges(reference: UnitReference) throws {
        let fixture = try makeFixture(reference: reference)
        var draft = UnitDraft(unit: fixture.unit)
        let originalType = draft.type
        let originalBase = draft.base
        draft.name = "Updated unit"
        draft.magnitudes[0].abbreviation = "updated"
        draft.magnitudes[0].singular = "updated unit"
        draft.magnitudes[0].plural = "updated units"
        draft.magnitudes[0].multiplier = 1_000

        try UnitStore(context: fixture.context).save(draft, id: fixture.unit.id)

        let persisted = try #require(ModelContext(fixture.context.container).fetch(
            meal_planner_ios.Unit.descriptor(id: fixture.unit.id)
        ).first)
        #expect(persisted.name == draft.name)
        #expect(persisted.magnitudes == draft.magnitudes)
        #expect(persisted.unitType == originalType)
        #expect(persisted.base == originalBase)
    }

    @Test(arguments: UnitReference.allCases)
    func deletingReferencedUnitsRejectsTheWholeSelection(reference: UnitReference) throws {
        let fixture = try makeFixture(reference: reference)
        let context = fixture.context
        let unused = meal_planner_ios.Unit(name: "Unused count", type: .count, magnitudes: [])
        context.insert(unused)
        try context.save()

        #expect {
            try UnitStore(context: context).delete(ids: [unused.id, fixture.unit.id])
        } throws: { error in
            guard let error = error as? UnitStore.Error,
                  case .inUse(let name) = error else { return false }
            return name == fixture.unit.name
        }

        #expect(!context.hasChanges)
        #expect(try context.fetch(meal_planner_ios.Unit.descriptor(id: unused.id)).count == 1)
        let verification = ModelContext(context.container)
        #expect(try verification.fetch(meal_planner_ios.Unit.descriptor(id: unused.id)).count == 1)
        #expect(try verification.fetch(meal_planner_ios.Unit.descriptor(id: fixture.unit.id)).count == 1)
    }

    @Test func unreferencedUnitsCanChangeConversionAndBeDeleted() throws {
        let context = try makeTestContext()
        let unit = meal_planner_ios.Unit(name: "Custom weight", type: .weight, magnitudes: [
            Magnitude(abbreviation: "w", singular: "weight", plural: "weights", multiplier: 1)
        ])
        context.insert(unit)
        try context.save()
        var draft = UnitDraft(unit: unit)
        draft.type = .volume
        draft.base = 2
        let store = UnitStore(context: context)

        try store.save(draft, id: unit.id)
        let persisted = try #require(ModelContext(context.container).fetch(
            meal_planner_ios.Unit.descriptor(id: unit.id)
        ).first)
        #expect(persisted.unitType == .volume)
        #expect(persisted.base == 2)

        try store.delete(ids: [unit.id])
        #expect(try ModelContext(context.container).fetch(
            meal_planner_ios.Unit.descriptor(id: unit.id)
        ).isEmpty)
    }

    @Test(arguments: [UnitReference.preferredWeight, .preferredVolume])
    func aPreferredDimensionChangeRequiresAReplacementBeforeMutation(reference: UnitReference) throws {
        let fixture = try makeFixture(reference: reference, includePreferredReplacement: false)
        var draft = UnitDraft(unit: fixture.unit)
        draft.name = "Must not be saved"
        draft.type = fixture.unit.unitType == .weight ? .volume : .weight
        #expect(throws: UnitStore.Error.self) {
            try UnitStore(context: fixture.context).save(draft, id: fixture.unit.id)
        }
        #expect(fixture.unit.name == "Custom unit")
        #expect(!fixture.context.hasChanges)
        let settings = try #require(fixture.context.fetch(FetchDescriptor<AppSettings>()).first)
        #expect(settings.preferredWeight.unitType == .weight)
        #expect(settings.preferredVolume.unitType == .volume)
    }

    @Test(arguments: [UnitReference.preferredWeight, .preferredVolume])
    func aPreferredDimensionChangeLeavesShoppingConversionUsable(reference: UnitReference) throws {
        let fixture = try makeFixture(reference: reference)
        let context = fixture.context
        let originalType = fixture.unit.unitType
        let backup = try #require(context.fetch(FetchDescriptor<meal_planner_ios.Unit>()).first {
            $0.id != fixture.unit.id && $0.unitType == originalType
        })
        let item = try #require(context.fetch(FetchDescriptor<Item>()).first)
        context.insert(PlannedMiscEntry(item: item, quantity: 3, unit: fixture.unit))
        context.insert(PlannedMiscEntry(item: item, quantity: 7, unit: backup))
        try context.save()

        var draft = UnitDraft(unit: fixture.unit)
        draft.type = originalType == .weight ? .volume : .weight
        draft.base = 2
        try UnitStore(context: context).save(draft, id: fixture.unit.id)
        try ShoppingListStore(context: context).regenerate()

        let persisted = ModelContext(context.container)
        let entries = try persisted.fetch(FetchDescriptor<ShoppingListEntry>())
        #expect(entries.count == 2)
        #expect(entries.first { $0.unit?.unitType == originalType }?.quantity == 7)
        #expect(entries.first { $0.unit?.unitType == draft.type }?.quantity == 6)
    }

    enum UnitReference: CaseIterable {
        case preferredWeight
        case preferredVolume
        case recipeIngredient
        case savedMealPortion
        case plannedMealPortion
        case miscellaneousItem
        case miscellaneousNote
        case shoppingEntry
    }

    private func makeFixture(reference: UnitReference, includePreferredReplacement: Bool = true) throws -> Fixture {
        let context = try makeTestContext()
        let category = meal_planner_ios.Category(name: "Produce", order: 0)
        let item = Item(name: "Apple", category: category, kind: .ingredient)
        let type: UnitType = reference == .preferredVolume ? .volume : .weight
        let unit = meal_planner_ios.Unit(name: "Custom unit", type: type, magnitudes: [
            Magnitude(abbreviation: "u", singular: "unit", plural: "units", multiplier: 1)
        ])
        context.insert(category)
        context.insert(item)
        context.insert(unit)

        switch reference {
        case .preferredWeight, .preferredVolume:
            let otherType: UnitType = type == .weight ? .volume : .weight
            let other = meal_planner_ios.Unit(name: "Other unit", type: otherType, magnitudes: [
                Magnitude(abbreviation: "o", singular: "other", plural: "others", multiplier: 1)
            ])
            context.insert(other)
            if includePreferredReplacement {
                context.insert(meal_planner_ios.Unit(name: "Replacement unit", type: type, magnitudes: [
                    Magnitude(abbreviation: "r", singular: "replacement", plural: "replacements", multiplier: 1)
                ]))
            }
            context.insert(AppSettings(
                preferredVolume: type == .volume ? unit : other,
                preferredWeight: type == .weight ? unit : other
            ))
        case .recipeIngredient:
            let ingredient = RecipieIngredient(item: item, unit: unit, quantity: 3)
            context.insert(Recipie(name: "Apple dish", ingredients: [ingredient]))
        case .savedMealPortion:
            let portion = MealComponent(ingredient: item, unit: unit, quantity: 3)
            context.insert(Meal(name: "Apple meal", mealType: .lunch, components: [portion]))
        case .plannedMealPortion:
            let portion = MealComponent(ingredient: item, unit: unit, quantity: 3)
            context.insert(PlannedMeal(mealType: .lunch, components: [portion]))
        case .miscellaneousItem:
            context.insert(PlannedMiscEntry(item: item, quantity: 3, unit: unit))
        case .miscellaneousNote:
            context.insert(PlannedMiscEntry(
                note: PlannedMiscNote(text: "Fruit for snacks", category: category), quantity: 3, unit: unit
            ))
        case .shoppingEntry:
            context.insert(ShoppingListEntry(name: "Apples", quantity: 3, item: item, category: category, unit: unit))
        }
        try context.save()
        return Fixture(context: context, unit: unit)
    }

    private struct Fixture {
        let context: ModelContext
        let unit: meal_planner_ios.Unit
    }
}
