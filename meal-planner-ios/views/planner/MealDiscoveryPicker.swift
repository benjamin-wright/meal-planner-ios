import SwiftUI
import SwiftData

/// All selection is staged in the parent meal draft. Browsing and previewing
/// never save usage history; committing the planned meal does that once.
struct MealDiscoveryPicker: View {
    @Environment(\.modelContext) private var context
    @Environment(FlowRouter.self) private var router
    @Query private var recipes: [Recipie]
    @Query private var items: [Item]
    @Query private var units: [Unit]
    @Query private var meals: [Meal]
    @Query private var history: [MealHistory]
    @Query private var plannedMeals: [PlannedMeal]

    let mealType: MealType
    let plannedMealID: UUID?
    let currentDraft: PlannedMealDraft
    let onSelect: (PlannedMealDraft) -> Void

    private enum Mode: String, CaseIterable, Identifiable {
        case name = "By name", ingredient = "By ingredient", suggest = "Suggest"
        var id: Self { self }
        var symbol: String {
            switch self {
            case .name: "text.magnifyingglass"
            case .ingredient: "carrot"
            case .suggest: "sparkles"
            }
        }
        var detail: String {
            switch self {
            case .name: "Find a saved meal, a recent combination, or a recipe."
            case .ingredient: "Start with ingredients you want to use."
            case .suggest: "A quick option, shared ingredients, or something different."
            }
        }
    }

    @State private var mode: Mode?
    @State private var nameSearch = ""
    @State private var ingredientSearch = ""
    @State private var browseType: MealType?
    @State private var filter = MealDiscovery.Filter()
    @State private var suggestions: [MealDiscovery.Suggestion] = []
    @State private var seenSuggestions: Set<String> = []
    @State private var hasMore = false
    @State private var hasLoadedSuggestions = false
    @State private var preview: MealDiscovery.Candidate?
    @FocusState private var searchFocused: Bool

    private var discovery: MealDiscovery {
        MealDiscovery(
            recipes: recipes, items: items, units: units,
            savedMeals: meals, history: history, plannedMeals: plannedMeals,
            excludingPlannedMealID: plannedMealID, currentComponents: currentDraft.components
        )
    }

    private var nameFilter: MealDiscovery.Filter {
        var value = MealDiscovery.Filter()
        value.search = nameSearch
        return value
    }

