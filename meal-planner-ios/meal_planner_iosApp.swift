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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Category.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MealPlannerView()
        }
        .modelContainer(sharedModelContainer)
    }
}
