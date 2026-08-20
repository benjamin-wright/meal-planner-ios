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
    @State private var editMode: EditMode = .inactive

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
            try MealStore(context: context).save(draft, id: id)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func newDish(course: CourseType, meal: MealType) {
        router.showDishPicker(
            selectedID: .recipe(UUID()),
            courseFilter: course,
            mealFilter: meal
        ) { dish in
            guard !draft.dishes.contains(dish) else { return }
            draft.dishes.append(dish)
        }
    }

    private func dishes(for course: CourseType) -> [(dish: DishID, name: String)] {
        draft.dishes.compactMap { dish in
            switch dish {
            case .recipe(let id):
                guard let recipie = recipies.first(where: { $0.id == id }),
                      recipie.courseEnum == course else { return nil }
                return (dish, recipie.name)
            case .readymeal(let id):
                guard let item = items.first(where: { $0.id == id }),
                      item.itemKind == .readymeal,
                      let data = item.readymealData,
                      data.courseEnum == course else { return nil }
                return (dish, item.name)
            }
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func deleteDishes(at offsets: IndexSet, for course: CourseType) {
        let courseDishes = dishes(for: course)
        let dishesToDelete = offsets.map { courseDishes[$0].dish }
        draft.dishes.removeAll { dishesToDelete.contains($0) }
    }
    
    private func courseRow(course: CourseType) -> some View {
        Section {
            let courseDishes = dishes(for: course)
            if !courseDishes.isEmpty {
                ForEach(courseDishes, id: \.dish) { dish in
                    HStack {
                        Text(dish.name)
                        Spacer()
                        if case .readymeal = dish.dish {
                            Image(systemName: "microwave")
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Ready meal")
                        }
                    }
                }
                .onDelete { offsets in
                    deleteDishes(at: offsets, for: course)
                }
            }
        } header: {
            HStack {
                Text(course.label)
                Spacer()
                Button {
                    newDish(course: course, meal: draft.mealType)
                } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel("Add \(course.label) dish")
                }
                .disabled(editMode.isEditing)
            }
        }
    }
        

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                Form {
                    Section("Details") {
                        TextInput(text: $draft.name, label: "Name", placeholder: "meal name")
                        EnumPicker(label: "Meal", selection: $draft.mealType)
                            .pickerStyle(.segmented)
                        if let validationError = validationErrors.first {
                            Text(validationError.localizedDescription)
                                .foregroundStyle(.red)
                        }
                    }
                    
                    courseRow(course: .starter)
                    courseRow(course: .main)
                    courseRow(course: .side)
                    courseRow(course: .dessert)
                    

                    Button(isEditing ? "Save" : "Add", action: save)
                        .disabled(editMode.isEditing || !validationErrors.isEmpty)
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
