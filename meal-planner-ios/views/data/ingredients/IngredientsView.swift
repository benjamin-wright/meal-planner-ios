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
    
    @Query(sort: \Ingredient.category.order) private var ingredients: [Ingredient]
    @Query(sort: \Category.order) private var categories: [Category]
    
    @State var filterCategory: String = ""
    @State var filtering: Bool = false
    
    var body: some View {
        return VStack {
            List {
                if filtering {
                    Section("filters") {
                        Picker("Category", selection: $filterCategory) {
                            Text("all").tag("")
                            ForEach(categories) { category in
                                Text(category.name).tag(category.name)
                            }
                        }
                    }
                }
                ForEach(ingredients.filter({
                    filterCategory == ""
                    || $0.category.name == filterCategory
                })) { ingredient in
                    NavigationLink(ingredient.name, value: ingredient)
                        .onChange(of: ingredients) {}
                }.onDelete { offsets in
                    for (index, ingredient) in ingredients.enumerated() {
                        if offsets.contains(index) {
                            context.delete(ingredient)
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
                Button {
                    filtering = !filtering
                    if !filtering {
                        filterCategory = ""
                    }
                } label: {
                    Text(filtering ? "Unfilter" : "Filter")
                }
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
        }
    }
}

#Preview {
    NavigationStack {
        IngredientsView().modelContainer(Models.testing.modelContainer)
    }
}
