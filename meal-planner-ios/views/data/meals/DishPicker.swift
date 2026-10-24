import SwiftUI
import SwiftData

struct DishPicker: View {
    @Environment(\.modelContext) private var context
    @Environment(FlowRouter.self) private var router

    let recipies: [Recipie]
    let items: [Item]
    let units: [Unit]
    let onSelect: (MealComponentDraft) -> Void

    @State private var course: CourseType = .main
    @State private var search = ""
    @State private var isSearchPresented = false
    @State private var catalogue: Catalogue = .recipes
    @State private var selectionError: String?
    @State private var quick = false
    @State private var vegetarian = false
    @State private var pescetarian = false
    @State private var previewRecipe: Recipie?

    init(
        recipies: [Recipie], items: [Item], units: [Unit],
        initialCourse: CourseType = .main,
        onSelect: @escaping (MealComponentDraft) -> Void
    ) {
        self.recipies = recipies
        self.items = items
        self.units = units
        self.onSelect = onSelect
        self._course = State(initialValue: initialCourse)
    }

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
        var recipe: Recipie? = nil
        var time: Int? = nil
        var serves: Int? = nil
        var isVegetarian = false
        var isPescetarian = false
        var ingredientNames: [String] = []

        var id: DishID { dish }

        var detail: String {
            var terms: [String] = []
            switch dish {
            case .recipe: terms.append("Recipe")
            case .readymeal: terms.append("Ready meal")
            case .ingredient: return category
            }
            if let time, time >= 0 { terms.append("\(time) min") }
            if let serves, serves > 0 { terms.append("Serves \(serves)") }
            return terms.joined(separator: " · ")
        }
    }

    private var dishes: [Option] {
        let recipes = recipies.map {
            Option(
                dish: .recipe($0.id), name: $0.name, recipe: $0,
                time: $0.time, serves: $0.serves,
                isVegetarian: !$0.ingredients.isEmpty && $0.isVegetarian,
                isPescetarian: !$0.ingredients.isEmpty && $0.isPescetarian,
                ingredientNames: $0.ingredients.map { $0.item.name }
            )
        }
        let readyMeals = items.filter { $0.itemKind == .readymeal }.map {
            Option(
                dish: .readymeal($0.id), name: $0.name, category: $0.category.name,
                time: $0.readymealData?.time, serves: $0.readymealData?.serves,
                isVegetarian: $0.dietary.isDisjoint(with: [.fish, .meat]),
                isPescetarian: !$0.dietary.contains(.meat) && $0.readymealData.map { $0.serves > 0 } == true
            )
        }
        let ingredients = items.filter { $0.itemKind == .ingredient }.map {
            Option(dish: .ingredient($0.id), name: $0.name, category: $0.category.name)
        }

        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return (catalogue == .recipes ? recipes + readyMeals : ingredients)
            .filter { option in
                let matchesSearch = query.isEmpty || option.name.localizedCaseInsensitiveContains(query)
                    || option.category.localizedCaseInsensitiveContains(query)
                    || option.ingredientNames.contains { $0.localizedCaseInsensitiveContains(query) }
                let matchesFilters = catalogue == .items || (
                    (!quick || option.time.map { (0...15).contains($0) } == true)
                    && (!vegetarian || option.isVegetarian)
                    && (!pescetarian || option.isPescetarian)
                )
                return matchesSearch && matchesFilters
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func dishRow(_ dish: Option) -> some View {
        HStack(spacing: 12) {
            Button {
                select(dish.dish)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dish.name)
                        .foregroundStyle(.primary)
                    Text(dish.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("dishOption-\(dish.dish)")
            .accessibilityLabel(dish.name)
            .accessibilityValue(dish.detail)
            .accessibilityHint("Add as \(course.label.lowercased())")

            if let recipe = dish.recipe {
                Button("Preview", systemImage: "eye") {
                    isSearchPresented = false
                    previewRecipe = recipe
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Preview \(dish.name)")
                .accessibilityIdentifier("previewRecipe-\(recipe.id)")
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                Toggle("Quick · ≤15 min", isOn: $quick)
                    .accessibilityIdentifier("dishQuickFilter")
                Toggle("Vegetarian", isOn: Binding(
                    get: { vegetarian },
                    set: { enabled in
                        vegetarian = enabled
                        if enabled { pescetarian = false }
                    }
                ))
                .accessibilityIdentifier("dishVegetarianFilter")
                Toggle("Pescatarian", isOn: Binding(
                    get: { pescetarian },
                    set: { enabled in
                        pescetarian = enabled
                        if enabled { vegetarian = false }
                    }
                ))
                .accessibilityHint("Includes fish and vegetarian dishes; excludes meat")
                .accessibilityIdentifier("dishPescetarianFilter")
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.horizontal)
        }
        .accessibilityIdentifier("dishDietaryFilters")
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
                onSave: onSelect
            )
        } else {
            onSelect(MealComponentDraft(source: dish, course: course))
        }
    }

    private func create(_ screen: FlowRouter.CreationScreen, in catalogue: Catalogue) {
        self.catalogue = catalogue
        search = ""
        isSearchPresented = false
        router.showCreation(screen) { id in
            switch screen {
            case .recipe:
                select(.recipe(id))
            case .item:
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
            Picker("Course", selection: $course) {
                ForEach(CourseType.allCases) { course in
                    Text(course.label).tag(course)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("dishCoursePicker")
            .accessibilityValue(course.label)
            .padding(.horizontal)
            EnumPicker(label: "Catalogue", selection: $catalogue)
                .padding(.horizontal)
            if catalogue == .recipes {
                filterChips
            }
            GlassList {
                ForEach(dishes) { dish in
                    dishRow(dish)
                }
                if dishes.isEmpty {
                    ContentUnavailableView(
                        "No Matching Dishes", systemImage: "magnifyingglass",
                        description: Text("Try another search or change your filters.")
                    )
                }
            }
            .searchable(text: $search, isPresented: $isSearchPresented, placement: .navigationBarDrawer(displayMode: .always))
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Add", systemImage: "plus") {
                    Button("Recipe") { create(.recipe, in: .recipes) }
                    Button("Ready Meal") { create(.item(kind: .readymeal), in: .recipes) }
                    Button("Ingredient") { create(.item(kind: .ingredient), in: .items) }
                }
            }
        }
        .navigationTitle("Dish")
        .sheet(item: $previewRecipe) { recipe in
            NavigationStack {
                RecipePreview(recipe: recipe, items: items, units: units)
                    .background { AppGlassBackground() }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { previewRecipe = nil }
                        }
                    }
            }
        }
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

    var body: some View {
        FlowContainer {
            DishPicker(recipies: recipies, items: items, units: units, onSelect: { _ in })
        }
    }
}

#Preview {
    DishPickerPreview()
        .modelContainer(Models.testing.modelContainer)
}
