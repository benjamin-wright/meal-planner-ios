//
//  MealsView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 09/08/2026.
//

import SwiftUI
import SwiftData

struct MealsView: View {
    @Environment(\.modelContext) private var context

    @Query private var meals: [Meal]
    @State private var mealType: MealType = .dinner
    @State private var deletionError: String?

    private var filteredMeals: [Meal] {
        meals.filter { $0.mealType == mealType }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func delete(at offsets: IndexSet) {
        do {
            try MealStore(context: context).delete(ids: offsets.map { filteredMeals[$0].id })
        } catch {
            deletionError = error.localizedDescription
        }
    }

    var body: some View {
        VStack {
            EnumPicker(label: "Meal", selection: $mealType)
                .pickerStyle(.segmented)
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))
            List {
                ForEach(filteredMeals) { meal in
                    NavigationLink(value: FlowRouter.Route.editMeal(meal.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meal.name)
                        }
                    }
                }
                .onDelete(perform: delete)
                Section {
                    NavigationLink(value: FlowRouter.Route.newMeal(mealType)) {
                        Text("Add").foregroundStyle(.accent)
                    }
                }
            }
            .toolbar { EditButton() }
        }
        .navigationTitle("Meals")
        .alert("Meal", isPresented: Binding(
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
        MealsView()
    }
    .modelContainer(Models.testing.modelContainer)
}
