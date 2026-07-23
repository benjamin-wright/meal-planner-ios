//
//  RecipiesFilteredView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 28/09/2025.
//

import SwiftUI
import SwiftData

struct RecipiesFilteredView: View {
    private enum Route: Hashable {
        case add
        case edit(UUID)
    }

    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    
    @Query private var recipies: [Recipie]
    @State var recipieType: RecipieType
    
    init(type: RecipieType) {
        self.recipieType = type
        
        _recipies = Query(filter: #Predicate { $0.type == type.rawValue })
    }
    
    var body: some View {
        return List {
            ForEach(recipies) { recipie in
                NavigationLink(recipie.name, value: Route.edit(recipie.id))
            }.onDelete { offsets in
                for (index, unit) in recipies.enumerated() {
                    if offsets.contains(index) {
                        context.delete(unit)
                    }
                }
            }
            Section {
                NavigationLink(value: Route.add) {
                    Text("Add").foregroundStyle(.accent)
                }
            }
        }
        .toolbar {
            EditButton()
        }
        .navigationDestination(for: Route.self) { route in
            WithEditContext(from: context) {
                switch route {
                case .add:
                    RecipieEdit(type: recipieType)
                case .edit(let id):
                    if let recipie = recipies.first(where: { $0.id == id }) {
                        RecipieEdit(id: id, type: recipie.recipieType, draft: RecipieDraft(recipie: recipie))
                    } else {
                        ContentUnavailableView("Recipe Not Found", systemImage: "exclamationmark.triangle")
                    }
                }
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
