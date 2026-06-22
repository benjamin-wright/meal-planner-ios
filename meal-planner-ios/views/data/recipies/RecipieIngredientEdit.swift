//
//  RecipieIngredientEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 08/10/2025.
//

import SwiftUI
import SwiftData

struct RecipieIngredientEdit: View {
    @Environment(\.dismiss) var dismiss
    
    @State var edit: Bool
    @State var value: RecipieIngredient
    @State var items: [Item]
    @State var units: [Unit]
    var action: () -> Void
    
    var body: some View {
        Form {
            Section {
                NavigationLink {
                    ItemPicker(
                        items: items,
                        selected: $value.item
                    )
                } label: {
                    Text("Item").badge(value.item.name)
                }
                UnitPicker(
                    label: "Unit",
                    selected: $value.unit,
                    units: units
                )
                UnitInput(
                    label: "Quantity",
                    unit: $value.unit,
                    value: $value.quantity
                )
            }
            if !edit {
                Button {
                    action()
                    dismiss()
                } label: {
                    Text("Add")
                }
            }
        }
    }
}

#Preview {
    struct Preview: View {
        @Query var items: [Item]
        @Query var units: [Unit]
        @Query var recipies: [Recipie]
        
        var body: some View {
            NavigationStack {
                RecipieIngredientEdit(
                    edit: false,
                    value: recipies[0].ingredients[0],
                    items: items,
                    units: units
                ) {
                    print("hi")
                }
            }
        }
    }
    
    return Preview().modelContainer(Models.testing.modelContainer)
}
