//
//  UnitPicker.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 08/10/2025.
//

import SwiftUI
import SwiftData

struct UnitPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FlowRouter.self) private var router

    let units: [Unit]
    @Binding var selectedID: UUID

    @State private var type = -1
    @State private var search = ""

    var filteredUnits: [Unit] {
        units.filter {
            (search.isEmpty || $0.name.contains(search))
            &&
            (type == -1 || $0.type == type)
        }
    }

    var body: some View {
        VStack {
            Picker("Type", selection: $type) {
                Text("All").tag(-1)
                Text("Count").tag(UnitType.count.rawValue)
                Text("Weight").tag(UnitType.weight.rawValue)
                Text("Volume").tag(UnitType.volume.rawValue)
            }
            .frame(maxWidth: .infinity).padding(.top, 16)
            .pickerStyle(.segmented)
            List {
                ForEach(filteredUnits) { unit in
                    Button {
                        router.selectUnit(unit.id)
                        dismiss()
                    } label: {
                        HStack {
                            Text(unit.name)
                            Spacer()
                            if unit.id == selectedID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
            .onChange(of: search) {
                let lowercase = search.lowercased()
                if lowercase != search {
                    search = lowercase
                }
            }
            .toolbar {
                Button("Add") {
                    router.path.append(.newUnit(.weight))
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
                    selectedID: $selectedID
                )
            }
        }
    }

    return Preview()
        .modelContainer(Models.testing.modelContainer)
}
