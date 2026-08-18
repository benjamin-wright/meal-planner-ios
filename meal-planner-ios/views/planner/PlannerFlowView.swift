//
//  PlannerFlowView.swift
//  meal-planner-ios
//

import SwiftUI

struct PlannerFlowView: View {
    var body: some View {
        FlowContainer {
            PlannerView()
        }
    }
}

#Preview {
    PlannerFlowView().modelContainer(Models.testing.modelContainer)
}
