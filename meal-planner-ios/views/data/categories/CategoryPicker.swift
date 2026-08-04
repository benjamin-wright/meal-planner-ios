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

    let categories: [Category]
    @Binding var selectedID: UUID

    @State private var search = ""
    @State private var isAddingCategory = false

    var filteredCategories: [Category] {
        categories.filter {
            search.isEmpty || $0.name.contains(search)
        }
    }

    var body: some View {
        List {
            ForEach(filteredCategories) { category in
                Button {
                    selectedID = category.id
                    dismiss()
                } label: {
                    HStack {
                        Text(category.name)
                        Spacer()
                        if category.id == selectedID {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
        .onChange(of: search) {
            let lowercase = search.lowercased()
            if lowercase != search {
                search = lowercase
            }
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
        @Query(sort: \Category.order) private var categories: [Category]
        @State private var selectedID: UUID = UUID()

        var body: some View {
            NavigationStack {
                CategoryPicker(
                    categories: categories,
                    selectedID: $selectedID
                )
            }
        }
    }

    return Preview().modelContainer(Models.testing.modelContainer)
}
