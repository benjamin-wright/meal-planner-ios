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
    
    private var edit: Bool
    @Query(sort: \Ingredient.category.order) private var ingredients: [Ingredient]
    @Query(sort: \Category.order) private var categories: [Category]
    @Bindable var ingredient: Ingredient
    
    init(_ ingredient: Ingredient, edit: Bool) {
        self.ingredient = ingredient
        self.edit = edit
    }
    
    private func isInvalid() -> Bool {
        if !self.ingredient.isValid() {
            return true
        }
        
        if ingredients
            .contains(where: { $0.id != ingredient.id && $0.name == ingredient.name }) {
            return true
        }
        
        return false
    }
    
    var body: some View {
        Form {
            Section {
                TextInput(text: $ingredient.name, label: "Name", placeholder: "category")
                HStack {
                    Picker("Category", selection: $ingredient.category) {
                        ForEach(categories) { category in
                            Text(category.name).tag(category)
                        }
                        NavigationLink("New") {
                            Text("New")
                        }
                    }.frame(maxWidth: .infinity)
                }
            }
            Button {
                if !edit {
                    context.insert(ingredient)
                }
                try! context.save()
                dismiss()
            } label: {
                Text(edit ? "Save" : "Add")
            }.disabled(isInvalid())
        }
        .navigationTitle("Ingredient")
    }
}

#Preview {
    let container = Models.testing.modelContainer
    let ingredient = Ingredient.makeNew(in: container.mainContext)!
    return NavigationStack {
        IngredientEdit(ingredient, edit: false)
    }.modelContainer(container)
}
