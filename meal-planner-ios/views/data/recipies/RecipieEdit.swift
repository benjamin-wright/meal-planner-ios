//
//  RecipieEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 29/09/2025.
//

import SwiftUI

struct RecipieEdit: View {
    @Environment(\.dismiss) var dismiss

    @State var edit: Bool
    @State var recipie: Recipie
    @State var existing: [Recipie]

    var action: () -> Void
    @State private var editMode: EditMode = .inactive
    
    init(
        edit: Bool = false,
        recipie: Recipie,
        existing: [Recipie],
        action: @escaping () -> Void
    ) {
        self.recipie = recipie
        self.existing = existing
        self.action = action
        self.edit = edit
    }
    
    var body: some View {
        Form {
            Section {
                TextInput(text: $recipie.name, label: "Name", placeholder: "recipie name")
            }
            
            Section("Details") {
                TextInput(text: $recipie.summary, label: "Summary", placeholder: "A basic description", multiline: true)
                IntegerInput(number: $recipie.serves, label: "Serves", placeholder: "number of portions")
                NumberInput(number: $recipie.time, label: "Time", placeholder: "time to cook (minutes)")
            }
            
            Section("Ingredients") {
                AddButton {
                    
                }
            }
            
            Section("Steps") {
                AddButton {
                    
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
    }
}

#Preview {
    NavigationStack {
        let recipie = Recipie(
            name: "",
            type: .dinner,
            summary: "",
            serves: 2,
            time: 15,
            ingredients: [],
            steps: []
        )
        RecipieEdit(
            recipie: recipie,
            existing: [recipie],
            action: {
                print(recipie.name)
            }
        )
    }
}
