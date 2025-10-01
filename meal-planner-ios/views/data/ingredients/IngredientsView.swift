//
//  IngredientsView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 01/10/2025.
//

import SwiftUI
import SwiftData

struct IngredientsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    
    @Query private var ingredients: [Ingredient]
    @Query private var categories: [Category]
    @State private var adding: Bool = false
    @State private var filtering: Bool = false
    @State private var search: String = ""
    @State private var scope: String = "vegetables"
    
    var body: some View {
        return List {
            ForEach(ingredients.filter({ search.count == 0 || $0.name.contains(search.lowercased()) })) { ingredient in
                NavigationLink {
                    IngredientEdit(
                        edit: true,
                        ingredient: ingredient,
                        ingredients: ingredients,
                        categories: categories,
                        action: { updated in
                            ingredient.update(updated)
                        }
                    )
                } label: {
                    Text(ingredient.name)
                }
            }.onDelete { offsets in
                for (index, ingredient) in ingredients.enumerated() {
                    if offsets.contains(index) {
                        context.delete(ingredient)
                    }
                }
            }
            Section {
                NavigationLink {
                    IngredientEdit(
                        edit: true,
                        ingredient: Ingredient(
                            name: "",
                            category: categories[0]
                        ),
                        ingredients: ingredients,
                        categories: categories,
                        action: { ingredient in
                            context.insert(ingredient)
                        }
                    )
                } label: {
                    Text("Add")
                        .foregroundColor(.accent)
                }
            }
        }
        .toolbar {
            EditButton()
        }
        .searchable(text: $search)
        .sheet(isPresented: $filtering) {
            Text("Filters")
        }.onChange(of: search) {
            let downcased = search.lowercased()
            if downcased != search {
                search = downcased
            }
        }
    }
}

#Preview {
    NavigationView {
        IngredientsView().modelContainer(Models.testing.modelContainer)
    }
}
