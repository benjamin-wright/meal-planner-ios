//
//  ItemsView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 01/10/2025.
//

import SwiftUI
import SwiftData

struct ItemsView: View {
    enum Route: Hashable {
        case id(_ id: UUID?)
    }
    
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    
    @Query(sort: \Item.category.order) private var items: [Item]
    @Query(sort: \Category.order) private var categories: [Category]
    
    @State var search: String = ""
    @State private var saveError: String?
    @State private var showIngredients = false
    @State private var showReadymeals = false
    @State private var showMisc = false
    
    func filterItem(item: Item) -> Bool {
        var searchFound = false
        var filtered = false
        
        if search.isEmpty {
            searchFound = true
        } else {
            searchFound = item.name.lowercased().contains(search.lowercased())
                || item.category.name.lowercased().contains(search.lowercased())
        }
        
        if !showIngredients && !showReadymeals && !showMisc {
            filtered = false
        } else {
            switch item.itemKind {
            case .ingredient:
                filtered = !showIngredients
            case .readymeal:
                filtered = !showReadymeals
            case .misc:
                filtered = !showMisc
            }
        }
        
        return searchFound && !filtered
    }
    
    var body: some View {
        return VStack {
            HStack {
                FilterButton(image: "carrot.fill", selected: $showIngredients)
                FilterButton(image: "takeoutbag.and.cup.and.straw.fill", selected: $showReadymeals)
                FilterButton(image: "bag.fill", selected: $showMisc)
            }.padding(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            List {
                ForEach(items.filter(filterItem)) { item in
                    NavigationLink(item.name, value: Route.id(item.id))
                }.onDelete { offsets in
                    do {
                        let filteredItems = items.filter {
                            search == ""
                            || $0.name.localizedCaseInsensitiveContains(search)
                            || $0.category.name.localizedCaseInsensitiveContains(search)
                        }
                        try ItemStore(context: context).delete(ids: offsets.map { filteredItems[$0].id })
                    } catch {
                        saveError = error.localizedDescription
                    }
                }
                Section {
                    NavigationLink(
                        value: Route.id(nil), label: {
                            Text("Add").foregroundColor(.accent)
                        }
                    )
                }
            }
            .toolbar {
                EditButton()
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .id(let id):
                    ItemEdit(id: id)
                }
            }
            .navigationTitle("Items")
        }
        .alert("Item", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        ItemsView()
    }
    .modelContainer(Models.testing.modelContainer)
}
