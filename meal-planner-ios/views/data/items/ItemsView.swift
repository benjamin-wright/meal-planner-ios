//
//  ItemsView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 01/10/2025.
//

import SwiftUI
import SwiftData

struct ItemsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    
    @Query(sort: \Item.category.order) private var items: [Item]
    @Query(sort: \Category.order) private var categories: [Category]

    @State private var saveError: String?
    @State private var filter: ItemFilter = ItemFilter()
    
    var body: some View {
        return VStack {
            HStack {
                FilterButton(image: .system("carrot.fill"), selected: $filter.ingredients)
                FilterButton(image: .system("takeoutbag.and.cup.and.straw.fill"), selected: $filter.readymeals)
                FilterButton(image: .system("bag.fill"), selected: $filter.misc)
            }.padding(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            List {
                ForEach(items.filter(filter.filter)) { item in
                    NavigationLink(item.name, value: FlowRouter.Route.editItem(item.id))
                }.onDelete { offsets in
                    do {
                        let filteredItems = items.filter(filter.filter)
                        try ItemStore(context: context).delete(ids: offsets.map { filteredItems[$0].id })
                    } catch {
                        saveError = error.localizedDescription
                    }
                }
                Section {
                    NavigationLink(
                        value: FlowRouter.Route.newItem, label: {
                            Text("Add").foregroundColor(.accent)
                        }
                    )
                }
            }
            .toolbar {
                EditButton()
            }
            .searchable(text: $filter.search, placement: .navigationBarDrawer(displayMode: .always))
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
    FlowContainer {
        ItemsView()
    }
    .modelContainer(Models.testing.modelContainer)
}
