//
//  CategoryEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 19/09/2025.
//

import SwiftUI
import SwiftData

struct CategoryEdit: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.order) var categories: [Category]
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var invalid: Bool = true
    
    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Name:") {
                    TextField("Category", text: $name)
                        .onChange(of: name) {
                            invalid = name.isEmpty || categories.contains(where: { $0.name == name.lowercased() })
                        }
                }
            }.toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button() {
                        let category = Category(name: name.lowercased(), order: categories.count + 1)
                        
                        context.insert(category)
                        try? context.save()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }.disabled(invalid)
                }
            }
        }
    }
}

#Preview {
    CategoryEdit().modelContainer(SampleData.shared.modelContainer)
}
