//
//  ContentView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 09/09/2025.
//

import SwiftUI
import SwiftData

struct TabData: Identifiable {
    var id: Int
    var name: String
    var component: AnyView
    var image: String
}

var tabs: [TabData] = [
    TabData(id: 1, name: "Data", component: AnyView(DataView()), image: "externaldrive"),
    TabData(id: 2, name: "Planner", component: AnyView(Text("Planner")), image: "calendar"),
    TabData(id: 3, name: "List", component: AnyView(Text("List")), image: "checklist"),
]

struct MealPlannerView: View {
    var body: some View {
        TabView {
            ForEach(tabs) { tab in
                Tab(tab.name, systemImage: tab.image) {
                    tab.component
                }
            }
        }
    }
}

#Preview {
    MealPlannerView().modelContainer(Models.testing.modelContainer)
}