    private var matchingIngredients: [Item] {
        let search = ingredientSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter {
            $0.itemKind == .ingredient && (search.isEmpty
                || $0.name.localizedCaseInsensitiveContains(search))
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var ingredientChoices: [Item] {
        let isSearching = !ingredientSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard isSearching || filter.ingredientIDs.isEmpty else { return [] }
        let matches = matchingIngredients.filter { !filter.ingredientIDs.contains($0.id) }
        return isSearching ? matches : Array(matches.prefix(8))
    }

    private var selectedIngredients: [Item] {
        items.filter { filter.ingredientIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        GlassList {
            Section {
                Text("\(mealType.label) for \(currentDraft.servings)")
                    .font(.subheadline).foregroundStyle(.secondary)
                if let mode {
                    Text(mode.detail).font(.subheadline)
                }
            }
            switch mode {
            case nil: routes
            case .name: nameResults
            case .ingredient: ingredientResults
            case .suggest: suggestionResults
            }
        }
        .navigationTitle(mode?.rawValue ?? "Choose a meal")
        .navigationBarBackButtonHidden(mode != nil)
        .toolbar {
            if mode != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        searchFocused = false
                        mode = nil
                    } label: { Label("Ways to choose", systemImage: "chevron.left") }
                    .accessibilityIdentifier("mealDiscoveryBack")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("New meal", systemImage: "plus") { createMeal() }
                    .accessibilityIdentifier("createDiscoveryMeal")
            }
        }
        .sheet(item: $preview) { candidate in
            NavigationStack {
                MealChoicePreview(candidate: candidate, recipes: recipes, items: items,
                                  units: units, servings: currentDraft.servings) {
                    preview = nil
                    select(candidate)
                }
                .background { AppGlassBackground() }
            }
        }
        .onChange(of: filter) { _, _ in
            hasLoadedSuggestions = false
            if mode == .suggest { refreshSuggestions(reset: true) }
        }
    }

    private var routes: some View {
        Section {
            ForEach(Mode.allCases) { choice in
                Button {
                    mode = choice
                    if choice == .suggest && !hasLoadedSuggestions {
                        refreshSuggestions(reset: true)
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: choice.symbol).font(.title3)
                            .frame(width: 30).foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(choice.rawValue).font(.headline)
                            Text(choice.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }.padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("mealDiscovery-\(choice.id)")
            }
        }
    }

    private var nameResults: some View {
        Group {
            Section {
                Picker("Browse meals for", selection: Binding(
                    get: { browseType ?? mealType }, set: { browseType = $0 }
                )) {
                    ForEach(MealType.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("discoveryMealType")
                .accessibilityValue((browseType ?? mealType).label)
                TextField("Search meal or recipe names", text: $nameSearch)
                    .focused($searchFocused).autocorrectionDisabled()
                    .accessibilityIdentifier("mealNameSearch")
            }
            candidateList(discovery.candidates(for: browseType ?? mealType, filter: nameFilter))
        }
    }

    private var ingredientResults: some View {
        Group {
            Section {
                TextField("Search ingredients", text: $ingredientSearch)
                    .focused($searchFocused).autocorrectionDisabled()
                    .accessibilityIdentifier("mealIngredientSearch")
                if !selectedIngredients.isEmpty { selectedIngredientTags }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)], alignment: .leading) {
                    ForEach(ingredientChoices) { item in
                        tag(item.name, selected: false) {
                            filter.ingredientIDs.insert(item.id)
                            ingredientSearch = ""
                            searchFocused = false
                        }
                        .accessibilityIdentifier("mealIngredient-\(item.name)")
                    }
                }
                if matchingIngredients.isEmpty {
                    Text("No matching ingredients").foregroundStyle(.secondary)
                } else if ingredientSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(filter.ingredientIDs.isEmpty ? "Search for more ingredients." : "Search to add another ingredient.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } header: { Text("Choose ingredients") }
              footer: { Text("Meals must contain every selected ingredient, in any of their dishes.") }
            filterControls
            if filter.ingredientIDs.isEmpty {
                Section { Text("Choose an ingredient above to see meal ideas.").foregroundStyle(.secondary) }
            } else {
                candidateList(discovery.candidates(for: mealType, filter: filter))
            }
        }
    }

    private var suggestionResults: some View {
        Group {
            if !selectedIngredients.isEmpty {
                Section("Using ingredients") { selectedIngredientTags }
            }
            filterControls
            if suggestions.isEmpty {
                emptyResults
            } else {
                Section {
                    ForEach(suggestions) { suggestion in
                        choiceRow(suggestion.candidate, reason: suggestion.title, detail: suggestion.detail)
                    }
                } header: { Text("Ideas for \(mealType.label.lowercased())") }
            }
            Section {
                Button("Show more") { refreshSuggestions(reset: false) }
                    .disabled(!hasMore).accessibilityIdentifier("moreMealSuggestions")
                if !hasMore && !suggestions.isEmpty {
                    Text("You’ve seen all matching meal ideas.").font(.footnote).foregroundStyle(.secondary)
                    Button("Start again") { refreshSuggestions(reset: true) }
                }
            }
        }
    }

    private var selectedIngredientTags: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)], alignment: .leading) {
            ForEach(selectedIngredients) { item in
                tag(item.name, selected: true) { filter.ingredientIDs.remove(item.id) }
                    .accessibilityLabel("Remove \(item.name) filter")
            }
        }
    }

    private var filterControls: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading) {
                tag("15 min or less", selected: filter.quick) { filter.quick.toggle() }
                    .accessibilityIdentifier("mealFilterQuick")
                tag("Vegetarian", selected: filter.vegetarian) {
                    filter.vegetarian.toggle()
                    if filter.vegetarian { filter.pescetarian = false }
                }
                    .accessibilityIdentifier("mealFilterVegetarian")
                tag("Pescatarian", selected: filter.pescetarian) {
                    filter.pescetarian.toggle()
                    if filter.pescetarian { filter.vegetarian = false }
                }
                    .accessibilityIdentifier("mealFilterPescetarian")
                    .accessibilityHint("Allows fish and vegetarian dishes; excludes meat")
                tag("Gluten free", selected: filter.glutenFree) { filter.glutenFree.toggle() }
                    .accessibilityIdentifier("mealFilterGlutenFree")
            }
            if filter.hasActiveFilters {
                Button("Clear filters") { filter = MealDiscovery.Filter() }
                    .accessibilityIdentifier("clearMealFilters")
            }
        } header: { Text("Filters") }
          footer: {
              Text("Applies to all dishes. Pescatarian allows fish and vegetarian dishes, with no meat. Time adds the recorded cooking times; dietary filters use ingredient labels.")
          }
    }

    private func tag(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if selected { Image(systemName: "checkmark") }
                Text(title).multilineTextAlignment(.leading)
            }
            .font(.subheadline)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(selected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain).foregroundStyle(selected ? Color.accentColor : Color.primary)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func candidateList(_ candidates: [MealDiscovery.Candidate]) -> some View {
        if candidates.isEmpty {
            emptyResults
        } else {
            Section {
                ForEach(candidates) { choiceRow($0) }
            } header: { Text("\(candidates.count) meal ideas · A–Z") }
        }
    }

    private var emptyResults: some View {
        Section {
            ContentUnavailableView("No matching meal ideas", systemImage: "fork.knife",
                                   description: Text("Try fewer filters, another ingredient, or create a meal."))
        }
    }

    private func choiceRow(_ candidate: MealDiscovery.Candidate, reason: String? = nil, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let reason { Text(reason).font(.subheadline.weight(.semibold)).foregroundStyle(.tint) }
            Text(candidate.name).font(.headline)
            Text(candidate.originLabel).font(.caption).foregroundStyle(.secondary)
            if let minutes = candidate.estimatedMinutes {
                Text("\(minutes) min total cooking time").font(.subheadline).foregroundStyle(.secondary)
            }
            if let detail { Text(detail).font(.subheadline) }
            if let note = candidate.roleNote { Text(note).font(.subheadline).foregroundStyle(.secondary) }
            HStack {
                Button("Preview") { searchFocused = false; preview = candidate }
                    .accessibilityIdentifier("previewMeal-\(candidate.name)")
                Spacer()
                Button("Use meal", systemImage: "plus") { select(candidate) }
                    .accessibilityIdentifier("useMeal-\(candidate.name)")
            }.buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mealChoice-\(candidate.name)")
    }

    private func refreshSuggestions(reset: Bool) {
        if reset { seenSuggestions = [] }
        let page = discovery.suggestions(for: mealType, filter: filter, excluding: seenSuggestions)
        suggestions = page.suggestions
        seenSuggestions.formUnion(suggestions.map { $0.candidate.id })
        hasMore = page.hasMore
        hasLoadedSuggestions = true
    }

    private func select(_ candidate: MealDiscovery.Candidate) {
        searchFocused = false
        onSelect(PlannedMealDraft(components: candidate.components.map { MealComponentDraft(copying: $0) },
                                  servings: currentDraft.servings))
    }

    private func createMeal() {
        searchFocused = false
        router.showCreation(.meal(browseType ?? mealType)) { id in
            guard let meal = try? context.fetch(Meal.descriptor(id: id)).first else { return }
            var selection = PlannedMealDraft(meal: meal)
            selection.servings = currentDraft.servings
            onSelect(selection)
        }
    }
}

