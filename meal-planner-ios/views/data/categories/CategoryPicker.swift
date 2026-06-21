//
//  CategoryPicker.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 21/06/2026.
//

import SwiftUI
import SwiftData

struct CategoryPicker: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context

    @State var categories: [Category]
    @Binding var selected: Category
    @State var search: String = ""
    @State private var isAddingCategory = false

    var body: some View {
        List {
            Picker("category", selection: $selected) {
                ForEach(categories.filter {
                    search.count == 0 ||
                    $0.name.contains(search)
                }) { category in
                    Text(category.name).tag(category)
                }
            }.pickerStyle(.inline)
                .labelsHidden()
        }
        .searchable(text: $search)
        .onChange(of: search) {
            let lowercase = search.lowercased()
            if lowercase != search {
                search = lowercase
            }
        }.onChange(of: selected) {
            dismiss()
        }
        .toolbar {
            Button("Add") {
                isAddingCategory = true
            }
        }
        .navigationDestination(isPresented: $isAddingCategory) {
            CategoryEdit(id: nil).modelContext(context.editContext())
        }
        .navigationTitle("Category")
    }
}

#Preview {
    struct Preview: View {
        @Query(sort: \Category.order) private var categories: [Category]
        @State private var selected: Category
        
        init() {
            self._selected = State(initialValue: Category(name: "Preview", order: 0))
        }
        
        var body: some View {
            NavigationStack {
                CategoryPicker(
                    categories: categories,
                    selected: $selected
                )
            }
        }
    }
    
    return Preview().modelContainer(Models.testing.modelContainer)
}
