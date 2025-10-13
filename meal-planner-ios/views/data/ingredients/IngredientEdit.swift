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
    
    @State var edit: Bool = false
    @State var ingredient: Ingredient
    @State var ingredients: [Ingredient]
    @State var categories: [Category]
    var action: () -> Void
    
    private func isInvalid() -> Bool {
        if !ingredient.isValid() {
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
                action()
                dismiss()
            } label: {
                Text(edit ? "Save" : "Add")
            }.disabled(isInvalid())
        }
        .navigationTitle("Ingredient")
    }
}

#Preview {
    let cat1 = Category(name: "thing1", order: 1)
    let cat2 = Category(name: "thing2", order: 2)
    let ingredient = Ingredient(name: "start", category: cat1)
    NavigationStack {
        IngredientEdit(
            edit: true,
            ingredient: ingredient,
            ingredients: [
                Ingredient(name: "test", category: cat2),
                ingredient
            ],
            categories: [
                cat1,
                cat2
            ],
            action: {
                print(ingredient.name)
            }
        )
    }
}
