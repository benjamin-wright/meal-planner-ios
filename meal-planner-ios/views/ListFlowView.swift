//
//  ListFlowView.swift
//  meal-planner-ios
//

import SwiftUI

struct ListFlowView: View {
    var body: some View {
        FlowContainer {
            Text("List")
        }
    }
}

#Preview {
    ListFlowView().modelContainer(Models.testing.modelContainer)
}
