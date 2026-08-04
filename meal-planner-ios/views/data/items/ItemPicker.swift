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
    @State var search: String = ""

    var filteredItems: [Item] {
        items.filter {
            search.isEmpty ||
            $0.name.contains(search) ||
            $0.category.name.contains(search)
        }
    }

    var body: some View {
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
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
        .onChange(of: search) {
            let lowercase = search.lowercased()
            if lowercase != search {
                search = lowercase
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
