//
//  CountUnitEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 20/09/2025.
//

import SwiftUI

struct CountUnitEdit: View {
    @Environment(\.dismiss) var dismiss

    @State var edit: Bool
    @State var unit: CountUnit
    @State var existing: [CountUnit]
    var action: () -> Void
    
    @State private var editMode: EditMode = .inactive
    
    init(edit: Bool = false, unit: CountUnit, existing: [CountUnit], action: @escaping () -> Void) {
        self.edit = edit
        self.unit = unit
        self.existing = existing
        self.action = action
    }
    
    func tableRow(collective: Binding<CountUnitCollective>, multiple: Bool) -> AnyView {
        AnyView(HStack {
            TextInput(text: collective.singular, placeholder: "singular", alignment: .center).frame(maxWidth: .infinity)
            TextInput(text: collective.plural, placeholder: "plural", alignment: .center).frame(maxWidth: .infinity)
            if multiple {
                NumberInput(number: collective.multiplier, placeholder: "multiplier", alignment: .center).frame(maxWidth: .infinity)
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
            }
            
            Section {
                List {
                    HStack {
                        Text("Singular").frame(maxWidth: .infinity)
                        Text("Plural").frame(maxWidth: .infinity)
                        if unit.collectives.count > 1 {
                            Text("Multiplier").frame(maxWidth: .infinity)
                        }
                    }.alignmentGuide(.listRowSeparatorLeading) { viewDimensions in
                        return 0
                    }.alignmentGuide(.listRowSeparatorTrailing) { viewDimensions in
                        return viewDimensions.width
                    }
                    
                    ForEach($unit.collectives) { collective in
                        Section {
                            tableRow(collective: collective, multiple: unit.collectives.count > 1)
                        }
                    }.onDelete { index in
                        unit.collectives.remove(atOffsets: index)
                        
                        if unit.collectives.count == 1 {
                            unit.collectives[0].multiplier = 1
                        }
                    }
                    
                    AddButton {
                        unit.collectives.append(CountUnitCollective(singular: "", plural: "", multiplier: 1))
                    }
                }
            }
            
            Button {
                action()
                dismiss()
            } label: {
                Text(edit ? "Update" : "Add")
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
        let unit = CountUnit(
            name: "test-unit",
            collectives: [
                CountUnitCollective(
                    singular: "slice",
                    plural: "slices",
                    multiplier: 0.1
                ),
                CountUnitCollective(
                    singular: "loaf",
                    plural: "loaves",
                    multiplier: 1
                )
            ]
        )
        CountUnitEdit(
            unit: unit,
            existing: [
                unit
            ], action: {
                print(unit.name)
            }
        )
    }
}
