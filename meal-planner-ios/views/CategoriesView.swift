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
    @Query(sort: \Category.order) private var categories: [Category]
    
    @State private var addingCategory: Bool = false
    
    var body: some View {
        return List {
            ForEach(categories) { category in
                NavigationLink {
                    CategoryEdit(
                        name: category.name,
                        categories: categories,
                        action: { name in
                            categories.first(where: { $0.id == category.id })?.name = name
                        }
                    )
                } label: {
                    Text(category.name)
                }
            }.onDelete { offsets in
                print("Deleting - \(offsets.count)")
                for (index, category) in categories.enumerated() {
                    if offsets.contains(index) {
                        context.delete(category)
                    }
                }
            }.onMove { from, to in
                print("MOVE - from: \(from.count), to: \(to)")
                
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
            }
        }
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $addingCategory) {
            CategoryEdit(
                categories: categories,
                action: { name in
                    context.insert(
                        Category(name: name, order: categories.count)
                    )
                }
            )
        }
    }
}

#Preview {
    NavigationView {
        CategoriesView().modelContainer(SampleData.shared.modelContainer)
    }
}
