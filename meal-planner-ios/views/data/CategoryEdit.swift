//
//  CategoryEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 19/09/2025.
//

import SwiftUI
import SwiftData

struct CategoryEdit: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var initial: String?
    @State private var invalid: Bool = true

    private var categories: [Category]
    private var action: (_ name: String) -> Void
    
    init(name: String? = nil, categories: [Category], action: @escaping (_ name: String) -> Void) {
        self.name = name ?? ""
        self.initial = name
        self.categories = categories
        self.action = action
    }
    
    private func isInvalid() -> Bool {
        if name.isEmpty {
            return true
        }
        
        if name.count < 3 {
            return true
        }
        
        if categories
            .contains(where: { $0.name == name }) {
            return true
        }
        
        return false
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Name:") {
                        TextField("category", text: $name)
                            .textInputAutocapitalization(.never)
                            .onChange(of: name) {
                                name = name.lowercased()
                                invalid = isInvalid()
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
