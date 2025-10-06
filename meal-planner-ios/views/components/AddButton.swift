//
//  AddButton.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 06/10/2025.
//

import SwiftUI

struct AddButton: View {
    @Environment(\.editMode) private var editMode
    
    var action: () -> Void
    @State var disabled: Bool = false
    
    init(_ action: @escaping () -> Void) {
        self.action = action
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Spacer()
                Image(systemName: "plus")
                Spacer()
            }
        }.disabled(editMode?.wrappedValue.isEditing == true)
    }
}

#Preview {
    NavigationStack {
        List {
            AddButton {
                print("hi")
            }
        }.toolbar {
            EditButton()
        }
    }
}
