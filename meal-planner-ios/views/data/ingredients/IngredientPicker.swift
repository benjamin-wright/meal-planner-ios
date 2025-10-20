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
    
    var categories: [Category] {
        var categories: [Category] = []
        for ingredient in filtered {
            if !categories.contains(where: { $0.name == ingredient.category.name}) {
                categories.append(ingredient.category)
            }
        }
        
        categories.sort(by: { $0.order < $1.order })
        
        return categories
    }
    
    var filtered: [Ingredient] {
        var filtered = ingredients.filter({
            search.count == 0 ||
            $0.name.contains(search) ||
            $0.category.name.contains(search)
        })
        
        filtered.sort(by: { $0.name < $1.name })
        
        return filtered
    }
    
    var list: some View {
        ForEach(categories) { category in
            Section(header: Text(category.name)) {
                Picker("ingredient", selection: $selected) {
                    ForEach(filtered.filter({ $0.category.name == category.name })) { ingredient in
                        Text(ingredient.name).tag(ingredient)
                    }
                }.pickerStyle(.inline)
                    .labelsHidden()
            }
        }
    }
    
    var body: some View {
        Form {
                self.list
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
