//
//  DataView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 19/09/2025.
//


import SwiftUI
import SwiftData

struct DataLink: Identifiable {
    var id: Int
    var name: String
    var component: AnyView
}

var dataLinks: [DataLink] = [
    DataLink(id: 1, name: "Units", component: AnyView(UnitsView())),
    DataLink(id: 2, name: "Categories", component: AnyView(CategoriesView())),
    DataLink(id: 3, name: "Ingredients", component: AnyView(IngredientsView())),
]

struct DataView: View {
    var body: some View {
        NavigationStack() {
            List {
                ForEach (dataLinks) { link in
                    NavigationLink {
                        link.component.navigationTitle(link.name)
                    } label: {
                        Text(link.name)
                    }
                }
            }.navigationTitle("Data")
        }
    }
}

#Preview {
    DataView().modelContainer(Models.testing.modelContainer)
}
