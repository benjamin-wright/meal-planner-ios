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
                NavigationLink(unit.name, value: unit)
                    .onChange(of: units) {}
            }.onDelete { offsets in
                for (index, unit) in units.enumerated() {
                    if offsets.contains(index) {
                        context.delete(unit)
                    }
                }
            }
            Section {
                NavigationLink(value: ContinuousUnit(
                    name: "",
                    type: unitType,
                    base: 1,
                    magnitudes: []
                )) {
                    Text("Add").foregroundStyle(.accent)
                }
            }
        }
        .toolbar {
            EditButton()
        }
        .navigationDestination(for: ContinuousUnit.self) { unit in
            ContinuousUnitEdit(
                unit: unit,
                existing: units,
                action: {
                    if !units.contains(where: { $0.id == unit.id }) {
                        context.insert(unit)
                    }
                    try! context.save()
                }
            ).onDisappear {
                context.rollback()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ContinuousUnitsView(
            type: .weight
        ).modelContainer(Models.testing.modelContainer)
    }
}
