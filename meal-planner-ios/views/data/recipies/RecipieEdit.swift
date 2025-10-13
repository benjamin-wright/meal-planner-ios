//
//  RecipieEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 29/09/2025.
//

import SwiftUI
import SwiftData

struct RecipieEdit: View {
    @Environment(\.dismiss) var dismiss

    @State var edit: Bool
    @State var recipie: Recipie
    @State var existing: [Recipie]
    @State var units: [Measure]
    @State var ingredients: [Ingredient]
    @State var newIngredient: Bool = false

    var action: () -> Void
    @State private var editMode: EditMode = .inactive
    
    init(
        edit: Bool = false,
        recipie: Recipie,
        existing: [Recipie],
        units: [Measure],
        ingredients: [Ingredient],
        action: @escaping () -> Void
    ) {
        self.recipie = recipie
        self.existing = existing
        self.units = units
        self.ingredients = ingredients
        self.action = action
        self.edit = edit
    }
    
    var body: some View {
        Form {
            Section {
                TextInput(text: $recipie.name, label: "Name", placeholder: "recipie name")
            }
            
            Section("Details") {
                TextInput(text: $recipie.summary, label: "Summary", placeholder: "A basic description", multiline: true)
                IntegerInput(number: $recipie.serves, label: "Serves", placeholder: "number of portions")
                NumberInput(number: $recipie.time, label: "Time", placeholder: "time to cook (minutes)")
            }
            
            Section("Ingredients") {
                ForEach(recipie.ingredients) { ingredient in
                    Text(ingredient.ingredient.name)
                }.onDelete { offsets in
                    recipie.ingredients.remove(atOffsets: offsets)
                }
                NavigationLink(
                    value: RecipieIngredient(
                        ingredient: ingredients[0],
                        unit: units[0],
                        quantity: 1
                    ),
                    label: {
                        Text("Add")
                            .foregroundColor(.accent)
                    }
                )
            }
            
            Section("Steps") {
                AddButton {
                    
                }
            }
            
            Button {
                action()
                dismiss()
            } label: {
                Text(edit ? "Save" : "Add")
            }.disabled(editMode.isEditing || !recipie.isValid())
        }
        .toolbar {
            EditButton()
        }
        .environment(\.editMode, $editMode)
        .navigationDestination(for: RecipieIngredient.self) { item in
            RecipieIngredientEdit(
                value: item,
                ingredients: ingredients,
                units: units
            ) {
                print(item.ingredient.name)
            }
        }
        .navigationTitle("Recipie")
    }
}

#Preview {
    struct Preview: View {
        @Query private var ingredients: [Ingredient]
        @Query private var units: [Measure]
        var recipie: Recipie = Recipie(
            type: .dinner
        )
        
        var body: some View {
            NavigationStack {
                RecipieEdit(
                    recipie: recipie,
                    existing: [],
                    units: units,
                    ingredients: ingredients,
                    action: {
                        print(recipie.name)
                    }
                )
            }
        }
    }
    
    return Preview().modelContainer(Models.testing.modelContainer)
}
