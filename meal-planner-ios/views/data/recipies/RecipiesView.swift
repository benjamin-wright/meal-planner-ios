//
//  RecipiesView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 06/10/2025.
//

import SwiftUI
import SwiftData

struct RecipiesView: View {
    @State var mealType: MealType = .dinner
    @State var course: CourseType = .main
    
    var body: some View {
        VStack {
            EnumPicker(label: "Meal", selection: $mealType)
                .pickerStyle(.segmented)
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))
            if mealType == .dinner {
                EnumPicker(label: "Course", selection: $course)
                    .pickerStyle(.segmented)
                    .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
            RecipiesFilteredView(mealType: mealType, course: course)
        }
        .navigationTitle("Recipies")
    }
}

#Preview {
    FlowContainer {
        RecipiesView()
    }
    .modelContainer(Models.testing.modelContainer)
}
