//
//  MealPicker.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 09/08/2026.
//

import SwiftUI
import SwiftData

struct MealPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FlowRouter.self) private var router

    let meals: [Meal]
    @Binding var selectedID: UUID
    @State private var search = ""
    @State private var mealType: MealType

    init(meals: [Meal], selectedID: Binding<UUID>, initialMealType: MealType = .dinner) {
        self.meals = meals
        self._selectedID = selectedID
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
                .pickerStyle(.segmented)
                .glassControl()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            GlassList {
                ForEach(filteredMeals) { meal in
                    Button {
                        router.selectMeal(meal.id)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(meal.name)
                            }
                            Spacer()
                            if meal.id == selectedID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") {
                    router.path.append(.newMeal(mealType))
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
                    selectedID: $selectedID
                )
            }
        }
    }

    return Preview()
        .modelContainer(Models.testing.modelContainer)
}
