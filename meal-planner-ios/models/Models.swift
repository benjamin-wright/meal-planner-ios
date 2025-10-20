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
        try context.save()
    }
    
    static func reset(_ context: ModelContext) {
        do {
            try Models.clear(Recipie.self, context)
            try Models.clear(Ingredient.self, context)
            try Models.clear(Category.self, context)
            try Models.clear(AppSettings.self, context)
            try Models.clear(Measure.self, context)
            
            Models.initialiseData(context)
            try context.save()
        } catch {
            fatalError("Could not clear existing data: \(error)")
        }
    }

    private init(testing: Bool = false) {
        let schema = Schema([
            Category.self,
            Measure.self,
            AppSettings.self,
            Ingredient.self,
            Recipie.self,
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
        let countUnit = Measure(name: "count", type: .count, magnitudes: [])
        let loavesUnit = Measure(name: "loaves", type: .count, magnitudes: [
            Magnitude(
                singular: "slice",
                plural: "slices",
                multiplier: 0.1
            ),
            Magnitude(
                singular: "loaf",
                plural: "loaves",
                multiplier: 1
            )
        ])
        let gramsUnit = Measure(
            name: "grams",
            type: .weight,
            base: 1,
            magnitudes: [
                Magnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1),
                Magnitude(abbreviation: "kg", singular: "kilogram", plural: "kilograms", multiplier: 1000),
            ]
        )
        let litresUnit = Measure(
            name: "litres",
            type: .volume,
            base: 1,
            magnitudes: [
                Magnitude(abbreviation: "ml", singular: "millilitre", plural: "millilitres", multiplier: 0.001),
                Magnitude(abbreviation: "l", singular: "litre", plural: "litres", multiplier: 1),
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
        let dairyCategory = Category(name: "dairy", order: 3)

        context.insert(drugCategory)
        context.insert(fruitCategory)
        context.insert(vegetableCategory)
        context.insert(dairyCategory)
        
        try? context.save()
        
        let carrots = Ingredient(name: "carrots", category: vegetableCategory)
        let onions = Ingredient(name: "onions", category: vegetableCategory)
        let damsons = Ingredient(name: "damsons", category: fruitCategory)
        let apples = Ingredient(name: "apples", category: fruitCategory)
        let milk = Ingredient(name: "milk", category: dairyCategory)
        
        context.insert(carrots)
        context.insert(onions)
        context.insert(damsons)
        context.insert(apples)
        context.insert(milk)
        
        try? context.save()
        
        let soup = Recipie(
            name: "soup",
            type: .dinner,
            summary: "A tasty soup",
            ingredients: [
                RecipieIngredient(
                    ingredient: carrots,
                    unit: countUnit,
                    quantity: 1
                ),
                RecipieIngredient(
                    ingredient: onions,
                    unit: gramsUnit,
                    quantity: 80
                ),
                RecipieIngredient(
                    ingredient: apples,
                    unit: loavesUnit,
                    quantity: 2
                ),
                RecipieIngredient(
                    ingredient: milk,
                    unit: litresUnit,
                    quantity: 1
                )
            ]
        )
        context.insert(soup)
        
        try? context.save()
    }
}
