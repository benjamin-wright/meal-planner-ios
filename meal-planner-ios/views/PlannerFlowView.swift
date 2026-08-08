//
//  PlannerFlowView.swift
//  meal-planner-ios
//

import SwiftUI

struct PlannerFlowView: View {
    var body: some View {
        FlowContainer {
            Text("Planner")
        }
    }
}

#Preview {
    PlannerFlowView().modelContainer(Models.testing.modelContainer)
}
