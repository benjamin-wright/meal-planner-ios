//
//  ItemPicker.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 07/10/2025.
//

import SwiftUI
import SwiftData

struct ItemPicker: View {
    @Environment(FlowRouter.self) private var router

    let items: [Item]
    let selectedID: UUID?
    var kindFilter: ItemKind? = nil
    @State var filter: ItemFilter = ItemFilter()
    let onSelect: (UUID) -> Void
    @State private var isSearchPresented = false

    var filteredItems: [Item] {
        items.filter { item in
            (kindFilter == nil || item.itemKind == kindFilter) && filter.filter(item: item)
        }
    }

    var body: some View {
        VStack {
            if kindFilter == nil {
                HStack {
                    FilterButton(image: .system("carrot.fill"), selected: $filter.ingredients)
                    FilterButton(image: .system("microwave.fill"), aspect: 1.5, selected: $filter.readymeals)
                    FilterButton(image: .system("bag.fill"), selected: $filter.misc)
                }.padding(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            }
            GlassList {
                ForEach(filteredItems) { item in
                    SelectionRow(title: item.name, isSelected: item.id == selectedID) {
                        isSearchPresented = false
                        onSelect(item.id)
                    }
                }
            }
            .searchable(text: $filter.search, isPresented: $isSearchPresented, placement: .navigationBarDrawer(displayMode: .always))
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") {
                    isSearchPresented = false
                    router.showCreation(.item(kind: kindFilter), onCreate: onSelect)
                }
            }
        }
        .navigationTitle("Item")
    }
}

#Preview {
    struct Preview: View {
        @Query() private var items: [Item]
        @State private var selectedID: UUID = UUID()

        var body: some View {
            FlowContainer {
                ItemPicker(
                    items: items,
                    selectedID: selectedID,
                    onSelect: { selectedID = $0 }
                )
            }
        }
    }

    return Preview()
        .modelContainer(Models.testing.modelContainer)
}
