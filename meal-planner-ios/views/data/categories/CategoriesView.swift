//
//  CategoriesView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 19/09/2025.
//

import SwiftUI
import SwiftData

extension CategoriesView {
    @Observable
    class ObservableCategory {
        var category: Category
        
        init(_ category: Category) {
            self.category = category
        }
    }
}

struct CategoriesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    
    @Query(sort: \Category.order) private var categories: [Category]
    
    var body: some View {
        return List {
            ForEach(categories) { category in
                let obs = ObservableCategory(category)
                NavigationLink(obs.category.name, value: obs.category)
                    .onChange(of: categories) {}
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
                NavigationLink(
                    value: Category(name: "", order: categories.count),
                    label: {
                        Text("Add")
                            .foregroundColor(.accent)
                    }
                )
            }
        }
        .toolbar {
            EditButton()
        }
        .navigationDestination(for: Category.self) { item in
            let edit = categories.contains(where: { $0.id == item.id })
            CategoryEdit(
                edit: edit,
                category: item,
                existing: categories,
                action: {
                    if !edit {
                        context.insert(item)
                    }
                    try! context.save()
                }
            ).onDisappear {
                context.rollback()
            }
        }
        .navigationTitle("Categories")
    }
}

#Preview {
    NavigationStack {
        CategoriesView().modelContainer(Models.testing.modelContainer)
    }
}
