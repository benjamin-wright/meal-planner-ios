//
//  ItemPicker.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 07/10/2025.
//

import SwiftUI
import SwiftData

struct ItemPicker: View {
    @Environment(\.dismiss) var dismiss

    let items: [Item]
    @Binding var selectedID: UUID
    @State var filter: ItemFilter = ItemFilter()

    var filteredItems: [Item] {
        items.filter(filter.filter)
    }

    var body: some View {
        VStack {
            HStack {
                FilterButton(image: .system("carrot.fill"), selected: $filter.ingredients)
                FilterButton(image: .system("takeoutbag.and.cup.and.straw.fill"), selected: $filter.readymeals)
                FilterButton(image: .system("bag.fill"), selected: $filter.misc)
            }.padding(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            List {
                ForEach(filteredItems) { item in
                    Button {
                        selectedID = item.id
                        dismiss()
                    } label: {
                        HStack {
                            Text(item.name)
                            Spacer()
                            if item.id == selectedID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            .searchable(text: $filter.search, placement: .navigationBarDrawer(displayMode: .always))
        }
        .navigationTitle("Item")
    }
}

#Preview {
    struct Preview: View {
        @Query() private var items: [Item]
        @State private var selectedID: UUID = UUID()

        var body: some View {
            NavigationStack {
                ItemPicker(
                    items: items,
                    selectedID: $selectedID
                )
            }
        }
    }

    return Preview().modelContainer(Models.testing.modelContainer)
}
