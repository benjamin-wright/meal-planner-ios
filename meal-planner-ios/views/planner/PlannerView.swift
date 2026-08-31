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
    @State private var section: PlannerSection = .dinner

    var body: some View {
        VStack(spacing: 0) {
            EnumPicker(label: "Plan", selection: $section)
                .pickerStyle(.segmented)
                .glassControl()
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
    }
}

private struct DinnerPlannerView: View {
    @Environment(\.modelContext) private var context
    @Query private var meals: [PlannedMeal]
    @State private var saveError: String?

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

    private func move(from: IndexSet, to: Int) {
        guard let fromIndex = from.first,
              Day.allCases.indices.contains(fromIndex) else { return }

        // `to` is calculated after SwiftUI removes the source row.
        let destinationIndex = to > fromIndex ? to - 1 : to
        guard Day.allCases.indices.contains(destinationIndex) else { return }

        do {
            let fromDay = Day.allCases[fromIndex]
            let toDay = Day.allCases[destinationIndex]

            try PlannedMealStore(context: context).moveDinner(from: fromDay, to: toDay)
        } catch {
            saveError = error.localizedDescription
        }
    }

    var body: some View {
        GlassList {
            ForEach(Day.allCases, id: \.rawValue) { day in
                if let meal = meal(for: day) {
                    NavigationLink(value: FlowRouter.Route.editPlannedMeal(meal.id)) {
                        HStack(spacing: 12) {
                            DayBadge(day: day)
                            Text(meal.displayName)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) { delete(meal) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } else {
                    NavigationLink(value: FlowRouter.Route.newPlannedMeal(mealType: .dinner, day: day)) {
                        HStack(spacing: 12) {
                            DayBadge(day: day)
                            Text("Add dinner")
                                .foregroundStyle(.tint)
                        }
                    }
                    .accessibilityLabel("Add dinner for \(day.label)")
                }
            }.onMove(perform: move)
        }
        .toolbar {
            EditButton()
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
