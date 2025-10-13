//
//  RecipiesView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 06/10/2025.
//

import SwiftUI
import SwiftData

struct RecipiesView: View {
    var body: some View {
        TabbedStack(pages: [
            TabPage(
                title: "Dinner",
                content: AnyView(RecipiesFilteredView(type: .dinner))
            ),
            TabPage(
                title: "Lunch",
                content: AnyView(RecipiesFilteredView(type: .lunch))
            ),
            TabPage(
                title: "Breakfast",
                content: AnyView(RecipiesFilteredView(type: .breakfast))
            ),
        ])
        .navigationTitle("Recipies")
    }
}

#Preview {
    NavigationStack {
        RecipiesView().modelContainer(Models.testing.modelContainer)
    }
}
