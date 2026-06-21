//
//  CategoryEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 19/09/2025.
//

import SwiftUI
import SwiftData

struct CategoryEdit: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let id: UUID?
    private var edit: Bool { id != nil }

    @State private var category: Category?
    @Query(sort: \Category.order) private var categories: [Category]

    init(id: UUID?) {
        self.id = id
    }

    private func isInvalid(_ category: Category) -> Bool {
        if !category.isValid() {
            return true
        }
        if categories.contains(where: { $0.id != category.id && $0.name == category.name }) {
            return true
        }
        return false
    }

    var body: some View {
        if let category {
            @Bindable var category = category
            Form {
                Section {
                    TextInput(text: $category.name, label: "Name", placeholder: "category")
                }
                Button {
                    if !edit {
                        context.insert(category)
                    }
                    try! context.save()
                    dismiss()
                } label: {
                    Text(edit ? "Save" : "Add")
                }.disabled(isInvalid(category))
            }
            .navigationTitle("Category")
        } else {
            ProgressView()
                .task {
                    if let id {
                        category = try? context.fetch(Category.descriptor(id: id)).first
                    } else {
                        category = Category.makeNew(in: context)
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        CategoryEdit(id: nil)
    }.modelContainer(Models.testing.modelContainer)
}
