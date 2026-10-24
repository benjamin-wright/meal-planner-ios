//
//  UnitsView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 20/09/2025.
//

import SwiftUI
import SwiftData

struct UnitsView: View {
    @State private var type: UnitType = .count

    var body: some View {
        VStack {
            EnumPicker(label: "Type", selection: $type)
            UnitsSubsetView(type: type)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .navigationTitle("Units")
    }
}

#Preview {
    FlowContainer {
        UnitsView()
    }
    .modelContainer(Models.testing.modelContainer)
}
