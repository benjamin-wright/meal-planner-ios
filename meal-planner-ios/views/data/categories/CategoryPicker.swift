//
//  CategoryPicker.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 21/06/2026.
//

import SwiftUI
import SwiftData

struct CategoryPicker: View {
    @Environment(FlowRouter.self) private var router

    let categories: [Category]
    let selectedID: UUID?

    let onSelect: (UUID) -> Void
    @State private var search = ""

    var filteredCategories: [Category] {
        categories.filter {
            search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        GlassList {
            ForEach(filteredCategories) { category in
                SelectionRow(title: category.name, isSelected: category.id == selectedID) {
                    onSelect(category.id)
                }
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
            Button("Add") {
                router.showCreation(.category, onCreate: onSelect)
            }
        }
        .navigationTitle("Category")
    }
}

#Preview {
    struct Preview: View {
        @Query(sort: \Category.order) private var categories: [Category]
        @State private var selectedID: UUID = UUID()

        var body: some View {
            FlowContainer {
                CategoryPicker(
                    categories: categories,
                    selectedID: selectedID,
                    onSelect: { selectedID = $0 }
                )
            }
        }
    }

    return Preview()
        .modelContainer(Models.testing.modelContainer)
}
