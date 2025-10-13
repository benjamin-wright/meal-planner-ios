//
//  ContinuousUnitEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 29/09/2025.
//

import SwiftUI

struct MeasureEdit: View {
    @Environment(\.dismiss) var dismiss

    @State var edit: Bool
    @State var unit: Measure
    @State var existing: [Measure]
    var action: () -> Void
    @State private var editMode: EditMode = .inactive
    
    init(edit: Bool = false, unit: Measure, existing: [Measure], action: @escaping () -> Void) {
        self.unit = unit
        self.existing = existing
        self.action = action
        self.edit = edit
    }
    
    func tableRow(magnitude: Binding<Magnitude>, type: UnitType, multiple: Bool) -> AnyView {
        return AnyView(
            HStack {
                if type != .count {
                    TextInput(text: magnitude.abbreviation, placeholder: "abbreviation", alignment: .center).frame(maxWidth: .infinity)
                }
                TextInput(text: magnitude.singular, placeholder: "singular", alignment: .center).frame(maxWidth: .infinity)
                TextInput(text: magnitude.plural, placeholder: "plural", alignment: .center).frame(maxWidth: .infinity)
                if multiple {
                    NumberInput(number: magnitude.multiplier, placeholder: "multiplier", alignment: .center).frame(maxWidth: .infinity)
                }
            }.frame(maxWidth: .infinity)
            .alignmentGuide(.listRowSeparatorLeading) { viewDimensions in
                return 0
            }.alignmentGuide(.listRowSeparatorTrailing) { viewDimensions in
                return viewDimensions.width
            }
        )
    }
    
    var body: some View {
        Form {
            Section {
                TextInput(text: $unit.name, label: "Name", placeholder: "unit name")
                NumberInput(number: $unit.base, label: "Base", placeholder: "base")
            }

            Section {
                List {
                    HStack {
                        if unit.unitType != .count {
                            Text("Abbr").frame(maxWidth: .infinity)
                        }
                        Text("Singular").frame(maxWidth: .infinity)
                        Text("Plural").frame(maxWidth: .infinity)
                        if unit.magnitudes.count > 1 {
                            Text("Multiplier").frame(maxWidth: .infinity)
                        }
                    }.alignmentGuide(.listRowSeparatorLeading) { viewDimensions in
                        return 0
                    }.alignmentGuide(.listRowSeparatorTrailing) { viewDimensions in
                        return viewDimensions.width
                    }
                    
                    ForEach($unit.magnitudes) { magnitude in
                        Section {
                            tableRow(magnitude: magnitude, type: unit.unitType, multiple: unit.magnitudes.count > 1)
                        }
                    }.onDelete { index in
                        unit.magnitudes.remove(atOffsets: index)
                        
                        if unit.magnitudes.count == 1 {
                            unit.magnitudes[0].multiplier = 1
                        }
                    }

                    AddButton {
                        print("hi")
                        unit.magnitudes.append(
                            Magnitude(singular: "", plural: "", multiplier: 1)
                        )
                    }
                }
            }
            
            Button {
                action()
                dismiss()
            } label: {
                Text(edit ? "Save" : "Add")
            }.disabled(editMode.isEditing || !unit.isValid())
        }
        .toolbar {
            EditButton()
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("Unit")
    }
}

#Preview {
    NavigationStack {
        let unit = Measure(
            name: "grams",
            type: .weight,
            base: 1,
            magnitudes: [
                Magnitude(
                    abbreviation: "g",
                    singular: "gram",
                    plural: "grams",
                    multiplier: 1
                ),
                Magnitude(
                    abbreviation: "kg",
                    singular: "kilogram",
                    plural: "kilograms",
                    multiplier: 1000
                )
            ]
        )
        MeasureEdit(
            unit: unit,
            existing: [unit],
            action: {
                print(unit.name)
            }
        )
    }
}
