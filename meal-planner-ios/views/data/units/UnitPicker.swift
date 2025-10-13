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
    @Binding var selected: Unit?
    @State var units: [Measure]
    @State var search: String = ""
    
    var body: some View {
        Picker(label, selection: $selected) {
            ForEach(units) { unit in
                Text(unit.name).tag(unit)
            }
        }.pickerStyle(.inline)
    }
}

#Preview {
    struct Preview: View {
        @Query var units: [Measure]
        @State var selected: Unit?
        
        var body: some View {
            Form {
                UnitPicker(
                    label: "Unit",
                    selected: $selected,
                    units: units,
                )
            }
        }
    }
    
    return Preview().modelContainer(Models.testing.modelContainer)
}