private struct MealChoicePreview: View {
    @Environment(\.dismiss) private var dismiss
    let candidate: MealDiscovery.Candidate
    let recipes: [Recipie]
    let items: [Item]
    let units: [Unit]
    let servings: Int
    let onSelect: () -> Void

    var body: some View {
        GlassList {
            Section {
                Text(candidate.name).font(.title2)
                Text("For \(servings) people · \(candidate.originLabel)").foregroundStyle(.secondary)
                if let note = candidate.roleNote { Text(note) }
            }
            ForEach(CourseType.allCases) { course in
                let components = candidate.components.filter { $0.course == course }
                if !components.isEmpty {
                    Section(course.label) {
                        ForEach(components) { component in
                            if case .recipe(let id) = component.source,
                               let recipe = recipes.first(where: { $0.id == id }) {
                                NavigationLink {
                                    RecipePreview(recipe: recipe, component: component, servings: servings, items: items, units: units)
                                        .background { AppGlassBackground() }
                                } label: {
                                    MealComponentRow(component: component, recipies: recipes, items: items, units: units)
                                }
                            } else {
                                MealComponentRow(component: component, recipies: recipes, items: items, units: units)
                            }
                        }
                    }
                }
            }
            Section {
                Button("Use this meal", systemImage: "plus", action: onSelect)
                    .accessibilityIdentifier("usePreviewedMeal")
            } footer: { Text("You can change dishes, courses, and portions before saving your plan.") }
        }
        .navigationTitle("Meal preview")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}

#Preview("Choose a meal") {
    FlowContainer {
        MealDiscoveryPicker(mealType: .dinner, plannedMealID: nil,
                            currentDraft: PlannedMealDraft(), onSelect: { _ in })
    }
    .modelContainer(Models.testing.modelContainer)
}
