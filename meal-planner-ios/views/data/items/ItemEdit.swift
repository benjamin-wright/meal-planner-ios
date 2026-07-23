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
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    private let id: UUID?
    private let initialDraft: ItemDraft?
    private var isEditing: Bool { id != nil }
    
    @State private var draft: ItemDraft
    @State private var isLoading = false
    @State private var saveError: String?
    @Query(sort: \Item.category.order) private var items: [Item]
    @Query(sort: \Category.order) private var categories: [Category]
    
    init(id: UUID? = nil, draft: ItemDraft? = nil) {
        self.id = id
        self.initialDraft = draft
        self._draft = State(initialValue: draft ?? ItemDraft())
    }
    
    private var isInvalid: Bool {
        !draft.isValid(existingNames: items.filter { $0.id != id }.map(\.name))
    }

    private var categorySelection: Binding<UUID> {
        Binding(
            get: { draft.categoryID ?? categories.first?.id ?? UUID() },
            set: { draft.categoryID = $0 }
        )
    }

    private func loadDraft() {
        guard initialDraft == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if let id {
                guard let item = try context.fetch(Item.descriptor(id: id)).first else {
                    saveError = "This item no longer exists."
                    return
                }
                draft = ItemDraft(item: item)
            } else {
                draft.categoryID = try context.fetch(Category.orderedDescriptor).first?.id
            }
        } catch {
            saveError = "Could not load this item: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            guard let categoryID = draft.categoryID,
                  let category = try context.fetch(Category.descriptor(id: categoryID)).first else {
                saveError = "Please choose a category."
                return
            }
            let item: Item
            if let id {
                guard let existing = try context.fetch(Item.descriptor(id: id)).first else {
                    saveError = "This item no longer exists."
                    return
                }
                item = existing
            } else {
                item = Item(name: draft.name, category: category, kind: draft.kind)
                context.insert(item)
            }
            item.name = draft.name
            item.category = category
            item.kind = draft.kind.rawValue
            try context.save()
            dismiss()
        } catch {
            saveError = "Could not save this item: \(error.localizedDescription)"
        }
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                Form {
                    Section {
                        TextInput(text: $draft.name, label: "Name", placeholder: "item name")
                        NavigationLink(value: Route.picker) {
                            Text("Category:").badge(categories.first(where: { $0.id == draft.categoryID })?.name ?? "")
                        }
                    }
                    Button(action: save) {
                        Text(isEditing ? "Save" : "Add")
                    }.disabled(isInvalid)
                }
                .navigationTitle("Item")
            }
        }
        .navigationDestination(for: Route.self) { _ in
            CategoryPicker(selected: categorySelection)
        }
        .task(id: id) { loadDraft() }
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
        ItemEdit()
    }.modelContainer(Models.testing.modelContainer)
}
