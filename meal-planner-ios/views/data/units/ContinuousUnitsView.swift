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
                        edit: true,
                        unit: unit,
                        existing: units,
                        action: {
                            try! context.save()
                        },
                    ).onDisappear {
                        context.rollback()
                    }
                } label: {
                    Text(unit.name)
                }
            }.onDelete { offsets in
                for (index, unit) in units.enumerated() {
                    if offsets.contains(index) {
                        context.delete(unit)
                    }
                }
            }
            Section {
                NavigationLink {
                    var unit = ContinuousUnit(
                        name: "",
                        type: unitType,
                        base: 1,
                        magnitudes: []
                    )
                    ContinuousUnitEdit(
                        unit: unit,
                        existing: units,
                        action: {
                            context.insert(unit)
                            try! context.save()
                            unit = ContinuousUnit(
                                name: "",
                                type: unitType,
                                base: 1,
                                magnitudes: []
                            )
                        }
                    ).onDisappear {
                        unit.name = ""
                        unit.base = 1
                        unit.magnitudes = []
                    }
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
        ContinuousUnitsView(
            type: .weight
        ).modelContainer(Models.testing.modelContainer)
    }
}
