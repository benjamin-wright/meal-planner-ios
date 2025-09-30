//
//  CategoriesView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 19/09/2025.
//

import SwiftUI
import SwiftData

struct CategoryData: Identifiable {
    var id: UUID = UUID()
    var name: String
}

struct CategoriesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    
    @Query(sort: \Category.order) private var categories: [Category]
    
    @State private var addingCategory: Bool = false
    
    var body: some View {
        return List {
            ForEach(categories) { category in
                NavigationLink {
                    CategoryEdit(
                        edit: true,
                        category: category,
                        categories: categories,
                        action: { updated in
                            category.name = updated.name
                        }
                    )
                } label: {
                    Text(category.name)
                }
            }.onDelete { offsets in
                var updated = categories
                for (index, category) in categories.enumerated() {
                    if offsets.contains(index) {
                        context.delete(category)
                        updated.remove(at: index)
                    }
                }
                
                for (index, _) in updated.enumerated() {
                    updated[index].order = index
                }
            }.onMove { from, to in
                var updated = categories
                
                updated.move(fromOffsets: from, toOffset: to)
                for (index, category) in updated.enumerated() {
                    category.order = index
                }
            }
            Button() {
                addingCategory = true
            } label: {
                Text("Add")
            }.disabled(editMode?.wrappedValue.isEditing ?? false)
        }
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $addingCategory) {
            CategoryEdit(
                category: Category(
                    name: "",
                    order: categories.count
                ),
                categories: categories,
                action: { category in
                    category.order = categories.count
                    context.insert(category)
                }
            )
        }
    }
}

#Preview {
    NavigationView {
        CategoriesView().modelContainer(Models.testing.modelContainer)
    }
}
