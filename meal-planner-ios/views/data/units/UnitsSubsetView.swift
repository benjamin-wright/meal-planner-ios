//
//  ContinuousUnitsView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 28/09/2025.
//

import SwiftUI
import SwiftData

struct UnitsSubsetView: View {
    private enum Route: Hashable {
        case add
        case edit(UUID)
    }

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
                NavigationLink(unit.name, value: Route.edit(unit.id))
            }.onDelete(perform: delete)
            Section {
                NavigationLink(value: Route.add) {
                    Text("Add").foregroundStyle(.accent)
                }
            }
        }
        .toolbar {
            EditButton()
        }
        .navigationDestination(for: Route.self) { route in
            switch route {
            case .add:
                UnitEdit(type: unitType)
            case .edit(let id):
                UnitEdit(id: id, type: unitType)
            }
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
    NavigationStack {
        UnitsSubsetView(
            type: .weight
        )
    }
    .modelContainer(Models.testing.modelContainer)
}
