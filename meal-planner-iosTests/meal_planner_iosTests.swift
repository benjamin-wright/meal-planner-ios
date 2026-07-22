//
//  meal_planner_iosTests.swift
//  meal-planner-iosTests
//
//  Created by Benjamin Wright on 09/09/2025.
//

import Testing
import SwiftData
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

}
