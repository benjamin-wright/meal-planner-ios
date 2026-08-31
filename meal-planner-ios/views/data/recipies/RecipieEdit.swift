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
    @Environment(FlowRouter.self) private var router

    private let id: UUID?
    private var isEditing: Bool { id != nil }

    @State private var draft: RecipieDraft
    @State private var isLoading = false
    @State private var saveError: String?
    @Query private var existing: [Recipie]
    @Query private var units: [Unit]
    @Query private var items: [Item]
    @State private var editMode: EditMode = .inactive

    init(id: UUID? = nil, mealType: MealType, courseType: CourseType) {
        self.id = id
        self._draft = State(initialValue: RecipieDraft(mealType, courseType))
    }

    private var validationErrors: [RecipieDraft.ValidationError] {
        draft.validate(existingNames: existing.filter { $0.id != id }.map(\.name))
    }

    private var isInvalid: Bool {
        !validationErrors.isEmpty
    }

    private func loadDraft() {
        guard let id else { return }
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
    
    private func addStep() {
        draft.steps.append("")
    }
    
    var detailsSection: some View {
        Section("Details") {
            TextInput(text: $draft.summary, label: "Summary", placeholder: "A basic description", multiline: true)
            EnumPicker(label: "Meal", selection: $draft.mealType).pickerStyle(.segmented)
            EnumPicker(label: "Course", selection: $draft.course).pickerStyle(.segmented)
            IntegerInput(number: $draft.serves, label: "Serves", placeholder: "number of portions")
            IntegerInput(number: $draft.time, label: "Time", placeholder: "time to cook (minutes)", step: 5)
        }
    }
    
    var ingredientsSection: some View {
        Section("Ingredients") {
            ForEach(draft.ingredients) { ingredient in
                Button {
                    router.showRecipieIngredient(ingredient, isEditing: true) { updated in
                        if let index = self.draft.ingredients.firstIndex(where: { $0.id == updated.id }) {
                            self.draft.ingredients[index] = updated
                        }
                    }
                } label: {
                    let item = items.first(where: { $0.id == ingredient.itemID })
                    let unit = units.first(where: { $0.id == ingredient.unitID })
                    Text("\(item?.name ?? "Unknown item"): \(unit?.toString(forValue: ingredient.quantity) ?? "\(ingredient.quantity)")")
                }
            }
            .onDelete { offsets in draft.ingredients.remove(atOffsets: offsets) }
            if let item = items.first, let unit = units.first {
                Button {
                    router.showRecipieIngredient(
                        RecipieIngredientDraft(itemID: item.id, unitID: unit.id, quantity: 1),
                        isEditing: false
                    ) { ingredient in
                        self.draft.ingredients.append(ingredient)
                    }
                } label: {
                    Text("Add").foregroundColor(.accent)
                }
            }
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                VStack {
                    GlassForm {
                        Section {
                            TextInput(text: $draft.name, label: "Name", placeholder: "recipe name")
                            if let validationError = validationErrors.first {
                                Text(validationError.localizedDescription)
                                    .foregroundStyle(.red)
                            }
                        }
                        detailsSection
                        ingredientsSection
                        Section("Steps") {
                            ForEach($draft.steps.enumerated(), id: \.offset) { index, step in
                                TextInput(text: step, label: "\(index)", placeholder: "Step \(index)")
                            }
                            .onDelete { offsets in draft.steps.remove(atOffsets: offsets) }
                            AddButton(addStep)
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
        .onFirstAppear(perform: loadDraft, loading: $isLoading)
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
    FlowContainer {
        RecipieEdit(mealType: .lunch, courseType: .starter)
    }
    .modelContainer(Models.testing.modelContainer)
}
