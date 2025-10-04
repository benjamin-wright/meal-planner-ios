//
//  ContinuousUnitEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 29/09/2025.
//

import SwiftUI

struct ContinuousUnitEdit: View {
    @Environment(\.dismiss) var dismiss

    @State var edit: Bool
    @State var unit: ContinuousUnit
    @State var existing: [ContinuousUnit]
    var action: () -> Void
    @State private var editMode: EditMode = .inactive
    
    init(edit: Bool = false, unit: ContinuousUnit, existing: [ContinuousUnit], action: @escaping () -> Void) {
        self.unit = unit
        self.existing = existing
        self.action = action
        self.edit = edit
    }
    
    func tableRow(magnitude: Binding<ContinuousUnitMagnitude>, multiple: Bool) -> AnyView {
        AnyView(HStack {
            TextInput(text: magnitude.abbreviation, placeholder: "abbreviation", alignment: .center).frame(maxWidth: .infinity)
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
        })
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
                        Text("Abbr").frame(maxWidth: .infinity)
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
                            tableRow(magnitude: magnitude, multiple: unit.magnitudes.count > 1)
                        }
                    }.onDelete { index in
                        unit.magnitudes.remove(atOffsets: index)
                        
                        if unit.magnitudes.count == 1 {
                            unit.magnitudes[0].multiplier = 1
                        }
                    }
                    
                    Button {
                        unit.magnitudes.append(ContinuousUnitMagnitude(abbreviation: "", singular: "", plural: "", multiplier: 1))
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "plus")
                            Spacer()
                        }
                    }.disabled(editMode.isEditing)
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
    }
}

#Preview {
    NavigationStack {
        let unit = ContinuousUnit(
            name: "grams",
            type: .weight,
            base: 1,
            magnitudes: [
                ContinuousUnitMagnitude(
                    abbreviation: "g",
                    singular: "gram",
                    plural: "grams",
                    multiplier: 1
                ),
                ContinuousUnitMagnitude(
                    abbreviation: "kg",
                    singular: "kilogram",
                    plural: "kilograms",
                    multiplier: 1000
                )
            ]
        )
        ContinuousUnitEdit(
            unit: unit,
            existing: [unit],
            action: {
                print(unit.name)
            }
        )
    }
}
