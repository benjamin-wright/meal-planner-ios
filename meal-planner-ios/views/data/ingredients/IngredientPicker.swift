//
//  IngredientPicker.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 07/10/2025.
//

import SwiftUI
import SwiftData

struct IngredientPicker: View {
    @Environment(\.dismiss) var dismiss
    
    @State var ingredients: [Ingredient]
    @Binding var selected: Ingredient
    @State var search: String = ""
    
    var body: some View {
        List {
            Picker("ingredient", selection: $selected) {
                ForEach(ingredients.filter {
                    search.count == 0 ||
                    $0.name.contains(search) ||
                    $0.category.name.contains(search)
                }) { ingredient in
                    Text(ingredient.name).tag(ingredient)
                }
            }.pickerStyle(.inline)
                .labelsHidden()
        }
        .searchable(text: $search)
        .onChange(of: search) {
            let lowercase = search.lowercased()
            if lowercase != search {
                search = lowercase
            }
        }.onChange(of: selected) {
            dismiss()
        }
        .navigationTitle("Ingredient")
    }
}

#Preview {
    struct Preview: View {
        @Query() private var ingredients: [Ingredient]
        @State private var selected: Ingredient
        
        init() {
            self._selected = State(initialValue: Ingredient(category: Category(name: "testing", order: 10)))
        }
        
        var body: some View {
            NavigationStack {
                IngredientPicker(
                    ingredients: ingredients,
                    selected: $selected
                )
            }
        }
    }
    
    return Preview().modelContainer(Models.testing.modelContainer)
}
