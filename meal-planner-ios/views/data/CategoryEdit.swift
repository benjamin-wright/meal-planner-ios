//
//  CategoryEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 19/09/2025.
//

import SwiftUI
import SwiftData

struct CategoryEdit: View {
    @Environment(\.dismiss) var dismiss
    
    @State var edit: Bool = false
    @State var categories: [Category]
    var action: (_ category: Category) -> Void
    var category: Category
    @State private var actual: Category
    
    init(edit: Bool = false, category: Category, categories: [Category], action: @escaping (_ caregory: Category) -> Void) {
        self.edit = edit
        self.categories = categories
        self.action = action
        self.category = category
        self.actual = category.clone()
    }
    
    private func isInvalid() -> Bool {
        if !actual.isValid() {
            return true
        }
        
        if categories
            .contains(where: { $0.name == actual.name }) {
            return true
        }
        
        return false
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextInput(text: $actual.name, label: "Name", placeholder: "category")
                }
                
                Button {
                    action(actual)
                    dismiss()
                } label: {
                    Text(edit ? "Save" : "Add")
                }.disabled(isInvalid())
            }
        }.onAppear {
            actual = category.clone()
        }
    }
}

#Preview {
    CategoryEdit(
        edit: true,
        category: Category(name: "start", order: 1),
        categories: [
            Category(name: "test", order: 0),
            Category(name: "start", order: 1)
        ], action: { name in
            print(name)
        }
    )
}
