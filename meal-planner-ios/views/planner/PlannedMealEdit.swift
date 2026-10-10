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
    @State private var isReorderingComponents = false
    @State private var componentScroller = MealComponentScrollController()
    @Query private var plannedMeals: [PlannedMeal]
    @Query private var recipies: [Recipie]
    @Query private var items: [Item]
    @Query private var units: [Unit]

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
            guard let template = try? context.fetch(Meal.descriptor(id: selectedID)).first else { return }
            // Templates supply dishes while the selected planner slot keeps its type and day.
            draft = PlannedMealDraft(meal: template)
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

    private func addDish(course: CourseType) {
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
        GeometryReader { geometry in
            GlassForm {
                Section {
                    if let validationError = validationErrors.first {
                        Text(validationError.localizedDescription)
                            .foregroundStyle(.red)
                    }
                    IntegerInput(number: $draft.servings, label: "Servings", placeholder: "servings")
                        .background(MealComponentScrollProbe(controller: componentScroller))
                    Button("Choose Saved Meal", action: chooseTemplate)
                } header: {
                    GlassSectionHeader(title: "Details")
                }
                MealComponentsEditor(
                    components: $draft.components,
                    isEditing: editMode.isEditing,
                    recipies: recipies,
                    items: items,
                    units: units,
                    onAdd: addDish,
                    onEditPortion: editComponent,
                    onReorderingChanged: { isReorderingComponents = $0 },
                    viewport: geometry.frame(in: .global),
                    scrollBy: { componentScroller.scroll(by: $0) }
                )
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
            .scrollDisabled(isReorderingComponents)
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
