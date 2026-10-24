import SwiftUI
import SwiftData

enum PlannerSection: CaseIterable, LabeledEnum {
    case dinner
    case lunch
    case breakfast
    case misc

    var id: Self { self }

    var label: String {
        switch self {
        case .dinner: "Dinner"
        case .lunch: "Lunch"
        case .breakfast: "Breakfast"
        case .misc: "Misc"
        }
    }
}

struct PlannerView: View {
    @Environment(\.modelContext) private var context
    @Query private var plannedMeals: [PlannedMeal]
    @Query private var miscEntries: [PlannedMiscEntry]
    @State private var section: PlannerSection = .dinner
    @State private var confirmingClear = false
    @State private var clearError: String?

    private func clearPlan() {
        do {
            try PlannerStore(context: context).clear()
        } catch {
            clearError = error.localizedDescription
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            EnumPicker(label: "Plan", selection: $section)
                .padding(.horizontal, 32)

            switch section {
            case .dinner:
                DinnerPlannerView()
            case .lunch:
                PlannedMealListView(mealType: .lunch)
            case .breakfast:
                PlannedMealListView(mealType: .breakfast)
            case .misc:
                MiscPlannerView()
            }
        }
        .navigationTitle("Planner")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear Plan", role: .destructive) {
                    confirmingClear = true
                }
                .disabled(plannedMeals.isEmpty && miscEntries.isEmpty)
            }
        }
        .confirmationDialog("Clear plan?", isPresented: $confirmingClear) {
            Button("Clear Plan", role: .destructive, action: clearPlan)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all planned meals and miscellaneous entries. Saved meals, recipes, and the shopping list will remain.")
        }
        .alert("Could not clear plan", isPresented: Binding(
            get: { clearError != nil },
            set: { if !$0 { clearError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(clearError ?? "")
        }
    }
}

private struct DinnerPlannerView: View {
    @Environment(\.modelContext) private var context
    @Environment(FlowRouter.self) private var router
    @Query private var meals: [PlannedMeal]
    @State private var saveError: String?
    @State private var targetedDay: Day?

    private func meal(for day: Day) -> PlannedMeal? {
        meals.first { $0.mealTypeEnum == .dinner && $0.dayEnum == day }
    }

    private func delete(_ meal: PlannedMeal) {
        do {
            try PlannedMealStore(context: context).delete(id: meal.id)
        } catch {
            saveError = error.localizedDescription
        }
    }

    @discardableResult
    private func move(_ id: UUID, to day: Day) -> Bool {
        do {
            try PlannedMealStore(context: context).moveDinner(id: id, to: day)
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Day.allCases, id: \.rawValue) { day in
                    HStack(spacing: 12) {
                        DayBadge(day: day)
                        if let meal = meal(for: day) {
                            Text(meal.displayName)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                                .accessibilityIdentifier("plannedDinner-\(day.label)")
                                .accessibilityHint("Drag to another day to move or swap meals.")
                                .draggable(meal.id.uuidString) {
                                    Text(meal.displayName)
                                        .padding()
                                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                }
                            Menu {
                                Button("Edit", systemImage: "pencil") {
                                    router.path.append(.editPlannedMeal(meal.id))
                                }
                                Menu("Move to…") {
                                    ForEach(Day.allCases.filter { $0 != day }, id: \.rawValue) { destination in
                                        Button(self.meal(for: destination) == nil
                                               ? "Move to \(destination.label)"
                                               : "Swap with \(destination.label)") {
                                            move(meal.id, to: destination)
                                        }
                                    }
                                }
                                Button("Delete", role: .destructive) { delete(meal) }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Actions for \(day.label) dinner")
                            .accessibilityIdentifier("plannedDinnerActions-\(day.label)")
                        } else {
                            Button {
                                router.path.append(.newPlannedMeal(mealType: .dinner, day: day))
                            } label: {
                                Text("Add dinner")
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Add dinner for \(day.label)")
                        }
                    }
                    .frame(minHeight: 44)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .background(targetedDay == day ? Color.accentColor.opacity(0.15) : Color.clear)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("dinnerDay-\(day.label)")
                    .dropDestination(for: String.self) { values, _ in
                        guard values.count == 1, let id = UUID(uuidString: values[0]) else { return false }
                        return move(id, to: day)
                    } isTargeted: { targeted in
                        if targeted { targetedDay = day }
                        else if targetedDay == day { targetedDay = nil }
                    }
                    if day != Day.allCases.last {
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .glassSurface()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .alert("Dinner", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }
}

private struct DayBadge: View {
    let day: Day

    var body: some View {
        Text(day.shortLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tint)
            .frame(width: 36, height: 36)
            .background(.tint.opacity(0.15), in: Circle())
            .accessibilityLabel(day.label)
    }
}

private struct PlannedMealListView: View {
    @Environment(\.modelContext) private var context
    let mealType: MealType
    @Query private var meals: [PlannedMeal]
    @State private var saveError: String?

    private var displayedMeals: [PlannedMeal] {
        meals.filter { $0.mealTypeEnum == mealType && $0.dayEnum == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func delete(at offsets: IndexSet) {
        do {
            let store = PlannedMealStore(context: context)
            for index in offsets {
                try store.delete(id: displayedMeals[index].id)
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    var body: some View {
        GlassList {
            ForEach(displayedMeals) { meal in
                NavigationLink(meal.displayName, value: FlowRouter.Route.editPlannedMeal(meal.id))
            }
            .onDelete(perform: delete)
            Section {
                NavigationLink(value: FlowRouter.Route.newPlannedMeal(mealType: mealType, day: nil)) {
                    Label("Add \(mealType.label.lowercased())", systemImage: "plus")
                        .foregroundStyle(.tint)
                }
            }
        }
        .toolbar { EditButton() }
        .alert(mealType.label, isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }
}

private struct MiscPlannerView: View {
    @Environment(\.modelContext) private var context
    @Query private var entries: [PlannedMiscEntry]
    @State private var saveError: String?

    private var displayedEntries: [PlannedMiscEntry] {
        entries.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func delete(at offsets: IndexSet) {
        do {
            let store = PlannedMiscStore(context: context)
            for index in offsets {
                try store.delete(id: displayedEntries[index].id)
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    var body: some View {
        GlassList {
            ForEach(displayedEntries) { entry in
                NavigationLink(value: FlowRouter.Route.editPlannedMisc(entry.id)) {
                    HStack {
                        Text(entry.displayName)
                        if entry.item != nil {
                            Image(systemName: "shippingbox")
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Saved item")
                        }
                    }
                }
            }
            .onDelete(perform: delete)
            Section {
                NavigationLink(value: FlowRouter.Route.newPlannedMisc) {
                    Label("Add item or note", systemImage: "plus")
                        .foregroundStyle(.tint)
                }
            }
        }
        .toolbar { EditButton() }
        .alert("Misc", isPresented: Binding(
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
    PlannerFlowView().modelContainer(Models.testing.modelContainer)
}
