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
    @State var mealType: MealType
    @State private var deletionError: String?
    
    init(mealType: MealType) {
        self.mealType = mealType
        
        _recipies = Query(filter: #Predicate { $0.mealType == mealType })
    }

    private func delete(at offsets: IndexSet) {
        do {
            let store = RecipieStore(context: context)
            for id in offsets.map({ recipies[$0].id }) {
                try store.delete(id: id)
            }
        } catch {
            deletionError = error.localizedDescription
        }
    }
    
    var body: some View {
        return List {
            ForEach(recipies) { recipie in
                NavigationLink(recipie.name, value: Route.edit(recipie.id))
            }.onDelete(perform: delete)
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
            switch route {
            case .add:
                RecipieEdit(mealType: mealType)
            case .edit(let id):
                if let recipie = recipies.first(where: { $0.id == id }) {
                    RecipieEdit(id: id, mealType: recipie.mealType)
                } else {
                    ContentUnavailableView("Recipe Not Found", systemImage: "exclamationmark.triangle")
                }
            }
        }
        .alert("Recipe", isPresented: Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionError ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        RecipiesFilteredView(
            mealType: .dinner
        )
    }
    .modelContainer(Models.testing.modelContainer)
}
