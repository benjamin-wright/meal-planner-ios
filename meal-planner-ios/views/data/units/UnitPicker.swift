//
//  UnitPicker.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 08/10/2025.
//

import SwiftUI
import SwiftData

struct UnitPicker: View {
    @Environment(FlowRouter.self) private var router

    let units: [Unit]
    let selectedID: UUID?
    var typeFilter: UnitType? = nil

    @State private var type = -1
    let onSelect: (UUID) -> Void
    @State private var search = ""

    var filteredUnits: [Unit] {
        units.filter {
            (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
            &&
            (typeFilter == nil || $0.unitType == typeFilter)
            &&
            (typeFilter != nil || type == -1 || $0.type == type)
        }
    }

    var body: some View {
        VStack {
            if typeFilter == nil {
                Picker("Type", selection: $type) {
                    Text("All").tag(-1)
                    Text("Count").tag(UnitType.count.rawValue)
                    Text("Weight").tag(UnitType.weight.rawValue)
                    Text("Volume").tag(UnitType.volume.rawValue)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
                .glassControl()
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            GlassList {
                ForEach(filteredUnits) { unit in
                    SelectionRow(title: unit.name, isSelected: unit.id == selectedID) {
                        onSelect(unit.id)
                    }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                Button("Add") {
                    router.showCreation(.unit(
                        type: typeFilter ?? UnitType(rawValue: type) ?? .weight,
                        allowsTypeChange: typeFilter == nil
                    ), onCreate: onSelect)
                }
            }
        }
        .navigationTitle("Unit")
    }
}

#Preview {
    struct Preview: View {
        @Query(sort: \Unit.name) private var units: [Unit]
        @State private var selectedID: UUID = UUID()

        var body: some View {
            FlowContainer {
                UnitPicker(
                    units: units,
                    selectedID: selectedID,
                    onSelect: { selectedID = $0 }
                )
            }
        }
    }

    return Preview()
        .modelContainer(Models.testing.modelContainer)
}
