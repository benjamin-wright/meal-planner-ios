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
            TabPage(title: "Count", content: {AnyView(UnitsSubsetView(type: .count))}),
            TabPage(title: "Weight", content: {AnyView(UnitsSubsetView(type: .weight))}),
            TabPage(title: "Volume", content: {AnyView(UnitsSubsetView(type: .volume))}),
        ]).navigationTitle("Units")
    }
}

#Preview {
    NavigationStack {
        UnitsView().modelContainer(Models.testing.modelContainer)
    }
}
