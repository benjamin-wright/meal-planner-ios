//
//  IngredientsView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 01/10/2025.
//

import SwiftUI
import SwiftData

struct IngredientsView: View {
    enum Route: Hashable {
        case new
        case id(_ id: UUID)
    }
    
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
                    NavigationLink(ingredient.name, value: Route.id(ingredient.id))
                        .onChange(of: ingredients) {}
                }.onDelete { offsets in
                    for (index, ingredient) in ingredients.enumerated() {
                        if offsets.contains(index) {
                            context.delete(ingredient)
                        }
                    }
                    
                    try! context.save()
                }
                Section {
                    NavigationLink(
                        value: Route.new, label: {
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
            .navigationDestination(for: Route.self) { route in
                let editContext = context.editContext()
                switch route {
                case .id(let id):
                    if let existing = try? editContext.fetch(Ingredient.descriptor(id: id)).first {
                        IngredientEdit(existing, edit: true).modelContext(editContext)
                    } else {
                        EmptyView()
                    }
                case .new:
                    if let newIngredient = Ingredient.makeNew(in: editContext) {
                        IngredientEdit(newIngredient, edit: false).modelContext(editContext)
                    } else {
                        EmptyView()
                    }
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
