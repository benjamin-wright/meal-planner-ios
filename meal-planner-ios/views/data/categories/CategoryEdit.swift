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
    private var isEditing: Bool { id != nil }

    @State private var draft: CategoryDraft
    @State private var isLoading = false
    @State private var saveError: String?
    @Query(sort: \Category.order) private var categories: [Category]

    init(id: UUID? = nil) {
        self.id = id
        self._draft = State(initialValue: CategoryDraft())
    }

    private var validationErrors: [CategoryDraft.ValidationError] {
        draft.validate(existingNames: categories.filter { $0.id != id }.map(\.name))
    }

    private var isInvalid: Bool {
        !validationErrors.isEmpty
    }

    private func loadDraft() {
        do {
            let store = CategoryStore(context: context)
            draft = try id.map(store.draft) ?? store.newDraft()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func save() {
        do {
            try CategoryStore(context: context).save(draft, id: id)
            dismiss()
        } catch {
            saveError = error.localizedDescription
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
                        if let validationError = validationErrors.first {
                            Text(validationError.localizedDescription)
                                .foregroundStyle(.red)
                        }
                    }
                    Button(action: save) {
                        Text(isEditing ? "Save" : "Add")
                    }.disabled(isInvalid)
                }
                .navigationTitle("Category")
            }
        }
        .onFirstAppear(perform: loadDraft, loading: $isLoading)
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
    FlowContainer {
        CategoryEdit(id: nil)
    }
    .modelContainer(Models.testing.modelContainer)
}
