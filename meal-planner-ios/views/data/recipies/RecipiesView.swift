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
            VStack(spacing: 8) {
                EnumPicker(label: "Meal", selection: $mealType)
                    .pickerStyle(.segmented)
                    .glassControl()
                EnumPicker(label: "Course", selection: $course)
                    .pickerStyle(.segmented)
                    .glassControl()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

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
