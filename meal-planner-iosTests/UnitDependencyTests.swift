import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct UnitDependencyTests {
    @Test func referencedUnitsAllowTypeAndBaseCorrections() throws {
        for reference in UnitReference.allCases {
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
        }
    }

    @Test func referencedUnitsAllowNameAndMagnitudeFormattingChanges() throws {
        for reference in UnitReference.allCases {
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
    }

    @Test func deletingReferencedUnitsRejectsTheWholeSelection() throws {
        for reference in UnitReference.allCases {
            let fixture = try makeFixture(reference: reference)
            let context = fixture.context
            let unused = meal_planner_ios.Unit(name: "Unused count", type: .count, magnitudes: [])
            context.insert(unused)
            try context.save()

            do {
                try UnitStore(context: context).delete(ids: [unused.id, fixture.unit.id])
                Issue.record("A unit with a required reference should not delete.")
            } catch let error as UnitStore.Error {
                guard case .inUse(let name) = error else {
                    Issue.record("Expected an in-use error, got \(error).")
                    continue
                }
                #expect(name == fixture.unit.name)
            }

            #expect(!context.hasChanges)
            #expect(try context.fetch(meal_planner_ios.Unit.descriptor(id: unused.id)).count == 1)
            let verification = ModelContext(context.container)
            #expect(try verification.fetch(meal_planner_ios.Unit.descriptor(id: unused.id)).count == 1)
            #expect(try verification.fetch(meal_planner_ios.Unit.descriptor(id: fixture.unit.id)).count == 1)
        }
    }

    @Test func unreferencedUnitsCanChangeConversionAndBeDeleted() throws {
        let context = try makeContext()
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

    private func makeFixture(reference: UnitReference) throws -> Fixture {
        let context = try makeContext()
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

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: meal_planner_ios.Category.self, meal_planner_ios.Unit.self, AppSettings.self, Item.self,
            RecipieIngredient.self, Recipie.self, MealComponent.self, Meal.self,
            PlannedMeal.self, PlannedMiscEntry.self, ShoppingListEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private struct Fixture {
        let context: ModelContext
        let unit: meal_planner_ios.Unit
    }
}
