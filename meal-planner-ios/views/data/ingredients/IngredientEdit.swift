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
    @State var ingredients: [Ingredient]
    @State var categories: [Category]
    var action: (_ ingredient: Ingredient) -> Void
    @State private var ingredient: Ingredient
    @State private var actual: Ingredient
    @State private var selectedCategory: String
    
    init(edit: Bool = false, ingredient: Ingredient, ingredients: [Ingredient], categories: [Category], action: @escaping (_ ingredient: Ingredient) -> Void) {
        self.edit = edit
        self.ingredients = ingredients
        self.categories = categories
        self.action = action
        self.ingredient = ingredient
        self.actual = ingredient.clone()
        self.selectedCategory = ingredient.category.name
    }
    
    private func isInvalid() -> Bool {
        if !actual.isValid() {
            return true
        }
        
        if ingredients
            .contains(where: { $0.name == actual.name }) {
            return true
        }
        
        return false
    }
    
    var body: some View {
        Form {
            Section {
                TextInput(text: $actual.name, label: "Name", placeholder: "category")
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories) { category in
                        Text(category.name).tag(category.name)
                    }
                }
            }
            Button {
                action(actual)
                dismiss()
            } label: {
                Text(edit ? "Save" : "Add")
            }.disabled(isInvalid())
        }.onAppear {
            actual = ingredient.clone()
            self.selectedCategory = ingredient.category.name
        }.onChange(of: selectedCategory) {
            let category = categories.first(where: { $0.name == selectedCategory })
            if category != nil {
                self.actual.category = category!
            }
        }
    }
}

#Preview {
    let cat1 = Category(name: "thing1", order: 1)
    let cat2 = Category(name: "thing2", order: 2)
    IngredientEdit(
        edit: true,
        ingredient: Ingredient(name: "start", category: cat1),
        ingredients: [
            Ingredient(name: "test", category: cat2),
            Ingredient(name: "start", category: cat1)
        ],
        categories: [
            cat1,
            cat2
        ],
        action: { name in
            print(name)
        }
    )
}
