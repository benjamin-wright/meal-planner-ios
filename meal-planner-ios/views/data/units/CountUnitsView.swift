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
                    CountUnitEdit(
                        unit: CountUnit(
                            name: ""
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
        CountUnitsView().modelContainer(Models.testing.modelContainer)
    }
}
