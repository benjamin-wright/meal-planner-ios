//
//  MealEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 09/08/2026.
//

import SwiftUI
import SwiftData

struct MealEdit: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(FlowRouter.self) private var router

    private let id: UUID?
    private let onCreate: ((UUID) -> Void)?
    private var isEditing: Bool { id != nil }

    @State private var draft: MealDraft
    @State private var saveError: String?
    @Query private var existingMeals: [Meal]
    @Query private var recipies: [Recipie]
    @Query private var items: [Item]
    @Query private var units: [Unit]

    init(id: UUID? = nil, mealType: MealType, onCreate: ((UUID) -> Void)? = nil) {
        self.id = id
        self.onCreate = onCreate
        self._draft = State(initialValue: MealDraft(mealType: mealType))
    }

    init(draft: MealDraft) {
        self.id = nil
        self.onCreate = nil
        self._draft = State(initialValue: draft)
    }

    private var validationErrors: [MealDraft.ValidationError] {
        draft.validate(existingNames: existingMeals.filter { $0.id != id }.map(\.name))
    }

    private func loadDraft() {
        guard let id else { return }
        do {
            draft = try MealStore(context: context).draft(id: id)
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func save() {
        do {
            let savedID = try MealStore(context: context).save(draft, id: id)
            if !isEditing, let onCreate {
                onCreate(savedID)
            } else {
                dismiss()
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func newDish() {
        router.showDishPicker { component in
            draft.components.append(component)
        }
    }

    private func editComponent(_ component: MealComponentDraft) {
        router.showMealComponent(component, isEditing: true) { updated in
            guard let index = draft.components.firstIndex(where: { $0.id == updated.id }) else { return }
            draft.components[index] = updated
        }
    }

    var body: some View {
        MealComponentsForm(
            components: $draft.components,
            recipies: recipies, items: items, units: units,
            onAdd: newDish, onEdit: editComponent,
            details: {
                Section("Details") {
                    TextInput(text: $draft.name, label: "Name", placeholder: "meal name")
                    EnumPicker(label: "Meal", selection: $draft.mealType)
                    if let validationError = validationErrors.first {
                        Text(validationError.localizedDescription).foregroundStyle(.red)
                    }
                }
            },
            actions: {
                Button(isEditing ? "Save" : "Add", action: save)
                    .disabled(!validationErrors.isEmpty)
            }
        )
        .navigationTitle("Meal")
        .onFirstAppear(perform: loadDraft)
        .alert("Meal", isPresented: Binding(
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
        MealEdit(mealType: .dinner)
    }
    .modelContainer(Models.testing.modelContainer)
}
