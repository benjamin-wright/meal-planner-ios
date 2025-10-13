//
//  RecipieIngredientEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 08/10/2025.
//

import SwiftUI
import SwiftData

struct RecipieIngredientEdit: View {
    @State var value: RecipieIngredient
    @State var ingredients: [Ingredient]
    @State var units: [Measure]
    var action: () -> Void
    
    var body: some View {
        Form {
            NavigationLink {
                IngredientPicker(
                    ingredients: ingredients,
                    selected: $value.ingredient
                )
            } label: {
                Text("Ingredient").badge(value.ingredient.name)
            }
            UnitPicker(
                label: "Unit",
                selected: $value.unit,
                units: units
            )
        }
    }
}

#Preview {
    struct Preview: View {
        @Query var ingredients: [Ingredient]
        @Query var units: [Measure]
        @Query var recipies: [Recipie]
        
        var body: some View {
            NavigationStack {
                RecipieIngredientEdit(
                    value: recipies[0].ingredients[0],
                    ingredients: ingredients,
                    units: units
                ) {
                    print("hi")
                }
            }
        }
    }
    
    return Preview().modelContainer(Models.testing.modelContainer)
}
