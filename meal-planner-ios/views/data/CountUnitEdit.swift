//
//  CountUnitEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 20/09/2025.
//

import SwiftUI
import SwiftData

struct CountUnitEdit: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var initial: String?
    @State private var invalid: Bool = true

    private var existing: [String]
    private var action: (_ name: String) -> Void
    
    init(name: String? = nil, existing: [String], action: @escaping (_ name: String) -> Void) {
        self.name = name ?? ""
        self.initial = name
        self.existing = existing
        self.action = action
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Name:") {
                        TextField("unit name", text: $name)
                            .textInputAutocapitalization(.never)
                            .onChange(of: name) {
                                name = name.lowercased()
                            }
                    }
                }
                
                Button {
                    action(name)
                    dismiss()
                } label: {
                    Text(initial == nil ? "Add" : "Save")
                }.disabled(invalid)
            }
        }
    }
}

#Preview {
    CategoryEdit(
        name: "start",
        categories: [
            Category(name: "test", order: 0),
            Category(name: "start", order: 1)
        ], action: { name in
            print(name)
        }
    )
}
