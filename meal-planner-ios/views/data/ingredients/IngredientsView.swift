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

    @Query(sort: \Ingredient.name) private var ingredients: [Ingredient]
    @Query(sort: \Category.order) private var categories: [Category]
    
    var body: some View {
        return VStack {
            List {
                ForEach(categories) { category in
                    let filtered = ingredients.filter({ $0.category.name == category.name })
                    if filtered.count > 0 {
                        Section(category.name) {
                            ForEach(filtered) { ingredient in
                                NavigationLink(ingredient.name, value: ingredient)
                                    .onChange(of: ingredients) {}
                            }.onDelete { offsets in
                                for (index, ingredient) in ingredients.enumerated() {
                                    if offsets.contains(index) {
                                        context.delete(ingredient)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section {
                    NavigationLink(
                        value: Ingredient(
                            name: "",
                            category: categories[0]
                        ), label: {
                            Text("Add").foregroundColor(.accent)
                        }
                    )
                }
            }
            .toolbar {
                EditButton()
            }
            .navigationDestination(for: Ingredient.self) { ingredient in
                IngredientEdit(
                    ingredient: ingredient,
                    ingredients: ingredients,
                    categories: categories,
                    action: {
                        if !ingredients.contains(where: { $0.id == ingredient.id }) {
                            context.insert(ingredient)
                        }
                        try! context.save()
                    }
                ).onDisappear() {
                    context.rollback()
                }
            }
            .navigationTitle("Ingredients")
        }
    }
}

#Preview {
    NavigationStack {
        IngredientsView().modelContainer(Models.testing.modelContainer)
    }
}
