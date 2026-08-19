//
//  DishPicker.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 09/09/2026.
//

import SwiftUI
import SwiftData

struct DishPicker: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FlowRouter.self) private var router

    let recipies: [Recipie]
    let readymeals: [Item]
    @Binding var selectedID: DishID
    @State private var search = ""
    @State private var courseFilter: CourseType
    @State private var mealFilter: MealType

    init(
        recipies: [Recipie],
        readymeals: [Item],
        selectedID: Binding<DishID>,
        initialCourseFilter: CourseType = .main,
        initialMealFilter: MealType = .dinner
    ) {
        self.recipies = recipies
        self.readymeals = readymeals
        self._selectedID = selectedID
        self._courseFilter = State(initialValue: initialCourseFilter)
        self._mealFilter = State(initialValue: initialMealFilter)
    }

    private struct Option: Identifiable {
        let dish: DishID
        let name: String
        let kind: String
        let course: CourseType
        let meal: MealType

        var id: DishID { dish }
    }

    private var dishes: [Option] {
        let recipes = recipies.map {
            Option(dish: .recipe($0.id), name: $0.name, kind: "Recipe", course: $0.courseEnum, meal: $0.mealTypeEnum)
        }
        let readyMeals = readymeals
            .filter { $0.itemKind == .readymeal }
            .map {
                Option(
                    dish: .readymeal($0.id),
                    name: $0.name,
                    kind: "Ready Meal",
                    course: $0.readymealData?.courseEnum ?? .main,
                    meal: $0.readymealData?.mealTypeEnum ?? .dinner
                )
            }

        return (recipes + readyMeals)
            .filter { $0.course == courseFilter }
            .filter { $0.meal == mealFilter }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack {
            Picker("Meal", selection: $mealFilter) {
                ForEach(MealType.allCases, id: \.id) { meal in
                    Text(meal.label).tag(Optional(meal))
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            Picker("Course", selection: $courseFilter) {
                ForEach(CourseType.allCases, id: \.id) { course in
                    Text(course.label).tag(Optional(course))
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            List {
                ForEach(dishes) { dish in
                    Button {
                        router.selectDish(dish.dish)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(dish.name)
                            }
                            Spacer()
                            if dish.kind == "Ready Meal" {
                                Image(systemName: "microwave")
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("Ready meal")
                            }
                            if dish.dish == selectedID {
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
                    router.path.append(.newRecipie(mealFilter, courseFilter))
                }
            }
        }
        .navigationTitle("Dish")
    }
}

private struct DishPickerPreview: View {
    @Query private var recipies: [Recipie]
    @Query private var items: [Item]
    @State private var selectedID: DishID = .recipe(UUID())

    init() {}

    var body: some View {
        FlowContainer {
            DishPicker(
                recipies: recipies,
                readymeals: items,
                selectedID: $selectedID
            )
        }
    }
}

#Preview {
    DishPickerPreview()
        .modelContainer(Models.testing.modelContainer)
}
