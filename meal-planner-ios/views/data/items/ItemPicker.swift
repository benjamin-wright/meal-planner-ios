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
    
    @State var items: [Item]
    @Binding var selected: Item
    @State var search: String = ""
    
    var body: some View {
        List {
            Picker("item", selection: $selected) {
                ForEach(items.filter {
                    search.count == 0 ||
                    $0.name.contains(search) ||
                    $0.category.name.contains(search)
                }) { item in
                    Text(item.name).tag(item)
                }
            }.pickerStyle(.inline)
                .labelsHidden()
        }
        .searchable(text: $search)
        .onChange(of: search) {
            let lowercase = search.lowercased()
            if lowercase != search {
                search = lowercase
            }
        }.onChange(of: selected) {
            dismiss()
        }
        .navigationTitle("Item")
    }
}

#Preview {
    struct Preview: View {
        @Query() private var items: [Item]
        @State private var selected: Item
        
        init() {
            self._selected = State(initialValue: Item(category: Category(name: "testing", order: 10), kind: .ingredient))
        }
        
        var body: some View {
            NavigationStack {
                ItemPicker(
                    items: items,
                    selected: $selected
                )
            }
        }
    }
    
    return Preview().modelContainer(Models.testing.modelContainer)
}
