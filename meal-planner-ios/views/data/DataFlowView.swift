//
//  DataFlowView.swift
//  meal-planner-ios
//

import SwiftUI

struct DataFlowView: View {
    var body: some View {
        FlowContainer {
            DataView()
        }
    }
}

#Preview {
    DataFlowView().modelContainer(Models.testing.modelContainer)
}
