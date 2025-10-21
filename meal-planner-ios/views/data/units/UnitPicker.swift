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
    @Binding var selected: Measure
    @State var units: [Measure]
    
    init(
        _ label: String,
        selected: Binding<Measure>,
        units: [Measure]
    ) {
        self.label = label
        self._selected = selected
        self.units = units
    }
    
    var body: some View {
        HStack {
            Text(label)
            VStack {
                Picker("", selection: $selected) {
                    ForEach(units) { unit in
                        Text(unit.name).tag(unit)
                    }
                }
            }
        }
    }
}

#Preview {
    struct Preview: View {
        @Query var units: [Measure]
        
        var body: some View {
            Container(units: units, selected: units[0])
        }
    }
    
    struct Container: View {
        @State var units: [Measure]
        @State var selected: Measure
        
        var body: some View {
            Form {
                UnitPicker(
                    "Unit",
                    selected: $selected,
                    units: units
                )
            }
        }
    }
    
    return Preview().modelContainer(Models.testing.modelContainer)
}
