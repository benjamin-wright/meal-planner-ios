//
//  CategoriesView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 19/09/2025.
//

import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    
    @Query(sort: \Category.order) private var categories: [Category]
    
    var body: some View {
        return List {
            ForEach(categories) { category in
                NavigationLink {
                    CategoryEdit(
                        edit: true,
                        category: category,
                        existing: categories,
                        action: {
                            try! context.save()
                        }
                    ).onDisappear {
                        context.rollback()
                    }
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
            Section {
                NavigationLink {
                    var category = Category(name: "", order: categories.count)
                    CategoryEdit(
                        category: category,
                        existing: categories,
                        action: {
                            context.insert(category)
                            try! context.save()
                            category = Category(name: "", order: categories.count)
                        }
                    ).onAppear {
                        category.name = ""
                    }
                } label: {
                    Text("Add")
                        .foregroundColor(.accent)
                }
            }
        }
        .toolbar {
            EditButton()
        }
    }
}

#Preview {
    NavigationView {
        CategoriesView().modelContainer(Models.testing.modelContainer)
    }
}
