//
//  ContinuousUnitsView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 28/09/2025.
//

import SwiftUI
import SwiftData

struct UnitsSubsetView: View {
    @Environment(\.modelContext) private var context
    
    @Query private var units: [Unit]

    private let unitType: UnitType
    @State private var saveError: String?
    
    init(type: UnitType) {
        self.unitType = type
        
        _units = Query(
            filter: #Predicate { $0.type == type.rawValue },
            sort: \Unit.name
        )
    }

    private func delete(_ offsets: IndexSet) {
        let selectedUnits = offsets.map { units[$0] }
        do {
            try UnitStore(context: context).delete(ids: selectedUnits.map(\.id))
        } catch {
            saveError = error.localizedDescription
        }
    }
    
    var body: some View {
        return List {
            ForEach(units) { unit in
                NavigationLink(unit.name, value: FlowRouter.Route.editUnit(id: unit.id, type: unitType))
            }.onDelete(perform: delete)
            Section {
                NavigationLink(value: FlowRouter.Route.newUnit(unitType)) {
                    Text("Add").foregroundStyle(.accent)
                }
            }
        }
        .toolbar {
            EditButton()
        }
        .alert("Could Not Save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }
}

#Preview {
    FlowContainer {
        UnitsSubsetView(
            type: .weight
        )
    }
    .modelContainer(Models.testing.modelContainer)
}
