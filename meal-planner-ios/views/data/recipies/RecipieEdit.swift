//
//  RecipieEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 29/09/2025.
//

import SwiftUI
import SwiftData

struct RecipieEdit: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let id: UUID?
    private var isEditing: Bool { id != nil }

    @State private var draft: RecipieDraft
    @State private var isLoading = false
    @State private var saveError: String?
    @Query private var existing: [Recipie]
    @Query private var units: [Unit]
    @Query private var items: [Item]
    @State private var editMode: EditMode = .inactive

    init(id: UUID? = nil, type: RecipieType) {
        self.id = id
        self._draft = State(initialValue: RecipieDraft(type: type))
    }

    private var validationErrors: [RecipieDraft.ValidationError] {
        draft.validate(existingNames: existing.filter { $0.id != id }.map(\.name))
    }

    private var isInvalid: Bool {
        !validationErrors.isEmpty
    }

    private func loadDraft() {
        guard let id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            draft = try RecipieStore(context: context).draft(id: id)
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func save() {
        do {
            try RecipieStore(context: context).save(draft, id: id)
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
                VStack {
                    Form {
                        Section {
                            TextInput(text: $draft.name, label: "Name", placeholder: "recipe name")
                            if let validationError = validationErrors.first {
                                Text(validationError.localizedDescription)
                                    .foregroundStyle(.red)
                            }
                        }
                        Section("Details") {
                            TextInput(text: $draft.summary, label: "Summary", placeholder: "A basic description", multiline: true)
                            IntegerInput(number: $draft.serves, label: "Serves", placeholder: "number of portions")
                            IntegerInput(number: $draft.time, label: "Time", placeholder: "time to cook (minutes)", step: 5)
                        }
                        Section("Ingredients") {
                            ForEach(draft.ingredients) { ingredient in
                                NavigationLink(value: ingredient) {
                                    let item = items.first(where: { $0.id == ingredient.itemID })
                                    let unit = units.first(where: { $0.id == ingredient.unitID })
                                    Text("\(item?.name ?? "Unknown item"): \(unit?.toString(forValue: ingredient.quantity) ?? "\(ingredient.quantity)")")
                                }
                            }
                            .onDelete { offsets in draft.ingredients.remove(atOffsets: offsets) }
                            if let item = items.first, let unit = units.first {
                                NavigationLink(value: RecipieIngredientDraft(itemID: item.id, unitID: unit.id, quantity: 1)) {
                                    Text("Add").foregroundColor(.accent)
                                }
                            }
                        }
                        Section("Steps") {
                            AddButton { }
                        }
                    }
                    Button(action: save) {
                        Text(isEditing ? "Save" : "Add")
                    }
                    .disabled(editMode.isEditing || isInvalid)
                }
            }
        }
        .toolbar { EditButton() }
        .environment(\.editMode, $editMode)
        .navigationTitle("Recipe")
        .navigationDestination(for: RecipieIngredientDraft.self) { ingredient in
            RecipieIngredientEdit(
                edit: draft.ingredients.contains(where: { $0.id == ingredient.id }),
                value: ingredient,
                items: items,
                units: units
            ) { updated in
                if let index = draft.ingredients.firstIndex(where: { $0.id == updated.id }) {
                    draft.ingredients[index] = updated
                } else {
                    draft.ingredients.append(updated)
                }
            }
        }
        .task(id: id) { loadDraft() }
        .alert("Recipe", isPresented: Binding(
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
        RecipieEdit(type: .dinner)
    }
    .modelContainer(Models.testing.modelContainer)
}
