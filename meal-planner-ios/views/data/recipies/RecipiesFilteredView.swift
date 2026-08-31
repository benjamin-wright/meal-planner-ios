//
//  RecipiesFilteredView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 28/09/2025.
//

import SwiftUI
import SwiftData
import OSLog

struct RecipiesFilteredView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    
    @Query private var recipies: [Recipie]
    let mealType: MealType
    let course: CourseType
    @State private var deletionError: String?
    
    init(mealType: MealType, course: CourseType) {
        self.mealType = mealType
        self.course = course
        
        _recipies = Query(filter: #Predicate<Recipie> { recipie in
            recipie.mealType == mealType.rawValue && recipie.course == course.rawValue
        })
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
    
    private func badge(_ recipie: Recipie) -> String {
        var terms: [String] = []
        
        if recipie.isQuick {
            terms.append("Q")
        }
        if recipie.isVegan {
            terms.append("Ve")
        } else if recipie.isVegetarian {
            terms.append("Vg")
        } else if recipie.isPescetarian {
            terms.append("Pe")
        }
        if recipie.isGlutenFree {
            terms.append("GF")
        }
        
        return terms.joined(separator: ", ")
    }

    var body: some View {
        return GlassList {
            ForEach(recipies) { recipie in
                NavigationLink(value: FlowRouter.Route.editRecipie(recipie.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipie.name).badge(badge(recipie))
                    }
                }
            }.onDelete(perform: delete)
            Section {
                NavigationLink(value: FlowRouter.Route.newRecipie(mealType, course)) {
                    Text("Add").foregroundStyle(.accent)
                }
            }
        }
        .toolbar {
            EditButton()
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
    FlowContainer {
        RecipiesFilteredView(
            mealType: .dinner,
            course: .main
        )
    }
    .modelContainer(Models.testing.modelContainer)
}
