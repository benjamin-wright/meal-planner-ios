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
    @State private var adding: Bool = false
    
    var body: some View {
        return List {
            ForEach(units) { unit in
                NavigationLink {
//                    CategoryEdit(
//                        name: category.name,
//                        categories: categories,
//                        action: { name in
//                            categories.first(where: { $0.id == category.id })?.name = name
//                        }
//                    )
                    Text("Editing \(unit.name)")
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
            Button() {
                adding = true
            } label: {
                Text("Add")
            }.disabled(editMode?.wrappedValue.isEditing ?? false)
        }
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $adding) {
            Text("Adding Unit")
        }
    }
}

#Preview {
    NavigationView {
        CountUnitsView().modelContainer(Models.testing.modelContainer)
    }
}
