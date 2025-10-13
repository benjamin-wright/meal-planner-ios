//
//  CategoryEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 19/09/2025.
//

import SwiftUI
import SwiftData

struct CategoryEdit: View {
    @Environment(\.dismiss) private var dismiss
    
    @State var edit: Bool = false
    @State var category: Category
    @State var existing: [Category]
    var action: () -> Void
    
    private func isInvalid() -> Bool {
        if !category.isValid() {
            return true
        }
        
        if existing
            .contains(where: { $0.id != category.id && $0.name == category.name }) {
            return true
        }
        
        return false
    }
    
    var body: some View {
        Form {
            Section {
                TextInput(text: $category.name, label: "Name", placeholder: "category")
            }
            
            Button {
                action()
                dismiss()
            } label: {
                Text(edit ? "Update" : "Add")
            }.disabled(isInvalid())
        }
        .navigationTitle("Category")
    }
}

#Preview {
    let input = Category(name: "start", order: 1)
    NavigationStack {
        CategoryEdit(
            edit: true,
            category: input,
            existing: [
                Category(name: "test", order: 0),
                input
            ], action: {
                print(input.name)
            }
        )
    }
}
