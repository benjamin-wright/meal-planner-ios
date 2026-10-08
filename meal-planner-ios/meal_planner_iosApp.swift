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
    init() {
        GlassChrome.configure()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-recipe-experiment") {
                RecipieExperimentView()
            } else {
                MealPlannerView()
            }
            #else
            MealPlannerView()
            #endif
        }
        .modelContainer(Models.shared.modelContainer)
    }
}
