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
    private var isEditing: Bool { id != nil }

    @State private var draft: MealDraft
    @State private var isLoading = false
    @State private var saveError: String?
    @Query private var existingMeals: [Meal]
    @Query private var recipies: [Recipie]
    @Query private var items: [Item]
    @Query private var units: [Unit]
    @State private var editMode: EditMode = .inactive
    @State private var isReorderingComponents = false
    @State private var componentScroller = MealComponentScrollController()

    init(id: UUID? = nil, mealType: MealType) {
        self.id = id
        self._draft = State(initialValue: MealDraft(mealType: mealType))
    }

    init(draft: MealDraft) {
        self.id = nil
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
            if !isEditing, router.completeCreation(id: savedID) { return }
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func newDish(course: CourseType) {
        router.showDishPicker(course: course) { component in
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
        Group {
            if isLoading {
                ProgressView()
            } else {
                GeometryReader { geometry in
                    GlassForm {
                        Section("Details") {
                            TextInput(text: $draft.name, label: "Name", placeholder: "meal name")
                                .background(MealComponentScrollProbe(controller: componentScroller))
                            EnumPicker(label: "Meal", selection: $draft.mealType)
                            if let validationError = validationErrors.first {
                                Text(validationError.localizedDescription)
                                    .foregroundStyle(.red)
                            }
                        }

                        MealComponentsEditor(
                            components: $draft.components,
                            isEditing: editMode.isEditing,
                            recipies: recipies,
                            items: items,
                            units: units,
                            onAdd: newDish,
                            onEditPortion: editComponent,
                            onReorderingChanged: { isReorderingComponents = $0 },
                            viewport: geometry.frame(in: .global),
                            scrollBy: { componentScroller.scroll(by: $0) }
                        )

                        Button(isEditing ? "Save" : "Add", action: save)
                            .disabled(editMode.isEditing || !validationErrors.isEmpty)
                    }
                    .scrollDisabled(isReorderingComponents)
                }
            }
        }
        .toolbar { EditButton() }
        .environment(\.editMode, $editMode)
        .navigationTitle("Meal")
        .onFirstAppear(perform: loadDraft, loading: $isLoading)
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
