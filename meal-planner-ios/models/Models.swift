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
            try Models.clear(Meal.self, context)
            try Models.clear(Recipie.self, context)
            try Models.clear(Item.self, context)
            try Models.clear(Category.self, context)
            try Models.clear(AppSettings.self, context)
            try Models.clear(Unit.self, context)
            
            Models.initialiseData(context)
            try context.save()
        } catch {
            fatalError("Could not clear existing data: \(error)")
        }
    }

    private init(testing: Bool = false) {
        let schema = Schema([
            Category.self,
            Unit.self,
            AppSettings.self,
            Item.self,
            Recipie.self,
            Meal.self,
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
        let countUnit = Unit(name: "count", type: .count, magnitudes: [])
        let loavesUnit = Unit(name: "loaves", type: .count, magnitudes: [
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
        let gramsUnit = Unit(
            name: "grams",
            type: .weight,
            base: 1,
            magnitudes: [
                Magnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1),
                Magnitude(abbreviation: "kg", singular: "kilogram", plural: "kilograms", multiplier: 1000),
            ]
        )
        let litresUnit = Unit(
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
        let precookedCategory = Category(name: "precooked", order: 4)

        context.insert(drugCategory)
        context.insert(fruitCategory)
        context.insert(vegetableCategory)
        context.insert(dairyCategory)
        context.insert(precookedCategory)
        
        try? context.save()
        
        let carrots = Item(name: "carrots", category: vegetableCategory, kind: .ingredient)
        let onions = Item(name: "onions", category: vegetableCategory, kind: .ingredient)
        let apples = Item(name: "apples", category: fruitCategory, kind: .ingredient)
        let milk = Item(name: "milk", category: dairyCategory, kind: .ingredient)
        let paracetamol = Item(name: "paracetamol", category: drugCategory, kind: .misc)
        let pastaPot = Item(name: "pasta pot", category: precookedCategory, kind: .readymeal, readymealData: ReadymealData(
            mealType: MealType.dinner.rawValue, course: CourseType.main.rawValue, serves: 1, time: 5
        ))
        
        context.insert(carrots)
        context.insert(onions)
        context.insert(apples)
        context.insert(milk)
        context.insert(paracetamol)
        context.insert(pastaPot)
        
        try? context.save()
        
        let soup = Recipie(
            name: "soup",
            mealType: .dinner,
            course: .main,
            summary: "A tasty soup",
            ingredients: [
                RecipieIngredient(
                    item: carrots,
                    unit: countUnit,
                    quantity: 1
                ),
                RecipieIngredient(
                    item: onions,
                    unit: gramsUnit,
                    quantity: 80
                ),
                RecipieIngredient(
                    item: apples,
                    unit: loavesUnit,
                    quantity: 2
                ),
                RecipieIngredient(
                    item: milk,
                    unit: litresUnit,
                    quantity: 1
                )
            ]
        )
        context.insert(soup)
        
        try? context.save()
    }
}
