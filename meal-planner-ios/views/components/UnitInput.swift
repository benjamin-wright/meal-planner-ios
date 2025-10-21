//
//  UnitInput.swift
//  meal-planner-ios
//
//  Created by Benjamin Peter Wright on 16/10/2025.
//

import SwiftUI

struct UnitInput: View {
    @State var label: String
    @Binding var unit: Measure
    @Binding var value: Double
    @State var adjusted: Double
    @State var magnitude: Magnitude?
    
    init(label: String, unit: Binding<Measure>, value: Binding<Double>, ) {
        self.label = label
        self._unit = unit
        self._value = value
        
        let initialMagnitude = unit.wrappedValue.selectMagnitude(forValue: value.wrappedValue)
        
        self._magnitude = State(initialValue: initialMagnitude)
        self._adjusted = State(initialValue: value.wrappedValue / (initialMagnitude?.multiplier ?? 1.0))
    }
    
    var body: some View {
        HStack {
            NumberInput(number: $adjusted, label: label, placeholder: "", alignment: .trailing)
            if unit.magnitudes.count > 0 {
                Picker("", selection: $magnitude) {
                    ForEach(unit.magnitudes) { magnitude in
                        Text(magnitude.abbreviation == "" ? magnitude.plural : magnitude.abbreviation).tag(magnitude)
                    }
                }.presentationSizing(.fitted)
            }
        }.onChange(of: magnitude) {
            adjusted = value / (self.magnitude?.multiplier ?? 1)
        }.onChange(of: adjusted) {
            value = adjusted * (self.magnitude?.multiplier ?? 1)
        }.onChange(of: unit) {
            magnitude = unit.selectMagnitude(forValue: value)
        }
    }
}

#Preview {
    let unit = Measure(
        name: "litres",
        type: .volume,
        magnitudes: [
            Magnitude(singular: "litre", plural: "litres", multiplier: 1),
            Magnitude(singular: "millilitre", plural: "millilitres", multiplier: 0.001)
        ]
    )
    
    struct Preview: View {
        @State var value: Double = 0.5
        @State var unit: Measure
        @State var magnitude: Magnitude?
        
        var body: some View {
            Form {
                UnitInput(
                    label: "Quantity",
                    unit: $unit,
                    value: $value,
                )
                Text(String(value))
            }
        }
    }
    
    return Preview(unit: unit)
}
