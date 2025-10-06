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
                NavigationLink(
                    value: CountUnit(name: ""),
                    label: {
                        Text("Add").foregroundStyle(.accent)
                    }
                )
            }
        }.navigationDestination(for: CountUnit.self) { item in
            let edit = units.contains(where: { $0.id == item.id })
            return CountUnitEdit(
                edit: edit,
                unit: item,
                existing: units,
                action: {
                    if !edit {
                        context.insert(item)
                    }
                    try! context.save()
                },
            ).onDisappear {
                print("Rolling back")
                context.rollback()
            }
        }
        .toolbar {
            EditButton()
        }
    }
}

#Preview {
    NavigationStack {
        CountUnitsView().modelContainer(Models.testing.modelContainer)
    }
}
