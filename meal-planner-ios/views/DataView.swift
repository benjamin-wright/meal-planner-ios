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
    DataLink(id: 1, name: "Units", component: AnyView(Text("Units"))),
    DataLink(id: 2, name: "Categories", component: AnyView(CategoriesView())),
]

struct DataView: View {
    var body: some View {
        NavigationView() {
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
    DataView().modelContainer(SampleData.shared.modelContainer)
}
