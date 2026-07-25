//
//  meal_planner_iosTests.swift
//  meal-planner-iosTests
//
//  Created by Benjamin Wright on 09/09/2025.
//

import Testing
import SwiftData
import Foundation
@testable import meal_planner_ios

struct meal_planner_iosTests {

    @Test func unitDraftRequiresCompleteUnitDetails() {
        var draft = UnitDraft(type: .weight)
        #expect(!draft.isValid())

        draft.name = "grams"
        draft.magnitudes = [
            Magnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1)
        ]
        #expect(draft.isValid())

        draft.magnitudes[0].multiplier = 0
        #expect(!draft.isValid())
    }

    @Test func unitCanBeFetchedByItsNavigationIdentifier() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Unit.self, configurations: configuration)
        let context = ModelContext(container)
        let unit = Unit(
            name: "grams",
            type: .weight,
            magnitudes: [Magnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1)]
        )

        context.insert(unit)
        try context.save()

        let fetched = try context.fetch(Unit.descriptor(id: unit.id)).first
        #expect(fetched?.id == unit.id)
    }

    @MainActor
    @Test func recipieStoreCreatesUpdatesAndRemovesIngredients() throws {
        let context = try makeRecipieContext()
        let category = Category(name: "vegetables", order: 0)
        let item = Item(name: "carrots", category: category, kind: .ingredient)
        let unit = Unit(name: "grams", type: .weight, magnitudes: [
            Magnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1)
        ])
        context.insert(category)
        context.insert(item)
        context.insert(unit)
        try context.save()

        let ingredientID = UUID()
        var draft = RecipieDraft(type: .dinner)
        draft.name = "Carrot soup"
        draft.ingredients = [
            RecipieIngredientDraft(id: ingredientID, itemID: item.id, unitID: unit.id, quantity: 100)
        ]

        let store = RecipieStore(context: context)
        try store.save(draft, id: nil)

        let recipie = try #require(context.fetch(FetchDescriptor<Recipie>()).first)
        #expect(recipie.ingredients.count == 1)
        #expect(recipie.ingredients[0].id == ingredientID)

        draft.ingredients[0].quantity = 250
        try store.save(draft, id: recipie.id)
        #expect(recipie.ingredients.count == 1)
        #expect(recipie.ingredients[0].quantity == 250)

        draft.ingredients = []
        try store.save(draft, id: recipie.id)
        #expect(recipie.ingredients.isEmpty)
        #expect(try context.fetch(FetchDescriptor<RecipieIngredient>()).isEmpty)
    }

    @MainActor
    @Test func recipieStoreRejectsMissingIngredientReferences() throws {
        let context = try makeRecipieContext()
        var draft = RecipieDraft(type: .dinner)
        draft.name = "Missing item soup"
        draft.ingredients = [
            RecipieIngredientDraft(itemID: UUID(), unitID: UUID(), quantity: 1)
        ]

        do {
            try RecipieStore(context: context).save(draft, id: nil)
            Issue.record("Saving with missing ingredient references should fail.")
        } catch let error as RecipieStore.Error {
            guard case .missingIngredientReference = error else {
                Issue.record("Expected a missing ingredient reference error, got \(error).")
                return
            }
        }

        #expect(try context.fetch(FetchDescriptor<Recipie>()).isEmpty)
    }

    private func makeRecipieContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Category.self,
            Unit.self,
            Item.self,
            RecipieIngredient.self,
            Recipie.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

}
