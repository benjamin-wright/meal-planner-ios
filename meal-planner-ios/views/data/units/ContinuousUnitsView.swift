//
//  ContinuousUnitsView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 28/09/2025.
//

import SwiftUI
import SwiftData

struct ContinuousUnitsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    
    @Query private var units: [ContinuousUnit]
    @State var unitType: ContinuousUnitType
    
    init(type: ContinuousUnitType) {
        self.unitType = type
        
        _units = Query(filter: #Predicate { $0.type == type.rawValue })
    }
    
    var body: some View {
        return List {
            ForEach(units) { unit in
                NavigationLink {
                    ContinuousUnitEdit(
                        unit: unit,
                        existing: units.map { unit in
                            return unit.name
                        },
                        action: { updated in
                            unit.update(updated: updated)
                        },
                        edit: true,
                    )
                } label: {
                    Text(unit.name)
                }
            }.onDelete { offsets in
                print("Deleting - \(offsets.count)")
                for (index, unit) in units.enumerated() {
                    if offsets.contains(index) {
                        context.delete(unit)
                    }
                }
            }
            Section {
                NavigationLink {
                    ContinuousUnitEdit(
                        unit: ContinuousUnit(
                            name: "",
                            type: unitType,
                            base: 1,
                            magnitudes: []
                        ),
                        existing: units.map { unit in
                            return unit.name
                        },
                        action: { unit in
                            context.insert(unit)
                        }
                    )
                } label: {
                    Text("Add").foregroundStyle(.accent)
                }
            }
        }
        .toolbar {
            EditButton()
        }
    }
}

#Preview {
    NavigationView {
        ContinuousUnitsView(type: .weight).modelContainer(Models.testing.modelContainer)
    }
}
