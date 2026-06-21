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
        case id(_ id: UUID?)
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
                        value: Route.id(nil), label: {
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
                    IngredientEdit(id: id).modelContext(editContext)
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
