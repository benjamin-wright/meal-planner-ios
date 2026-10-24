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
    private let models: Models

    init() {
        GlassChrome.configure()
        #if DEBUG
        models = UITestConfiguration.models() ?? Models.shared
        #else
        models = Models.shared
        #endif
    }

    var body: some Scene {
        WindowGroup {
            MealPlannerView()
        }
        .modelContainer(models.modelContainer)
    }
}
