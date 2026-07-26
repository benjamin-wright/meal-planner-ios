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
    @State private var saveError: String?

    @Query(sort: \Category.order) private var categories: [Category]

    var body: some View {
        return List {
            ForEach(categories.filter {
                search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
            
            }) { category in
                NavigationLink(category.name, value: Route.id(category.id))
            }.onDelete { offsets in
                do {
                    let filteredCategories = categories.filter {
                        search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
                    }
                    try CategoryStore(context: context).delete(ids: offsets.map { filteredCategories[$0].id })
                } catch {
                    saveError = error.localizedDescription
                }
            }.onMove { from, to in
                guard search.isEmpty else { return }
                do {
                    try CategoryStore(context: context).move(fromOffsets: from, toOffset: to)
                } catch {
                    saveError = error.localizedDescription
                }
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
                CategoryEdit(id: id)
            }
        }
        .navigationTitle("Categories")
        .alert("Category", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }
}

#Preview {
    let container = Models.testing.modelContainer

    NavigationStack {
        CategoriesView()
    }
    .modelContainer(container)
}
