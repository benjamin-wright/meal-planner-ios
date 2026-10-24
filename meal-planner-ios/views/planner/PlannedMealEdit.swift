import SwiftUI
import SwiftData

struct PlannedMealEdit: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(FlowRouter.self) private var router

    private let id: UUID?
    @State private var mealType: MealType
    @State private var day: Day?
    @State private var draft: PlannedMealDraft
    @State private var saveError: String?
    @Query private var plannedMeals: [PlannedMeal]
    @Query private var recipies: [Recipie]
    @Query private var items: [Item]
    @Query private var units: [Unit]

    init(id: UUID? = nil, mealType: MealType = .dinner, day: Day? = nil) {
        self.id = id
        self._mealType = State(initialValue: mealType)
        self._day = State(initialValue: day)
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
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func chooseMeal() {
        router.showMealDiscovery(mealType: mealType, plannedMealID: id, draft: draft) { selected in
            // The picker supplies dishes; the planner retains its slot and serving count.
            draft = selected
        }
    }

    private func save() {
        do {
            try PlannedMealStore(context: context).save(
                draft,
                id: id,
                mealType: mealType,
                day: day
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

    private func addDish() {
        router.showDishPicker { component in
            draft.components.append(component)
        }
    }

    private func editComponent(_ component: MealComponentDraft) {
        router.showMealComponent(component, isEditing: true, allowsRecipeEditing: true) { updated in
            guard let index = draft.components.firstIndex(where: { $0.id == updated.id }) else { return }
            draft.components[index] = updated
        }
    }

    private func replaceComponent(_ component: MealComponentDraft) {
        router.showDishPicker(initialCourse: component.course) { replacement in
            guard let index = draft.components.firstIndex(where: { $0.id == component.id }) else { return }
            var replacement = replacement
            replacement.id = component.id
            draft.components[index] = replacement
        }
    }

    var body: some View {
        MealComponentsForm(
            components: $draft.components,
            recipies: recipies, items: items, units: units,
            onAdd: addDish, onEdit: editComponent, allowsRecipeEditing: true,
            onReplace: replaceComponent,
            details: {
                Section {
                    if let validationError = validationErrors.first {
                        Text(validationError.localizedDescription).foregroundStyle(.red)
                    }
                    IntegerInput(number: $draft.servings, label: "Servings", placeholder: "servings")
                    Button("Choose a meal", systemImage: "sparkle.magnifyingglass", action: chooseMeal)
                        .accessibilityIdentifier("chooseMeal")
                } header: {
                    GlassSectionHeader(title: "Details")
                }
            },
            actions: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: save) {
                            Text(id == nil ? "Add" : "Save").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderless)
                        Button(action: saveAsMeal) {
                            Image(systemName: "square.and.arrow.down").frame(width: 20, height: 20)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel("Save as Meal")
                        .accessibilityHint("Opens a new saved meal with these dishes pre-filled")
                    }
                    .disabled(!validationErrors.isEmpty)
                    Text("Planning a meal automatically remembers its dishes and courses for future suggestions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        )
        .navigationTitle(title)
        .onFirstAppear(perform: load)
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
