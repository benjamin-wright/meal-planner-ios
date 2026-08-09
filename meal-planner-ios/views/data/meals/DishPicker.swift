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

    init(
        recipies: [Recipie],
        readymeals: [Item],
        selectedID: Binding<DishID>,
        initialCourseFilter: CourseType = .main
    ) {
        self.recipies = recipies
        self.readymeals = readymeals
        self._selectedID = selectedID
        self._courseFilter = State(initialValue: initialCourseFilter)
    }

    private struct Option: Identifiable {
        let dish: DishID
        let name: String
        let kind: String
        let course: CourseType

        var id: DishID { dish }
    }

    private var dishes: [Option] {
        let recipes = recipies.map {
            Option(dish: .recipe($0.id), name: $0.name, kind: "Recipe", course: $0.courseEnum)
        }
        let readyMeals = readymeals
            .filter { $0.itemKind == .readymeal }
            .map {
                Option(
                    dish: .readymeal($0.id),
                    name: $0.name,
                    kind: "Ready Meal",
                    course: $0.readymealData?.courseEnum ?? .main
                )
            }

        return (recipes + readyMeals)
            .filter { $0.course == courseFilter }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack {
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
                                Text(dish.kind)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
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
                    router.path.append(.newRecipie(.dinner))
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
