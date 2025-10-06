//
//  DataView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 19/09/2025.
//


import SwiftUI
import SwiftData

extension DataView {
    enum ViewDestination: Hashable, CaseIterable {
        case units, categories, ingredients
    }
}

struct DataView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Units", value: ViewDestination.units)
                NavigationLink("Categories", value: ViewDestination.categories)
                NavigationLink("Ingredients", value: ViewDestination.ingredients)
            }.navigationTitle("Data")
            .navigationDestination(for: ViewDestination.self) { view in
                switch view {
                case .units:
                    UnitsView()
                case .categories:
                    CategoriesView()
                case .ingredients:
                    IngredientsView()
                }
            }
        }
    }
}

#Preview {
    DataView().modelContainer(Models.testing.modelContainer)
}
