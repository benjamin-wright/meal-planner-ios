//
//  UnitsView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 20/09/2025.
//

import SwiftUI
import SwiftData

struct CountUnitsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    
    @Query private var units: [CountUnit]
    
    var body: some View {
        return List {
            ForEach(units) { unit in
                NavigationLink {
                    CountUnitEdit(
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
                    var unit = CountUnit(
                        name: ""
                    )
                    CountUnitEdit(
                        unit: unit,
                        existing: units,
                        action: {
                            context.insert(unit)
                            try! context.save()
                            unit = CountUnit(
                                name: ""
                            )
                        }
                    ).onDisappear() {
                        unit.name = ""
                        unit.collectives = []
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
        CountUnitsView().modelContainer(Models.testing.modelContainer)
    }
}
