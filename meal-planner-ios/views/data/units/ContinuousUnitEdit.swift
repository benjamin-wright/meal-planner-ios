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
    @State var existing: [String]
    private var action: (_ unit: ContinuousUnit) -> Void
    
    let unit: ContinuousUnit
    @State private var actual: ContinuousUnit
    @State private var editMode: EditMode = .inactive
    
    init(unit: ContinuousUnit, existing: [String], action: @escaping (_ unit: ContinuousUnit) -> Void, edit: Bool = false) {
        self.unit = unit
        self.actual = unit.clone()
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
        NavigationStack {
            Form {
                Section {
                    TextInput(text: $actual.name, label: "Name", placeholder: "unit name")
                    NumberInput(number: $actual.base, label: "Base", placeholder: "base")
                }
                
                Section {
                    List {
                        HStack {
                            Text("Abbr").frame(maxWidth: .infinity)
                            Text("Singular").frame(maxWidth: .infinity)
                            Text("Plural").frame(maxWidth: .infinity)
                            if actual.magnitudes.count > 1 {
                                Text("Multiplier").frame(maxWidth: .infinity)
                            }
                        }.alignmentGuide(.listRowSeparatorLeading) { viewDimensions in
                            return 0
                        }.alignmentGuide(.listRowSeparatorTrailing) { viewDimensions in
                            return viewDimensions.width
                        }
                        
                        ForEach($actual.magnitudes) { magnitude in
                            Section {
                                tableRow(magnitude: magnitude, multiple: actual.magnitudes.count > 1)
                            }
                        }.onDelete { index in
                            actual.magnitudes.remove(atOffsets: index)
                            
                            if actual.magnitudes.count == 1 {
                                actual.magnitudes[0].multiplier = 1
                            }
                        }
                        
                        Button {
                            actual.magnitudes.append(ContinuousUnitMagnitude(abbreviation: "", singular: "", plural: "", multiplier: 1))
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
                    action(actual)
                    dismiss()
                } label: {
                    Text(edit ? "Save" : "Add")
                }.disabled(editMode.isEditing || !actual.isValid())
            }
            .toolbar {
                EditButton()
            }
            .environment(\.editMode, $editMode)
        }.onAppear {
            actual = unit.clone()
        }
    }
}

#Preview {
    ContinuousUnitEdit(
        unit: ContinuousUnit(
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
        ),
        existing: [
            "grams",
            "litres"
        ], action: { unit in
            print(unit.name)
        }
    )
}
