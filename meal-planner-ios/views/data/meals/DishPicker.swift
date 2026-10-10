import SwiftUI
import SwiftData

struct DishPicker: View {
    @Environment(\.modelContext) private var context
    @Environment(FlowRouter.self) private var router

    let recipies: [Recipie]
    let items: [Item]
    let units: [Unit]
    @Binding var selectedID: DishID
    var course: CourseType = .main

    @State private var search = ""
    @State private var isSearchPresented = false
    @State private var catalogue: Catalogue = .recipes
    @State private var selectionError: String?

    private enum Catalogue: String, LabeledEnum {
        case recipes = "Recipes"
        case items = "Items"

        var id: Self { self }
        var label: String { rawValue }
    }

    private struct Option: Identifiable {
        let dish: DishID
        let name: String
        var category: String = ""

        var id: DishID { dish }
    }

    private var dishes: [Option] {
        let recipes = recipies.map {
            Option(dish: .recipe($0.id), name: $0.name)
        }
        let readyMeals = items.filter { $0.itemKind == .readymeal }.map {
            Option(dish: .readymeal($0.id), name: $0.name, category: $0.category.name)
        }
        let ingredients = items.filter { $0.itemKind == .ingredient }.map {
            Option(dish: .ingredient($0.id), name: $0.name, category: $0.category.name)
        }

        return (catalogue == .recipes ? recipes + readyMeals : ingredients)
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
                || $0.category.localizedCaseInsensitiveContains(search) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func select(_ dish: DishID) {
        isSearchPresented = false
        if case .ingredient = dish {
            // Creation can finish before the picker's query has refreshed.
            let units = (try? context.fetch(FetchDescriptor<Unit>(sortBy: [SortDescriptor(\.name)]))) ?? units
            guard let unit = Unit.defaultForNewObject(in: units) else {
                selectionError = "Add a unit in Data before adding an ingredient portion."
                return
            }
            router.showMealComponent(
                MealComponentDraft(source: dish, course: course, quantity: 1, unitID: unit.id),
                isEditing: false,
                dismissDishPickerOnSave: true,
                onSave: router.selectDishComponent
            )
        } else {
            router.selectDishComponent(MealComponentDraft(source: dish, course: course))
            router.path = Array(router.path.dropLast())
        }
    }

    private func create(_ route: FlowRouter.Route, in catalogue: Catalogue) {
        self.catalogue = catalogue
        search = ""
        isSearchPresented = false
        router.showCreation(route) { id in
            switch route {
            case .newRecipie:
                select(.recipe(id))
            case .newItemOfKind:
                guard let item = try? context.fetch(Item.descriptor(id: id)).first else { return }
                switch item.itemKind {
                case .ingredient: select(.ingredient(id))
                case .readymeal: select(.readymeal(id))
                case .misc: break
                }
            default:
                break
            }
        }
    }

    var body: some View {
        VStack {
            EnumPicker(label: "Catalogue", selection: $catalogue)
                .padding(.horizontal)
            GlassList {
                ForEach(dishes) { dish in
                    Button {
                        select(dish.dish)
                    } label: {
                        HStack {
                            Text(dish.name)
                                .lineLimit(1)
                            Spacer()
                            if dish.dish == selectedID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .accessibilityIdentifier("dishOption-\(dish.dish)")
                }
            }
            .searchable(text: $search, isPresented: $isSearchPresented, placement: .navigationBarDrawer(displayMode: .always))
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Add", systemImage: "plus") {
                    Button("Recipe") { create(.newRecipie, in: .recipes) }
                    Button("Ready Meal") { create(.newItemOfKind(.readymeal), in: .recipes) }
                    Button("Ingredient") { create(.newItemOfKind(.ingredient), in: .items) }
                }
            }
        }
        .navigationTitle("Dish")
        .alert("Ingredient Portion", isPresented: Binding(
            get: { selectionError != nil },
            set: { if !$0 { selectionError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(selectionError ?? "")
        }
    }
}

private struct DishPickerPreview: View {
    @Query private var recipies: [Recipie]
    @Query private var items: [Item]
    @Query private var units: [Unit]
    @State private var selectedID: DishID = .recipe(UUID())

    var body: some View {
        FlowContainer {
            DishPicker(recipies: recipies, items: items, units: units, selectedID: $selectedID)
        }
    }
}

#Preview {
    DishPickerPreview()
        .modelContainer(Models.testing.modelContainer)
}
