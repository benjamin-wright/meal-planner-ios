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
    private let initialDraft: CategoryDraft?
    private var isEditing: Bool { id != nil }

    @State private var draft: CategoryDraft
    @State private var isLoading = false
    @State private var saveError: String?
    @Query(sort: \Category.order) private var categories: [Category]

    init(id: UUID? = nil, draft: CategoryDraft? = nil) {
        self.id = id
        self.initialDraft = draft
        self._draft = State(initialValue: draft ?? CategoryDraft())
    }

    private var isInvalid: Bool {
        draft.name.count < 3 || categories.contains { $0.id != id && $0.name == draft.name }
    }

    private func loadDraft() {
        guard initialDraft == nil, let id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            guard let category = try context.fetch(Category.descriptor(id: id)).first else {
                saveError = "This category no longer exists."
                return
            }
            draft = CategoryDraft(category: category)
        } catch {
            saveError = "Could not load this category: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            let category: Category
            if let id {
                guard let existing = try context.fetch(Category.descriptor(id: id)).first else {
                    saveError = "This category no longer exists."
                    return
                }
                category = existing
            } else {
                category = Category(name: draft.name, order: draft.order)
                context.insert(category)
            }
            category.name = draft.name
            category.order = draft.order
            try context.save()
            dismiss()
        } catch {
            saveError = "Could not save this category: \(error.localizedDescription)"
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                Form {
                    Section {
                        TextInput(text: $draft.name, label: "Name", placeholder: "category")
                    }
                    Button(action: save) {
                        Text(isEditing ? "Save" : "Add")
                    }.disabled(isInvalid)
                }
                .navigationTitle("Category")
            }
        }
        .task(id: id) { loadDraft() }
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
    NavigationStack {
        CategoryEdit(id: nil)
    }.modelContainer(Models.testing.modelContainer)
}
