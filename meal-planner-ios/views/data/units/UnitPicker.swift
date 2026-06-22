//
//  UnitPicker.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 08/10/2025.
//

import SwiftUI
import SwiftData

struct UnitPicker: View {
    @State var label: String
    @Binding var selected: Unit
    @State var units: [Unit]
    @State var search: String = ""
    
    var body: some View {
        Picker(label, selection: $selected) {
            ForEach(units) { unit in
                Text(unit.name).tag(unit)
            }
        }
    }
}

struct Preview: View {
    @Query private var units: [Unit]
    @State var selected: Unit
    
    var body: some View {
        Form {
            UnitPicker(
                label: "Unit",
                selected: $selected,
                units: units,
                search: ""
            )
        }
    }
}

#Preview {
    let container = Models.testing.modelContainer
    Preview(selected: Unit(name: "Preview", type: .weight, magnitudes: [Magnitude(singular: "unit", plural: "units", multiplier: 1)])).modelContainer(container)
}
