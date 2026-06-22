//
//  ItemEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 19/09/2025.
//

import SwiftUI
import SwiftData

struct ItemEdit: View {
    enum Route: Hashable {
        case picker
    }
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    
    private let id: UUID?
    private var edit: Bool { id != nil }
    
    @State private var item: Item?
    @Query(sort: \Item.category.order) private var items: [Item]
    
    init(id: UUID? = nil) {
        self.id = id
    }
    
    private func isInvalid(_ item: Item) -> Bool {
        if !item.isValid() {
            return true
        }
        if items.contains(where: { $0.id != item.id && $0.name == item.name }) {
            return true
        }
        return false
    }
    
    var body: some View {
        if let item {
            @Bindable var item = item
            Form {
                Section {
                    TextInput(text: $item.name, label: "Name", placeholder: "category")
                    NavigationLink(
                        value: Route.picker,
                        label: {
                            Text("Category:").badge(item.category.name)
                        }
                    )
                }
                Button {
                    if !edit {
                        context.insert(item)
                    }
                    try! context.save()
                    dismiss()
                } label: {
                    Text(edit ? "Save" : "Add")
                }.disabled(isInvalid(item))
            }
            .navigationDestination(for: Route.self) { route in
                CategoryPicker(selected: Binding(
                    get: { item.category.id },
                    set: { newCategoryID in
                        guard let newCategory = try? context.fetch(Category.descriptor(id: newCategoryID)).first else {
                            return
                        }
                    
                        item.category = newCategory
                    }
                ))
            }
            .navigationTitle("Item")
        } else {
            ProgressView()
                .task {
                    if let id {
                        item = try? context.fetch(Item.descriptor(id: id)).first
                    } else {
                        item = Item.makeNew(in: context)
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        ItemEdit()
    }.modelContainer(Models.testing.modelContainer)
}
