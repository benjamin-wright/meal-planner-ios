//
//  meal_planner_iosApp.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 09/09/2025.
//

import SwiftUI
import SwiftData

@main
struct meal_planner_iosApp: App {
    var body: some Scene {
        WindowGroup {
            MealPlannerView()
        }
        .modelContainer(Models.shared.modelContainer)
    }
}
