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
    private let initialDraft: RecipieDraft?
    private var isEditing: Bool { id != nil }

    @State private var draft: RecipieDraft
    @State private var isLoading = false
    @State private var saveError: String?
    @Query private var existing: [Recipie]
    @Query private var units: [Unit]
    @Query private var items: [Item]
    @State private var editMode: EditMode = .inactive

    init(id: UUID? = nil, type: RecipieType, draft: RecipieDraft? = nil) {
        self.id = id
        self.initialDraft = draft
        self._draft = State(initialValue: draft ?? RecipieDraft(type: type))
    }

    private var isInvalid: Bool {
        !draft.isValid(existingNames: existing.filter { $0.id != id }.map(\.name))
    }

    private func loadDraft() {
        guard initialDraft == nil, let id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            guard let recipie = try context.fetch(Recipie.descriptor(id: id)).first else {
                saveError = "This recipe no longer exists."
                return
            }
            draft = RecipieDraft(recipie: recipie)
        } catch {
            saveError = "Could not load this recipe: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            let recipie: Recipie
            if let id {
                guard let existing = try context.fetch(Recipie.descriptor(id: id)).first else {
                    saveError = "This recipe no longer exists."
                    return
                }
                recipie = existing
            } else {
                recipie = Recipie(type: draft.type)
                context.insert(recipie)
            }
            recipie.name = draft.name
            recipie.type = draft.type.rawValue
            recipie.summary = draft.summary
            recipie.serves = draft.serves
            recipie.time = draft.time
            recipie.steps = draft.steps

            let oldIngredients = recipie.ingredients
            recipie.ingredients = try draft.ingredients.map { ingredientDraft in
                guard let item = try context.fetch(Item.descriptor(id: ingredientDraft.itemID)).first,
                      let unit = try context.fetch(Unit.descriptor(id: ingredientDraft.unitID)).first else {
                    throw NSError(domain: "RecipieEdit", code: 1, userInfo: [NSLocalizedDescriptionKey: "An ingredient or unit no longer exists."])
                }
                if let ingredient = oldIngredients.first(where: { $0.id == ingredientDraft.id }) {
                    ingredient.item = item
                    ingredient.unit = unit
                    ingredient.quantity = ingredientDraft.quantity
                    return ingredient
                }
                return RecipieIngredient(id: ingredientDraft.id, item: item, unit: unit, quantity: ingredientDraft.quantity)
            }
            let retainedIDs = Set(draft.ingredients.map(\.id))
            oldIngredients.filter { !retainedIDs.contains($0.id) }.forEach(context.delete)
            try context.save()
            dismiss()
        } catch {
            saveError = "Could not save this recipe: \(error.localizedDescription)"
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
