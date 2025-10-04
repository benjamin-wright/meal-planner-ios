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
    
    private static func clear<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<T>())
        items.forEach { item in
            context.delete(item)
        }
    }
    
    static func reset(_ context: ModelContext) {
        do {
            try Models.clear(AppSettings.self, context)
            try Models.clear(CountUnit.self, context)
            try Models.clear(ContinuousUnit.self, context)
            try Models.clear(Category.self, context)
            try Models.clear(Ingredient.self, context)
            
            Models.initialiseData(context)
            try context.save()
        } catch {
            fatalError("Could not clear existing data: \(error)")
        }
        
    }

    private init(testing: Bool = false) {
        let schema = Schema([
            Category.self,
            CountUnit.self,
            ContinuousUnit.self,
            AppSettings.self,
            Ingredient.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: testing)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let settings = try modelContainer.mainContext.fetch(FetchDescriptor<AppSettings>())
            if settings.count < 1 {
                Models.initialiseData(context)
                try context.save()
            }
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    private static func initialiseData(_ context: ModelContext) {
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
        let settings = AppSettings(
            preferredVolume: litresUnit,
            preferredWeight: gramsUnit
        )

        context.insert(countUnit)
        context.insert(loavesUnit)
        context.insert(gramsUnit)
        context.insert(litresUnit)
        context.insert(settings)
        
        let drugCategory = Category(name: "drugs", order: 0)
        let fruitCategory = Category(name: "fruit", order: 1)
        let vegetableCategory = Category(name: "vegetables", order: 2)

        context.insert(drugCategory)
        context.insert(fruitCategory)
        context.insert(vegetableCategory)
        
        do {
            try context.save()
        } catch {
            
        }
        
        let carrots = Ingredient(name: "carrots", category: vegetableCategory)
        let onions = Ingredient(name: "onions", category: vegetableCategory)
        let apples = Ingredient(name: "apples", category: fruitCategory)
        
        context.insert(carrots)
        context.insert(onions)
        context.insert(apples)
    }
}
