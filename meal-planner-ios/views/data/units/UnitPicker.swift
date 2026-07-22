//
//  UnitPicker.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 08/10/2025.
//

import SwiftUI
import SwiftData

struct UnitPicker: View {
    let label: String
    @Binding var selectedID: UUID
    @Query(sort: \Unit.name) private var units: [Unit]

    init(label: String, selectedID: Binding<UUID>) {
        self.label = label
        self._selectedID = selectedID
    }
    
    var body: some View {
        Picker(label, selection: $selectedID) {
            ForEach(units) { unit in
                Text(unit.name).tag(unit.id)
            }
        }
    }
}

struct Preview: View {
    @Query private var units: [Unit]
    @State private var selectedID: UUID?
    
    var body: some View {
        if let selectedID {
            Form {
                UnitPicker(label: "Unit", selectedID: Binding(
                    get: { selectedID },
                    set: { self.selectedID = $0 }
                ))
            }
        } else {
            ProgressView()
                .task {
                    selectedID = units.first?.id
                }
        }
    }
}

#Preview {
    let container = Models.testing.modelContainer
    Preview().modelContainer(container)
}
