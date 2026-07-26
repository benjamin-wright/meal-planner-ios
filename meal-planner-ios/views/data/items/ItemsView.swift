//
//  ItemsView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 01/10/2025.
//

import SwiftUI
import SwiftData

struct ItemsView: View {
    enum Route: Hashable {
        case id(_ id: UUID?)
    }
    
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    
    @Query(sort: \Item.category.order) private var items: [Item]
    @Query(sort: \Category.order) private var categories: [Category]
    
    @State var search: String = ""
    @State private var saveError: String?
    
    var body: some View {
        return VStack {
            List {
                ForEach(items.filter({
                    search == ""
                    || $0.name.localizedCaseInsensitiveContains(search)
                    || $0.category.name.localizedCaseInsensitiveContains(search)
                })) { item in
                    NavigationLink(item.name, value: Route.id(item.id))
                }.onDelete { offsets in
                    do {
                        let filteredItems = items.filter {
                            search == ""
                            || $0.name.localizedCaseInsensitiveContains(search)
                            || $0.category.name.localizedCaseInsensitiveContains(search)
                        }
                        try ItemStore(context: context).delete(ids: offsets.map { filteredItems[$0].id })
                    } catch {
                        saveError = error.localizedDescription
                    }
                }
                Section {
                    NavigationLink(
                        value: Route.id(nil), label: {
                            Text("Add").foregroundColor(.accent)
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
                    ItemEdit(id: id)
                }
            }
            .navigationTitle("Items")
        }
        .alert("Item", isPresented: Binding(
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
    NavigationStack {
        ItemsView()
    }
    .modelContainer(Models.testing.modelContainer)
}
