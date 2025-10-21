//
//  UnitPicker.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 08/10/2025.
//

import SwiftUI
import SwiftData

struct UnitPicker: View {
    @Binding var selected: Measure
    @Binding var value: Double
    @State var units: [Measure]
    @State var magnitude: Magnitude? = nil
    @State var search: String = ""
    
    init(
        selected: Binding<Measure>,
        value: Binding<Double>,
        units: [Measure]
    ) {
        _selected = selected
        _value = value
        units = units
        magnitude = selected.wrappedValue.magnitudes.first
    }
    
    var body: some View {
        HStack {
            NumberInput(
                number: $value,
                placeholder: "value",
                alignment: .trailing
            )
            if selected.magnitudes.count > 0 {
                Picker("", selection: $magnitude) {
                    ForEach(selected.magnitudes) { magnitude in
                        Text(magnitude.abbreviation != "" ? magnitude.abbreviation : magnitude.plural).tag(magnitude)
                        
                    }
                }.pickerStyle(.menu).frame(minWidth: .leastNormalMagnitude)
            }
            Picker("", selection: $selected) {
                ForEach(units) { unit in
                    Text(unit.name).tag(unit)
                }
            }.pickerStyle(.menu)
        }.onChange(of: selected) { _, newValue in
            self.magnitude = selected.magnitudes.first
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
        @State var value: Double = 100
        
        var body: some View {
            Form {
                UnitPicker(
                    selected: $selected,
                    value: $value,
                    units: units
                )
            }
        }
    }
    
    return Preview().modelContainer(Models.testing.modelContainer)
}
