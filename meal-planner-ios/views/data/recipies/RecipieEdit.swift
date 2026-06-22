//
//  RecipieEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 29/09/2025.
//

import SwiftUI
import SwiftData

struct RecipieEdit: View {
    @Environment(\.dismiss) var dismiss

    @State var edit: Bool
    @State var recipie: Recipie
    @State var existing: [Recipie]
    @State var units: [Unit]
    @State var items: [Item]
    @State var newIngredient: Bool = false

    var action: () -> Void
    @State private var editMode: EditMode = .inactive
    
    init(
        edit: Bool = false,
        recipie: Recipie,
        existing: [Recipie],
        units: [Unit],
        items: [Item],
        action: @escaping () -> Void
    ) {
        self.recipie = recipie
        self.existing = existing
        self.units = units
        self.items = items
        self.action = action
        self.edit = edit
    }
    
    var body: some View {
        VStack {
            Form {
                Section {
                    TextInput(text: $recipie.name, label: "Name", placeholder: "recipie name")
                }
                
                Section("Details") {
                    TextInput(text: $recipie.summary, label: "Summary", placeholder: "A basic description", multiline: true)
                    IntegerInput(number: $recipie.serves, label: "Serves", placeholder: "number of portions")
                    IntegerInput(number: $recipie.time, label: "Time", placeholder: "time to cook (minutes)", step: 5)
                }
                
                Section("Ingredients") {
                    ForEach(recipie.ingredients) { ingredient in
                        NavigationLink(
                            value: ingredient,
                            label: {
                                Text("\(ingredient.item.name): \(ingredient.unit.toString(forValue: ingredient.quantity))")
                            }
                        )
                    }.onDelete { offsets in
                        recipie.ingredients.remove(atOffsets: offsets)
                    }
                    NavigationLink(
                        value: RecipieIngredient(
                            item: items[0],
                            unit: units[0],
                            quantity: 1
                        ),
                        label: {
                            Text("Add")
                                .foregroundColor(.accent)
                        }
                    )
                }
                
                Section("Steps") {
                    AddButton {
                        
                    }
                }
            }
            
            Button {
                action()
                dismiss()
            } label: {
                Text(edit ? "Save" : "Add")
            }.disabled(editMode.isEditing || !recipie.isValid())
        }
        .toolbar {
            EditButton()
        }
        .environment(\.editMode, $editMode)
        .navigationDestination(for: RecipieIngredient.self) { item in
            RecipieIngredientEdit(
                edit: recipie.ingredients.contains(where: {$0.id == item.id }),
                value: item,
                items: items,
                units: units
            ) {
                if !recipie.ingredients.contains(where: {$0.id == item.id}) {
                    recipie.ingredients.append(item)
                }
            }
        }
    }
}

#Preview {
    struct Preview: View {
        @Query private var items: [Item]
        @Query private var units: [Unit]
        @Query private var recipies: [Recipie]
        
        var body: some View {
            NavigationStack {
                RecipieEdit(
                    recipie: recipies[0],
                    existing: [],
                    units: units,
                    items: items,
                    action: {
                        print(recipies[0].name)
                    }
                )
            }
        }
    }
    
    return Preview().modelContainer(Models.testing.modelContainer)
}
