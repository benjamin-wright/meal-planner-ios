//
//  DataView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 19/09/2025.
//


import SwiftUI
import SwiftData

struct DataView: View {
    @Environment(FlowRouter.self) private var router

    var body: some View {
        List {
            NavigationLink("Units", value: FlowRouter.Route.units)
            NavigationLink("Categories", value: FlowRouter.Route.categories)
            NavigationLink("Items", value: FlowRouter.Route.items)
            NavigationLink("Recipies", value: FlowRouter.Route.recipies)
        }
        .navigationTitle("Data")
    }
}

#Preview {
    DataFlowView().modelContainer(Models.testing.modelContainer)
}
