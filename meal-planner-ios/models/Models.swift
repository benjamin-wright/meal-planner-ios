//
//  SampleData.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 19/09/2025.
//

import Foundation
import SwiftData

@MainActor
class Models {
    static let shared = Models()
    static let testing = Models(testing: true)
    
    let modelContainer: ModelContainer
    
    var context: ModelContext {
        modelContainer.mainContext
    }

    private init(testing: Bool = false) {
        let schema = Schema([
            Category.self,
            CountUnit.self,
            ContinuousUnit.self,
            Settings.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: testing)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let settings = try modelContainer.mainContext.fetch(FetchDescriptor<Settings>())
            
            if settings.count != 1 {
                initialiseData()
                try context.save()
            }
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    private func initialiseData() {
        let drugCategory = Category(name: "drugs", order: 0)
        let fruitCategory = Category(name: "fruit", order: 1)
        let vegetableCategory = Category(name: "vegetables", order: 2)
        let countUnit = CountUnit(name: "count", collectives: [])
        let loavesUnit = CountUnit(name: "loaves", collectives: [
            CountUnitCollective(
                singular: "slice",
                plural: "slices",
                multiplier: 0.1
            ),
            CountUnitCollective(
                singular: "loaf",
                plural: "loaves",
                multiplier: 1
            )
        ])
        let gramsUnit = ContinuousUnit(
            name: "grams",
            type: .weight,
            base: 1,
            magnitudes: [
                ContinuousUnitMagnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1),
                ContinuousUnitMagnitude(abbreviation: "kg", singular: "kilogram", plural: "kilograms", multiplier: 1000),
            ]
        )
        let litresUnit = ContinuousUnit(
            name: "litres",
            type: .volume,
            base: 1,
            magnitudes: [
                ContinuousUnitMagnitude(abbreviation: "ml", singular: "millilitre", plural: "millilitres", multiplier: 0.001),
                ContinuousUnitMagnitude(abbreviation: "l", singular: "litre", plural: "litres", multiplier: 1),
            ]
        )
        let settings = Settings(
            preferredVolume: litresUnit,
            preferredWeight: gramsUnit
        )

        context.insert(drugCategory)
        context.insert(fruitCategory)
        context.insert(vegetableCategory)
        context.insert(countUnit)
        context.insert(loavesUnit)
        context.insert(gramsUnit)
        context.insert(litresUnit)
        context.insert(settings)
    }
}
