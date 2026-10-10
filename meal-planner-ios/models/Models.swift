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
            try Models.clear(ShoppingListEntry.self, context)
            try Models.clear(PlannedMiscEntry.self, context)
            try Models.clear(PlannedMeal.self, context)
            try Models.clear(Meal.self, context)
            try Models.clear(MealComponent.self, context)
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
            MealComponent.self,
            Meal.self,
            PlannedMeal.self,
            PlannedMiscEntry.self,
            ShoppingListEntry.self,
        ])
        let modelConfiguration = ModelConfiguration("MealPlanner", schema: schema, isStoredInMemoryOnly: testing)

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
        
        let fruitCategory = Category(name: "fruit", order: 0)
        let vegetableCategory = Category(name: "vegetables", order: 1)
        let spicesCategory = Category(name: "spices", order: 2)
        let dairyCategory = Category(name: "dairy", order: 3)
        let bakeryCategory = Category(name: "bakery", order: 4)
        let seafoodCategory = Category(name: "seafood", order: 5)
        let precookedCategory = Category(name: "precooked", order: 6)
        let householdCategory = Category(name: "household", order: 7)
        let drugCategory = Category(name: "drugs", order: 8)

        context.insert(fruitCategory)
        context.insert(vegetableCategory)
        context.insert(spicesCategory)
        context.insert(dairyCategory)
        context.insert(bakeryCategory)
        context.insert(seafoodCategory)
        context.insert(precookedCategory)
        context.insert(householdCategory)
        context.insert(drugCategory)
        
        try? context.save()
        
        let carrots = Item(name: "carrots", category: vegetableCategory, kind: .ingredient)
        let onions = Item(name: "onions", category: vegetableCategory, kind: .ingredient)
        let apples = Item(name: "apples", category: fruitCategory, kind: .ingredient)
        let milk = Item(name: "milk", category: dairyCategory, kind: .ingredient, dietary: [.dairy])
        let potatoes = Item(name: "potatoes", category: vegetableCategory, kind: .ingredient)
        let chickenThighs = Item(name: "chicken thighs", category: precookedCategory, kind: .ingredient, dietary: [.meat])
        let rosemary = Item(name: "rosemary", category: spicesCategory, kind: .ingredient)
        let flour = Item(name: "flour", category: bakeryCategory, kind: .ingredient, dietary: [.gluten])
        let salmon = Item(name: "salmon fillets", category: seafoodCategory, kind: .ingredient, dietary: [.fish])
        let paracetamol = Item(name: "paracetamol", category: drugCategory, kind: .misc)
        let dishwasherTablets = Item(name: "dishwasher tablets", category: householdCategory, kind: .misc)
        let pastaPot = Item(name: "pasta pot", category: precookedCategory, kind: .readymeal, readymealData: ReadymealData(
            serves: 1, time: 5
        ))
        let fruitPot = Item(
            name: "fruit pot",
            category: precookedCategory,
            kind: .readymeal,
            readymealData: ReadymealData(
                serves: 1,
                time: 0
            )
        )
        
        context.insert(carrots)
        context.insert(onions)
        context.insert(apples)
        context.insert(milk)
        context.insert(potatoes)
        context.insert(chickenThighs)
        context.insert(rosemary)
        context.insert(flour)
        context.insert(salmon)
        context.insert(paracetamol)
        context.insert(dishwasherTablets)
        context.insert(pastaPot)
        context.insert(fruitPot)
        
        try? context.save()
        
        let carrotSoup = Recipie(
            name: "carrot soup",
            summary: "A warming carrot and rosemary soup",
            serves: 4,
            time: 35,
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
                    item: rosemary,
                    unit: gramsUnit,
                    quantity: 5
                )
            ],
            steps: ["Chop the vegetables.", "Simmer until tender, then blend."]
        )
        let roastChicken = Recipie(
            name: "roast chicken",
            summary: "Rosemary roast chicken",
            serves: 4,
            time: 60,
            ingredients: [
                RecipieIngredient(
                    item: chickenThighs,
                    unit: countUnit,
                    quantity: 2
                ),
                RecipieIngredient(
                    item: rosemary,
                    unit: gramsUnit,
                    quantity: 5
                ),
            ],
            steps: ["Season the chicken with rosemary.", "Roast until cooked through."]
        )
        let mashedPotatoes = Recipie(
            name: "mashed potatoes",
            summary: "Creamy mashed potatoes",
            serves: 4,
            time: 25,
            ingredients: [
                RecipieIngredient(
                    item: potatoes,
                    unit: gramsUnit,
                    quantity: 200
                ),
                RecipieIngredient(
                    item: milk,
                    unit: litresUnit,
                    quantity: 0.1
                )
            ],
            steps: ["Boil the potatoes.", "Mash with the milk."]
        )
        let salmonSalad = Recipie(
            name: "salmon salad",
            summary: "A light salmon and apple salad",
            serves: 2,
            time: 20,
            ingredients: [
                RecipieIngredient(item: salmon, unit: countUnit, quantity: 2),
                RecipieIngredient(item: apples, unit: countUnit, quantity: 1),
            ],
            steps: ["Cook the salmon.", "Flake over the sliced apple salad."]
        )
        let breakfastLoaf = Recipie(
            name: "breakfast loaf",
            summary: "A simple apple breakfast loaf",
            serves: 6,
            time: 45,
            ingredients: [
                RecipieIngredient(item: apples, unit: countUnit, quantity: 2),
                RecipieIngredient(item: flour, unit: gramsUnit, quantity: 250),
                RecipieIngredient(item: milk, unit: litresUnit, quantity: 0.2),
            ],
            steps: ["Mix the ingredients.", "Bake until golden."]
        )
        let appleCrumble = Recipie(
            name: "apple crumble",
            summary: "Baked apples with a crisp topping",
            serves: 4,
            time: 40,
            ingredients: [
                RecipieIngredient(item: apples, unit: countUnit, quantity: 4),
                RecipieIngredient(item: flour, unit: gramsUnit, quantity: 150),
            ],
            steps: ["Top the sliced apples with crumble.", "Bake until crisp."]
        )
        
        context.insert(carrotSoup)
        context.insert(roastChicken)
        context.insert(mashedPotatoes)
        context.insert(salmonSalad)
        context.insert(breakfastLoaf)
        context.insert(appleCrumble)
        
        let roastChickenMeal = Meal(
            name: "Roast Chicken Dinner",
            mealType: .dinner,
            components: [
                MealComponent(recipe: roastChicken, course: .main),
                MealComponent(recipe: mashedPotatoes, course: .side),
                MealComponent(recipe: appleCrumble, course: .dessert),
            ]
        )
        let salmonLunch = Meal(
            name: "Salmon Lunch",
            mealType: .lunch,
            components: [MealComponent(recipe: salmonSalad, course: .main)]
        )
        let breakfast = Meal(
            name: "Breakfast",
            mealType: .breakfast,
            components: [
                MealComponent(recipe: breakfastLoaf, course: .main),
                MealComponent(readymeal: fruitPot, course: .side),
            ]
        )
        let quickDinner = Meal(
            name: "Quick Dinner",
            mealType: .dinner,
            components: [MealComponent(readymeal: pastaPot, course: .main)]
        )
        
        context.insert(roastChickenMeal)
        context.insert(salmonLunch)
        context.insert(breakfast)
        context.insert(quickDinner)

        let plannedBreakfast = PlannedMeal(
            mealType: .breakfast,
            sortOrder: 0,
            sourceMealID: breakfast.id,
            servings: 2,
            components: breakfast.orderedComponents.map { MealComponent(copying: $0) }
        )
        let plannedLunch = PlannedMeal(
            mealType: .lunch,
            sortOrder: 0,
            sourceMealID: salmonLunch.id,
            servings: 2,
            components: salmonLunch.orderedComponents.map { MealComponent(copying: $0) }
        )
        let saturdayDinner = PlannedMeal(
            mealType: .dinner,
            day: .saturday,
            sourceMealID: roastChickenMeal.id,
            servings: 4,
            components: roastChickenMeal.orderedComponents.map { MealComponent(copying: $0) }
        )
        let sundayDinner = PlannedMeal(
            mealType: .dinner,
            day: .sunday,
            sourceMealID: quickDinner.id,
            servings: 2,
            components: quickDinner.orderedComponents.map { MealComponent(copying: $0) }
        )

        context.insert(plannedBreakfast)
        context.insert(plannedLunch)
        context.insert(saturdayDinner)
        context.insert(sundayDinner)
        context.insert(PlannedMiscEntry(
            item: dishwasherTablets,
            quantity: 1,
            unit: countUnit,
            sortOrder: 0
        ))
        context.insert(PlannedMiscEntry(
            note: PlannedMiscNote(text: "birthday candles", category: householdCategory),
            quantity: 12,
            unit: countUnit,
            sortOrder: 1
        ))
        
        try? context.save()
        try? ShoppingListStore(context: context).regenerate()
    }
}
