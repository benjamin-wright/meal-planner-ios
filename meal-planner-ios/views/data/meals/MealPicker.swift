//
//  MealPicker.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 09/08/2026.
//

import SwiftUI
import SwiftData

struct MealPicker: View {
    @Environment(FlowRouter.self) private var router

    let meals: [Meal]
    let selectedID: UUID?
    let onSelect: (UUID) -> Void
    @State private var search = ""
    @State private var mealType: MealType

    init(meals: [Meal], selectedID: UUID?, initialMealType: MealType = .dinner, onSelect: @escaping (UUID) -> Void) {
        self.meals = meals
        self.selectedID = selectedID
        self.onSelect = onSelect
        self._mealType = State(initialValue: initialMealType)
    }

    private var filteredMeals: [Meal] {
        meals.filter {
            $0.mealType == mealType &&
            (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack {
            EnumPicker(label: "Meal", selection: $mealType)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            GlassList {
                ForEach(filteredMeals) { meal in
                    SelectionRow(title: meal.name, isSelected: meal.id == selectedID) {
                        onSelect(meal.id)
                    }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") {
                    router.showCreation(.meal(mealType), onCreate: onSelect)
                }
            }
        }
        .navigationTitle("Meal")
    }
}

#Preview {
    struct Preview: View {
        @Query() private var meals: [Meal]
        @State private var selectedID: UUID = UUID()

        var body: some View {
            FlowContainer {
                MealPicker(
                    meals: meals,
                    selectedID: selectedID,
                    onSelect: { selectedID = $0 }
                )
            }
        }
    }

    return Preview()
        .modelContainer(Models.testing.modelContainer)
}
