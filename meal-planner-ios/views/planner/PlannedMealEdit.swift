import SwiftUI
import SwiftData

struct PlannedMealEdit: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(FlowRouter.self) private var router

    private let id: UUID?
    @State private var mealType: MealType
    @State private var day: Day?
    @State private var sourceMealID: UUID?
    @State private var draft: PlannedMealDraft
    @State private var isLoading = false
    @State private var saveError: String?
    @State private var editMode: EditMode = .inactive
    @Query private var plannedMeals: [PlannedMeal]
    @Query private var meals: [Meal]
    @Query private var recipies: [Recipie]
    @Query private var items: [Item]

    init(id: UUID? = nil, mealType: MealType = .dinner, day: Day? = nil) {
        self.id = id
        self._mealType = State(initialValue: mealType)
        self._day = State(initialValue: day)
        self._sourceMealID = State(initialValue: nil)
        self._draft = State(initialValue: PlannedMealDraft())
    }

    private var title: String {
        day.map { "\($0.label) Dinner" } ?? mealType.label
    }

    private var validationErrors: [PlannedMealDraft.ValidationError] {
        draft.validate()
    }

    private func load() {
        guard let id else { return }
        guard let plannedMeal = plannedMeals.first(where: { $0.id == id }) else {
            saveError = PlannedMealStore.Error.notFound.localizedDescription
            return
        }
        do {
            draft = try PlannedMealStore(context: context).draft(id: id)
            mealType = plannedMeal.mealTypeEnum
            day = plannedMeal.dayEnum
            sourceMealID = plannedMeal.sourceMealID
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func chooseTemplate() {
        router.showPlannerMealPicker(mealType: mealType) { selectedID in
            guard let template = meals.first(where: { $0.id == selectedID }) else { return }
            draft = PlannedMealDraft(meal: template)
            mealType = template.mealType
            sourceMealID = template.id
        }
    }

    private func save() {
        do {
            try PlannedMealStore(context: context).save(
                draft,
                id: id,
                mealType: mealType,
                day: day,
                sourceMealID: sourceMealID
            )
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func saveAsMeal() {
        let mealDraft = MealDraft(plannedMeal: draft, mealType: mealType)
        router.path.append(.newMealDraft(mealDraft))
    }

    private func dishes(for course: CourseType) -> [(DishID, String)] {
        draft.dishes.compactMap { dish in
            switch dish {
            case .recipe(let id):
                guard let recipie = recipies.first(where: { $0.id == id }), recipie.courseEnum == course else { return nil }
                return (dish, recipie.name)
            case .readymeal(let id):
                guard let item = items.first(where: { $0.id == id }),
                      item.itemKind == .readymeal,
                      item.readymealData?.courseEnum == course else { return nil }
                return (dish, item.name)
            }
        }
    }

    private func addDish(course: CourseType) {
        router.showDishPicker(
            selectedID: .recipe(UUID()),
            courseFilter: course,
            mealFilter: mealType
        ) { dish in
            guard !draft.dishes.contains(dish) else { return }
            draft.dishes.append(dish)
        }
    }

    private func courseSection(_ course: CourseType) -> some View {
        let courseDishes = dishes(for: course)
        return Section {
            ForEach(courseDishes, id: \.0) { dish, name in
                HStack {
                    Text(name)
                    Spacer()
                    if case .readymeal = dish {
                        Image(systemName: "microwave")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                let deleted = offsets.map { courseDishes[$0].0 }
                draft.dishes.removeAll { deleted.contains($0) }
            }
        } header: {
            HStack {
                Text(course.label)
                Spacer()
                Button { addDish(course: course) } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel("Add \(course.label) dish")
                }
                .disabled(editMode.isEditing)
            }
        }
    }

    var body: some View {
        GlassForm {
            Section("Details") {
                if let validationError = validationErrors.first {
                    Text(validationError.localizedDescription)
                        .foregroundStyle(.red)
                }
                IntegerInput(number: $draft.servings, label: "Servings", placeholder: "servings")
                Button("Choose Saved Meal", action: chooseTemplate)
            }
            courseSection(.starter)
            courseSection(.main)
            courseSection(.side)
            courseSection(.dessert)
            HStack(spacing: 12) {
                Button(action: save) {
                    Text(id == nil ? "Add" : "Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)

                Button(action: saveAsMeal) {
                    Image(systemName: "square.and.arrow.down")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Save as Meal")
                .accessibilityHint("Opens a new saved meal with these dishes pre-filled")
            }
            .disabled(editMode.isEditing || !validationErrors.isEmpty)
        }
        .toolbar { EditButton() }
        .environment(\.editMode, $editMode)
        .navigationTitle(title)
        .onFirstAppear(perform: load, loading: $isLoading)
        .alert("Planned Meal", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }
}
