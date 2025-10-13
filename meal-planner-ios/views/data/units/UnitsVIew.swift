//
//  UnitsView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 20/09/2025.
//

import SwiftUI
import SwiftData

struct UnitsView: View {
    var body: some View {
        TabbedStack(pages: [
            TabPage(title: "Count", content: AnyView(MeasuresView(type: .count))),
            TabPage(title: "Weight", content: AnyView(MeasuresView(type: .weight))),
            TabPage(title: "Volume", content: AnyView(MeasuresView(type: .volume))),
        ]).navigationTitle("Units")
    }
}

#Preview {
    NavigationStack {
        UnitsView().modelContainer(Models.testing.modelContainer)
    }
}
