//
//  RecipiesFilteredView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 28/09/2025.
//

import SwiftUI
import SwiftData

struct RecipiesFilteredView: View {
    @Environment(\.modelContext) private var context
    @Query private var recipies: [Recipie]
    @State private var filter = RecipieFilter()
    @State private var deletionError: String?

    private var filteredRecipies: [Recipie] {
        recipies.filter { filter.filter(recipie: $0) }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private func delete(at offsets: IndexSet) {
        do {
            let store = RecipieStore(context: context)
            for id in offsets.map({ filteredRecipies[$0].id }) {
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
            ForEach(filteredRecipies) { recipie in
                NavigationLink(value: FlowRouter.Route.editRecipie(recipie.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipie.name).badge(badge(recipie))
                    }
                }
            }.onDelete(perform: delete)
            Section {
                NavigationLink(value: FlowRouter.Route.newRecipie) {
                    Text("Add").foregroundStyle(.accent)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Toggle("Quick (15 minutes or less)", isOn: $filter.quick)
                    Toggle("Vegan", isOn: $filter.vegan)
                    Toggle("Vegetarian", isOn: $filter.vegetarian)
                    Toggle("Pescetarian", isOn: $filter.pescetarian)
                    Toggle("Gluten Free", isOn: $filter.glutenFree)
                    if filter.hasActiveFilters {
                        Button("Clear Filters") { filter.clearFilters() }
                    }
                } label: {
                    Label("Filters", systemImage: filter.hasActiveFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
                .accessibilityIdentifier("recipeFilters")
                EditButton()
            }
        }
        .searchable(text: $filter.search, placement: .navigationBarDrawer(displayMode: .always))
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
        RecipiesFilteredView()
    }
    .modelContainer(Models.testing.modelContainer)
}
