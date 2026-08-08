//
//  ContentView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 09/09/2025.
//

import SwiftUI
import SwiftData

struct MealPlannerView: View {
    var body: some View {
        TabView {
            Tab("Data", systemImage: "externaldrive") {
                DataFlowView().padding(.bottom, 10)
            }
            Tab("Planner", systemImage: "calendar") {
                PlannerFlowView().padding(.bottom, 10)
            }
            Tab("List", systemImage: "checklist") {
                ListFlowView().padding(.bottom, 10)
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView().padding(.bottom, 10)
            }
        }
    }
}

#Preview {
    MealPlannerView().modelContainer(Models.testing.modelContainer)
}
