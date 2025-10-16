//
//  RecipiesFilteredView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 28/09/2025.
//

import SwiftUI
import SwiftData

struct RecipiesFilteredView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    
    @Query private var recipies: [Recipie]
    @Query private var units: [Measure]
    @Query private var ingredients: [Ingredient]
    @State var recipieType: RecipieType
    
    init(type: RecipieType) {
        self.recipieType = type
        
        _recipies = Query(filter: #Predicate { $0.type == type.rawValue })
    }
    
    var body: some View {
        return List {
            ForEach(recipies) { recipie in
                NavigationLink(recipie.name, value: recipie)
                    .onChange(of: recipies) {}
            }.onDelete { offsets in
                for (index, unit) in recipies.enumerated() {
                    if offsets.contains(index) {
                        context.delete(unit)
                    }
                }
            }
            Section {
                NavigationLink(
                    value: Recipie(type: recipieType),
                    label: {
                        Text("Add").foregroundStyle(.accent)
                    }
                )
            }
        }
        .toolbar {
            EditButton()
        }
        .navigationDestination(for: Recipie.self) { recipie in
            RecipieEdit(
                edit: recipies.contains(where: { $0.id == recipie.id }),
                recipie: recipie,
                existing: recipies,
                units: units,
                ingredients: ingredients,
                action: {
                    if !recipies.contains(where: { $0.id == recipie.id }) {
                        context.insert(recipie)
                    }
                    try! context.save()
                }
            ).onDisappear {
                context.rollback()
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecipiesFilteredView(
            type: .dinner
        ).modelContainer(Models.testing.modelContainer)
    }
}
