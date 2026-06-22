//
//  CategoriesView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 19/09/2025.
//

import SwiftUI
import SwiftData

struct CategoriesView: View {
    enum Route: Hashable {
        case id(_ id: UUID?)
    }

    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    
    @State var search: String = ""

    @Query(sort: \Category.order) private var categories: [Category]

    var body: some View {
        return List {
            ForEach(categories.filter {
                search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
            
            }) { category in
                NavigationLink(category.name, value: Route.id(category.id))
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

                try! context.save()
            }.onMove { from, to in
                var updated = categories
                updated.move(fromOffsets: from, toOffset: to)

                for (index, category) in updated.enumerated() {
                    category.order = index
                }

                try! context.save()
            }
            Section {
                NavigationLink(
                    value: Route.id(nil),
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
        .searchable(text: $search)
        .navigationDestination(for: Route.self) { route in
            switch route {
            case .id(let id):
                CategoryEdit(id: id).modelContext(context.editContext())
            }
        }
        .navigationTitle("Categories")
    }
}

#Preview {
    let container = Models.testing.modelContainer

    NavigationStack {
        CategoriesView().modelContainer(container)
    }
}
