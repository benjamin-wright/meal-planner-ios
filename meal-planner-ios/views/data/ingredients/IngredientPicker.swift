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
    
    var action: (Ingredient) -> Void
    @State var ingredients: [Ingredient]
    @State var selected: Ingredient?
    @State var search: String = ""
    
    init(
        ingredients: [Ingredient],
        selected: Ingredient? = .none,
        _ action: @escaping (Ingredient) -> Void
    ) {
        self.action = action
        self.ingredients = ingredients
        self._selected = State(initialValue: selected)
    }
    
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
            switch selected {
            case .some(let ingredient):
                action(ingredient)
                dismiss()
            case .none:
                break
            }
        }.navigationTitle("Ingredient")
    }
}

#Preview {
    struct Preview: View {
        @Query() private var ingredients: [Ingredient]
        @State var selected: Ingredient? = .none
        
        var body: some View {
            NavigationStack {
                IngredientPicker(
                    ingredients: ingredients,
                    selected: ingredients[0]
                ) { selected in
                    print("doing \(selected.name)")
                }
            }
        }
    }
    
    return Preview().modelContainer(Models.testing.modelContainer)
}
