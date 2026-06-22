//
//  CategoryPicker.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 21/06/2026.
//

import SwiftUI
import SwiftData

struct CategoryPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Category.order) private var categories: [Category]
    @Binding var selected: UUID

    @State private var search = ""
    @State private var isAddingCategory = false

    var filteredCategories: [Category] {
        categories.filter {
            search.isEmpty || $0.name.contains(search)
        }
    }

    var body: some View {
        List {
            Picker("category", selection: $selected) {
                ForEach(filteredCategories) { category in
                    Text(category.name).tag(category.id)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .searchable(text: $search)
        .onChange(of: selected) {
            dismiss()
        }
        .toolbar {
            Button("Add") {
                isAddingCategory = true
            }
        }
        .navigationDestination(isPresented: $isAddingCategory) {
            CategoryEdit()
        }
        .navigationTitle("Category")
    }
}

#Preview {
    struct Preview: View {
        @State private var selected: UUID
        
        init() {
            self._selected = State(initialValue: UUID())
        }
        
        var body: some View {
            NavigationStack {
                CategoryPicker(
                    selected: $selected
                )
            }
        }
    }
    
    return Preview().modelContainer(Models.testing.modelContainer)
}
