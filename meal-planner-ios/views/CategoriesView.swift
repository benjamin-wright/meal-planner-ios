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
    @Query(sort: \Category.order) var categories: [Category]
    
    @State private var addingCategory: Bool = false
    
    var body: some View {
        List {
            ForEach(categories) { category in
                Text(category.name)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button() {
                    addingCategory = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $addingCategory) {
            CategoryEdit()
        }
    }
}

#Preview {
    NavigationView {
        CategoriesView().modelContainer(SampleData.shared.modelContainer)
    }
}
