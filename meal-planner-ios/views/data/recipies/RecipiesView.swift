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
        RecipiesFilteredView()
            .navigationTitle("Recipies")
    }
}

#Preview {
    FlowContainer {
        RecipiesView()
    }
    .modelContainer(Models.testing.modelContainer)
}
