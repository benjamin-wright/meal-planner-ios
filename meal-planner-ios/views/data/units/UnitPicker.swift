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

    let units: [Unit]
    @Binding var selectedID: UUID

    @State private var search = ""
    @State private var isAddingUnit = false

    var filteredUnits: [Unit] {
        units.filter {
            search.isEmpty || $0.name.contains(search)
        }
    }

    var body: some View {
        List {
            ForEach(filteredUnits) { unit in
                Button {
                    selectedID = unit.id
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
                isAddingUnit = true
            }
        }
        .navigationDestination(isPresented: $isAddingUnit) {
            UnitEdit(type: .weight)
        }
        .navigationTitle("Unit")
    }
}

#Preview {
    struct Preview: View {
        @Query(sort: \Unit.name) private var units: [Unit]
        @State private var selectedID: UUID = UUID()

        var body: some View {
            NavigationStack {
                UnitPicker(
                    units: units,
                    selectedID: $selectedID
                )
            }
        }
    }

    return Preview().modelContainer(Models.testing.modelContainer)
}
