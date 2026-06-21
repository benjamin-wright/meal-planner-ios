//
//  IngredientEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 19/09/2025.
//

import SwiftUI
import SwiftData

struct IngredientEdit: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    
    private let id: UUID?
    private var edit: Bool { id != nil }
    
    @State private var ingredient: Ingredient?
    @Query(sort: \Ingredient.category.order) private var ingredients: [Ingredient]
    @Query(sort: \Category.order) private var categories: [Category]
    
    init(id: UUID?) {
        self.id = id
    }
    
    private func isInvalid(_ ingredient: Ingredient) -> Bool {
        if !ingredient.isValid() {
            return true
        }
        if ingredients.contains(where: { $0.id != ingredient.id && $0.name == ingredient.name }) {
            return true
        }
        return false
    }
    
    var body: some View {
        if let ingredient {
            @Bindable var ingredient = ingredient
            Form {
                Section {
                    TextInput(text: $ingredient.name, label: "Name", placeholder: "category")
                    NavigationLink(
                        value: ingredient.category,
                        label: {
                            Text("Category:").badge(ingredient.category.name)
                        }
                    )
                }
                Button {
                    if !edit {
                        context.insert(ingredient)
                    }
                    try! context.save()
                    dismiss()
                } label: {
                    Text(edit ? "Save" : "Add")
                }.disabled(isInvalid(ingredient))
            }
            .navigationDestination(for: Category.self) { _ in
                CategoryPicker(categories: categories, selected: $ingredient.category)
            }
            .navigationTitle("Ingredient")
        } else {
            ProgressView()
                .task {
                    if let id {
                        ingredient = try? context.fetch(Ingredient.descriptor(id: id)).first
                    } else {
                        ingredient = Ingredient.makeNew(in: context)
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        IngredientEdit(id: nil)
    }.modelContainer(Models.testing.modelContainer)
}
