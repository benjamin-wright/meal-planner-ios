//
//  ContinuousUnitsView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 28/09/2025.
//

import SwiftUI
import SwiftData

struct MeasuresView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    
    @Query private var units: [Measure]
    @State var unitType: UnitType
    
    init(type: UnitType) {
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
                NavigationLink(value: Measure(
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
        .navigationDestination(for: Measure.self) { unit in
            MeasureEdit(
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
        MeasuresView(
            type: .weight
        ).modelContainer(Models.testing.modelContainer)
    }
}
