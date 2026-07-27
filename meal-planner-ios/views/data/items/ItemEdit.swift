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
    private var isEditing: Bool { id != nil }
    
    @State private var draft: ItemDraft
    @State private var isLoading = false
    @State private var saveError: String?
    @Query(sort: \Item.category.order) private var items: [Item]
    @Query(sort: \Category.order) private var categories: [Category]
    
    init(id: UUID? = nil) {
        self.id = id
        self._draft = State(initialValue: ItemDraft())
    }
    
    private var validationErrors: [ItemDraft.ValidationError] {
        draft.validate(existingNames: items.filter { $0.id != id }.map(\.name))
    }

    private var isInvalid: Bool {
        !validationErrors.isEmpty
    }

    private func loadDraft() {
        do {
            let store = ItemStore(context: context)
            draft = try id.map(store.draft) ?? store.newDraft()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func save() {
        do {
            try ItemStore(context: context).save(draft, id: id)
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
                        TextInput(text: $draft.name, label: "Name", placeholder: "item name")
                        if let validationError = validationErrors.first {
                            Text(validationError.localizedDescription)
                                .foregroundStyle(.red)
                        }
                        EnumPicker(selection: $draft.kind).pickerStyle(.segmented)
                        if draft.kind == .readymeal {
                            EnumPicker(label: "Meal", selection: $draft.readymealData.mealTypeEnum).pickerStyle(.segmented)
                            if draft.readymealData.mealTypeEnum == .dinner {
                                EnumPicker(label: "Course", selection: $draft.readymealData.courseEnum).pickerStyle(.segmented)
                            }
                            IntegerInput(number: $draft.readymealData.serves, label: "Serves", placeholder: "number of portions")
                            IntegerInput(number: $draft.readymealData.time, label: "Time", placeholder: "time to cook (minutes)", step: 5)
                        }
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
            CategoryPicker(selectedID: $draft.categoryID)
        }
        .onFirstAppear(perform: loadDraft, loading: $isLoading)
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
