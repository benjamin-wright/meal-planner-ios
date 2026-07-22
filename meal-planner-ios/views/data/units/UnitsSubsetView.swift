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
    @Query private var settings: [AppSettings]
    @Query private var recipies: [Recipie]

    private let unitType: UnitType
    @State private var saveError: String?
    @State private var deletionError: String?
    
    init(type: UnitType) {
        self.unitType = type
        
        _units = Query(
            filter: #Predicate { $0.type == type.rawValue },
            sort: \Unit.name
        )
    }

    private func isInUse(_ unit: Unit) -> Bool {
        settings.contains {
            $0.preferredWeight.id == unit.id || $0.preferredVolume.id == unit.id
        } || recipies.contains {
            $0.ingredients.contains { $0.unit.id == unit.id }
        }
    }

    private func delete(_ offsets: IndexSet) {
        let selectedUnits = offsets.map { units[$0] }
        guard let referencedUnit = selectedUnits.first(where: isInUse) else {
            selectedUnits.forEach(context.delete)
            do {
                try context.save()
            } catch {
                saveError = "Could not delete the selected unit: \(error.localizedDescription)"
            }
            return
        }

        deletionError = "\(referencedUnit.name) is used by settings or a recipe and cannot be deleted."
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
                if let unit = units.first(where: { $0.id == id }) {
                    UnitEdit(id: id, type: unitType, draft: UnitDraft(unit: unit))
                } else {
                    ContentUnavailableView("Unit Not Found", systemImage: "exclamationmark.triangle")
                }
            }
        }
        .alert("Could Not Delete Unit", isPresented: Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionError ?? "")
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
        ).modelContainer(Models.testing.modelContainer)
    }
}
