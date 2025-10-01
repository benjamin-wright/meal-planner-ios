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
    @State var existing: [String]
    private var action: (_ unit: CountUnit) -> Void
    
    let unit: CountUnit
    @State private var actual: CountUnit
    @State private var editMode: EditMode = .inactive
    
    init(unit: CountUnit, existing: [String], action: @escaping (_ unit: CountUnit) -> Void, edit: Bool = false) {
        self.unit = unit
        self.actual = unit.clone()
        self.existing = existing
        self.action = action
        self.edit = edit
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
                TextInput(text: $actual.name, label: "Name", placeholder: "unit name")
            }
            
            Section {
                List {
                    HStack {
                        Text("Singular").frame(maxWidth: .infinity)
                        Text("Plural").frame(maxWidth: .infinity)
                        if actual.collectives.count > 1 {
                            Text("Multiplier").frame(maxWidth: .infinity)
                        }
                    }.alignmentGuide(.listRowSeparatorLeading) { viewDimensions in
                        return 0
                    }.alignmentGuide(.listRowSeparatorTrailing) { viewDimensions in
                        return viewDimensions.width
                    }
                    
                    ForEach($actual.collectives) { collective in
                        Section {
                            tableRow(collective: collective, multiple: actual.collectives.count > 1)
                        }
                    }.onDelete { index in
                        actual.collectives.remove(atOffsets: index)
                        
                        if actual.collectives.count == 1 {
                            actual.collectives[0].multiplier = 1
                        }
                    }
                    
                    Button {
                        actual.collectives.append(CountUnitCollective(singular: "", plural: "", multiplier: 1))
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
        .onAppear {
            actual = unit.clone()
        }
    }
}

#Preview {
    NavigationStack {
        CountUnitEdit(
            unit: CountUnit(
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
            ),
            existing: [
                "grams",
                "litres"
            ], action: { unit in
                print(unit.name)
            }
        )
    }
}
