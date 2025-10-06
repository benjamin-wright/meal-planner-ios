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
            TabPage(title: "Count", content: AnyView(CountUnitsView())),
            TabPage(title: "Weight", content: AnyView(ContinuousUnitsView(type: .weight))),
            TabPage(title: "Volume", content: AnyView(ContinuousUnitsView(type: .volume))),
        ])
    }
}

#Preview {
    NavigationStack {
        UnitsView().modelContainer(Models.testing.modelContainer)
    }
}
