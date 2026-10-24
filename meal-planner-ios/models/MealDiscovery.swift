import Foundation

/// Read-only meal discovery. The editor remains responsible for copying components and saving a plan.
@MainActor
final class MealDiscovery {
    struct Filter: Hashable {
        var search = ""
        var ingredientIDs: Set<UUID> = []
        var quick = false
        var vegetarian = false
        var pescetarian = false
        var glutenFree = false

        var hasActiveFilters: Bool {
            !ingredientIDs.isEmpty || quick || vegetarian || pescetarian || glutenFree
        }

        mutating func clearFilters() {
            ingredientIDs = []
            quick = false
            vegetarian = false
            pescetarian = false
            glutenFree = false
        }
    }

    struct Candidate: Identifiable, Hashable {
        let id: String
        let name: String
        let components: [MealComponentDraft]
        let sourceMealID: UUID?
        let servings: Int
        let originLabel: String
        let roleNote: String?
        let ingredientIDs: Set<UUID>
        /// Sum of known component times, not elapsed time when cooking dishes concurrently.
        let estimatedMinutes: Int?
        let isVegetarian: Bool
        let isPescetarian: Bool
        let isGlutenFree: Bool
        let recipeIDs: Set<UUID>
        fileprivate let combinationID: String
        fileprivate let rank: Double
        fileprivate let isRecipeFallback: Bool

        var isQuick: Bool { estimatedMinutes.map { $0 > 0 && $0 <= 15 } == true }
    }

    struct Suggestion: Identifiable {
        var id: String { candidate.id }
        let candidate: Candidate
        let title: String
        let detail: String
    }

    struct SuggestionPage {
        let suggestions: [Suggestion]
        let hasMore: Bool
        /// True when this page contains the last available candidates, including an empty pool.
        var exhausted: Bool { !hasMore }
    }

    private struct Observation {
        let components: [MealComponentDraft]
        let weight: Double
    }

    private struct RoleEvidence {
        var counts: [CourseType: Double] = [:]
        var total: Double { counts.values.reduce(0, +) }
        var preferred: CourseType {
            CourseType.allCases.max {
                let left = counts[$0, default: 0], right = counts[$1, default: 0]
                return left == right ? priority($0) < priority($1) : left < right
            } ?? .main
        }

        private func priority(_ course: CourseType) -> Int {
            // In a genuine tie, don't reclassify an established main as a side.
            course == .main ? 4 : 3 - course.rawValue
        }
    }

    private struct Metadata {
        var ingredients: Set<UUID> = []
        var recipes: Set<UUID> = []
        var dietary: Set<Dietary> = []
        var dietaryKnown = true
        var minutes: Int? = 0
    }

    private let recipes: [UUID: Recipie]
    private let items: [UUID: Item]
    private let units: [UUID: Unit]
    private let savedMeals: [Meal]
    private let history: [MealHistory]
    private let plannedMeals: [PlannedMeal]
    private let excludingPlannedMealID: UUID?
    private let currentComponents: [MealComponentDraft]
    private let ingredientResolver: IngredientResolver

    init(
        recipes: [Recipie], items: [Item], units: [Unit], savedMeals: [Meal],
        history: [MealHistory], plannedMeals: [PlannedMeal],
        excludingPlannedMealID: UUID? = nil, currentComponents: [MealComponentDraft] = []
    ) {
        self.recipes = Dictionary(recipes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.items = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.units = Dictionary(units.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.savedMeals = savedMeals
        self.history = history
        self.plannedMeals = plannedMeals
        self.excludingPlannedMealID = excludingPlannedMealID
        self.currentComponents = currentComponents
        ingredientResolver = IngredientResolver(
            items: Array(self.items.values), units: Array(self.units.values)
        )
    }

    /// Browsing is deliberately inclusive: learning changes suggested roles, never hides a recipe.
    func candidates(for mealType: MealType, filter: Filter = .init()) -> [Candidate] {
        let evidence = roleEvidence(for: mealType)
        var result: [String: Candidate] = [:]
        var searchNames: [String: Set<String>] = [:]

        func add(_ components: [MealComponentDraft], name: String, servings: Int,
                 sourceMealID: UUID?, origin: String, fallback: Bool) {
            guard servings > 0, let metadata = metadata(for: components) else { return }
            let id = Self.compositionID(components)
            // Keep every saved/history name even when only one representative is displayed.
            // Named dishes also find their complete meals; ingredients inside recipes remain
            // the responsibility of ingredient search.
            searchNames[id, default: []].insert(name)
            searchNames[id, default: []].formUnion(components.compactMap { component -> String? in
                switch component.source {
                case .recipe(let sourceID): return recipes[sourceID]?.name
                case .readymeal(let sourceID), .ingredient(let sourceID): return items[sourceID]?.name
                }
            })
            guard result[id] == nil else { return }
            let mainComponents = components.filter { $0.course == .main }
            let roleNote: String?
            if fallback, let component = components.first, let role = evidence[component.source] {
                roleNote = "Used as \(role.preferred == .main ? "a main" : "a " + role.preferred.label.lowercased()) at \(mealType.label.lowercased())"
            } else {
                roleNote = components.count > 1 ? "Keeps the dishes and courses together" : nil
            }
            // Context-specific observations strengthen mains; unknown recipes retain a neutral prior.
            let mainConfidence = mainComponents.map { component in
                guard let role = evidence[component.source] else { return 0.5 }
                return (role.counts[.main, default: 0] + 0.5) / (role.total + 1)
            }.max() ?? 0
            let rank = mainConfidence * 20 + (fallback ? 0 : 20) + (components.count > 1 ? 5 : 0)
            result[id] = Candidate(
                id: id, name: name, components: components, sourceMealID: sourceMealID,
                servings: servings, originLabel: origin, roleNote: roleNote,
                ingredientIDs: metadata.ingredients, estimatedMinutes: metadata.minutes,
                isVegetarian: metadata.dietaryKnown && metadata.dietary.isDisjoint(with: [.fish, .meat]),
                isPescetarian: metadata.dietaryKnown && !metadata.dietary.contains(.meat),
                isGlutenFree: metadata.dietaryKnown && !metadata.dietary.contains(.gluten),
                recipeIDs: metadata.recipes, combinationID: Self.combinationID(components),
                rank: rank, isRecipeFallback: fallback
            )
        }

        // Prefer the reusable name and identity when a template and history describe the same meal.
        for meal in savedMeals.filter({ $0.mealType == mealType }).sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            add(meal.orderedComponents.map { MealComponentDraft(component: $0) }, name: meal.name, servings: 2,
                sourceMealID: meal.id, origin: "Saved meal", fallback: false)
        }
        for meal in history.filter({ $0.mealTypeEnum == mealType }).sorted(by: {
            $0.savedAt == $1.savedAt ? $0.id.uuidString < $1.id.uuidString : $0.savedAt > $1.savedAt
        }) {
            let draft = meal.draft
            add(draft.components, name: meal.name, servings: draft.servings,
                sourceMealID: nil, origin: "Previously planned", fallback: false)
        }
        for recipe in recipes.values.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            let source = DishID.recipe(recipe.id)
            add([MealComponentDraft(source: source, course: evidence[source]?.preferred ?? .main)],
                name: recipe.name, servings: recipe.serves, sourceMealID: nil,
                origin: "Recipe", fallback: true)
        }
        let search = filter.search.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.values.filter { candidate in
            (search.isEmpty || searchNames[candidate.id]?.contains {
                $0.localizedCaseInsensitiveContains(search)
            } == true)
                && filter.ingredientIDs.isSubset(of: candidate.ingredientIDs)
                && (!filter.quick || candidate.isQuick)
                && (!filter.vegetarian || candidate.isVegetarian)
                && (!filter.pescetarian || candidate.isPescetarian)
                && (!filter.glutenFree || candidate.isGlutenFree)
        }.sorted {
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }

    /// Pass all previously shown IDs for finite, non-repeating pages. The seed only breaks equal ranks.
    func suggestions(
        for mealType: MealType, filter: Filter = .init(),
        excluding seenIDs: Set<String> = [], seed: Int = 0
    ) -> SuggestionPage {
        let all = candidates(for: mealType, filter: filter)
        let plans = plannedMeals.filter { $0.id != excludingPlannedMealID }
            .map { $0.orderedComponents.map { MealComponentDraft(component: $0) } } + [currentComponents]
        let plannedCombinations = Set(plans.filter { !$0.isEmpty }.map(Self.combinationID))
        let plannedSources = Set(plans.flatMap { $0.map(\.source) })
        let plannedIngredients = plans.reduce(into: Set<UUID>()) { result, components in
            // Invalid editor rows don't discard the valid ingredients of the rest of the plan.
            for component in components {
                if let metadata = metadata(for: [component]) { result.formUnion(metadata.ingredients) }
            }
        }
        let plausible = all.filter {
            $0.components.contains { $0.course == .main }
                && !plannedCombinations.contains($0.combinationID)
                // Different sides, portions, or substitutions don't make an already
                // planned dish a new main. Reusing a side with another main is fine.
                && !$0.components.contains { $0.course == .main && plannedSources.contains($0.source) }
        }
        // A known pairing is the default suggestion for its main. The solo recipe stays browsable,
        // and becomes eligible when filters rule out the pairing (e.g. a meat-containing side).
        let pairedMains = Set(plausible.filter { !$0.isRecipeFallback && $0.components.count > 1 }
            .flatMap { $0.components.filter { $0.course == .main }.map(\.source) })
        func preferred(_ left: Candidate, _ right: Candidate) -> Bool {
            if left.rank != right.rank { return left.rank > right.rank }
            let leftTie = Self.tieBreaker(left.id, seed: seed), rightTie = Self.tieBreaker(right.id, seed: seed)
            return leftTie == rightTie ? left.id < right.id : leftTie < rightTie
        }
        let seenCombinations = Set((seenIDs.isEmpty ? [] : candidates(for: mealType))
            .filter { seenIDs.contains($0.id) }.map(\.combinationID))
        let eligible = plausible.filter { candidate in
            !seenIDs.contains(candidate.id) && !seenCombinations.contains(candidate.combinationID)
                && !(candidate.isRecipeFallback && candidate.components.count == 1
                     && pairedMains.contains(candidate.components[0].source))
        }
        // Portions, ordering, or substitutions remain separate browse choices, but don't consume
        // several suggestion cards or reappear as supposedly new meals on the following page.
        let pool = Dictionary(grouping: eligible, by: \.combinationID).values
            .compactMap { $0.sorted(by: preferred).first }
        var remaining = pool.sorted(by: preferred)
        var selected: [Suggestion] = []
        func take(_ candidate: Candidate, title: String, detail: String) {
            selected.append(Suggestion(candidate: candidate, title: title, detail: detail))
            remaining.removeAll { $0.id == candidate.id }
        }

        if let quickest = remaining.filter({ $0.estimatedMinutes != nil }).sorted(by: {
            if $0.estimatedMinutes != $1.estimatedMinutes { return $0.estimatedMinutes! < $1.estimatedMinutes! }
            return preferred($0, $1)
        }).first, let minutes = quickest.estimatedMinutes {
            take(quickest, title: "Quickest option", detail: "About \(minutes) min in total, cooking dishes one after another.")
        }
        if let shared = remaining.filter({ !$0.ingredientIDs.isDisjoint(with: plannedIngredients) }).sorted(by: {
            let left = $0.ingredientIDs.intersection(plannedIngredients).count
            let right = $1.ingredientIDs.intersection(plannedIngredients).count
            return left == right ? preferred($0, $1) : left > right
        }).first {
            let names = shared.ingredientIDs.intersection(plannedIngredients).compactMap { items[$0]?.name }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            take(shared, title: "Shares ingredients", detail: "Uses \(names.prefix(3).joined(separator: ", ")) from your current plan.")
        }
        while selected.count < 3, let next = remaining.first {
            take(next, title: "Not yet in this plan", detail: "A different main for \(mealType.label.lowercased()).")
        }
        return SuggestionPage(suggestions: selected, hasMore: !remaining.isEmpty)
    }

    private func roleEvidence(for mealType: MealType) -> [DishID: RoleEvidence] {
        let currentIDs = Set(plannedMeals.map(\.id))
        var observations = history.filter { $0.mealTypeEnum == mealType && !currentIDs.contains($0.id) }
            .map { Observation(components: $0.draft.components, weight: 1) }
        observations += plannedMeals.filter { $0.mealTypeEnum == mealType }
            .map { Observation(components: $0.orderedComponents.map { MealComponentDraft(component: $0) }, weight: 1) }
        let observed = Set(observations.map { Self.compositionID($0.components) })
        // Templates provide a weak prior only where actual use hasn't already supplied that meal.
        observations += savedMeals.filter {
            $0.mealType == mealType && !observed.contains(Self.compositionID($0.orderedComponents.map { MealComponentDraft(component: $0) }))
        }.map { Observation(components: $0.orderedComponents.map { MealComponentDraft(component: $0) }, weight: 0.5) }
        var result: [DishID: RoleEvidence] = [:]
        for observation in observations where metadata(for: observation.components) != nil {
            // Repeated portions of one dish in the same course are one role observation.
            var counted: Set<String> = []
            for component in observation.components {
                let key = Self.sourceID(component.source) + ":\(component.course.rawValue)"
                guard counted.insert(key).inserted else { continue }
                result[component.source, default: RoleEvidence()].counts[component.course, default: 0] += observation.weight
            }
        }
        return result
    }

    /// Fail closed for unresolved references: a missing side must not turn a meal into a new recipe.
    private func metadata(for components: [MealComponentDraft]) -> Metadata? {
        guard !components.isEmpty else { return nil }
        var result = Metadata()
        for component in components {
            guard component.hasValidPortion else { return nil }
            let minutes: Int?
            switch component.source {
            case .recipe(let id):
                guard let recipe = recipes[id], recipe.serves > 0,
                      let ingredients = try? ingredientResolver.resolve(
                        recipe.ingredients.map(RecipieIngredientDraft.init), overrides: component.ingredientOverrides
                      ) else { return nil }
                result.recipes.insert(id)
                result.dietaryKnown = result.dietaryKnown && !ingredients.isEmpty
                for ingredient in ingredients {
                    guard let item = items[ingredient.itemID] else { return nil }
                    result.ingredients.insert(item.id)
                    result.dietary.formUnion(item.dietary)
                }
                minutes = recipe.time > 0 ? recipe.time : nil
            case .readymeal(let id):
                guard let item = items[id], item.kind == ItemKind.readymeal.rawValue,
                      let data = item.readymealData, data.serves > 0 else { return nil }
                result.dietary.formUnion(item.dietary)
                minutes = data.time > 0 ? data.time : nil
            case .ingredient(let id):
                guard let quantity = component.quantity, let unitID = component.unitID,
                      (try? ingredientResolver.resolve(RecipieIngredientDraft(
                        itemID: id, unitID: unitID, quantity: quantity
                      ))) != nil, let item = items[id] else { return nil }
                result.ingredients.insert(id)
                result.dietary.formUnion(item.dietary)
                minutes = nil // Direct portions don't carry a preparation-time estimate.
            }
            if let total = result.minutes, let minutes {
                let addition = total.addingReportingOverflow(minutes)
                result.minutes = addition.overflow ? nil : addition.partialValue
            } else { result.minutes = nil }
        }
        return result
    }

    private static func sourceID(_ source: DishID) -> String {
        switch source {
        case .recipe(let id): return "r:\(id.uuidString)"
        case .readymeal(let id): return "m:\(id.uuidString)"
        case .ingredient(let id): return "i:\(id.uuidString)"
        }
    }

    private static func compositionID(_ components: [MealComponentDraft]) -> String {
        "meal:" + components.map { component in
            let overrides = component.ingredientOverrides.sorted { $0.id.uuidString < $1.id.uuidString }.map {
                "\($0.id.uuidString):\($0.itemID.uuidString):\($0.unitID.uuidString):\($0.quantity.bitPattern)"
            }.joined(separator: ",")
            return "\(sourceID(component.source))/\(component.course.rawValue)/\(component.quantity.map { String($0.bitPattern) } ?? "-")/\(component.unitID?.uuidString ?? "-")/[\(overrides)]"
        }.joined(separator: "|")
    }

    private static func combinationID(_ components: [MealComponentDraft]) -> String {
        components.map { sourceID($0.source) }.sorted().joined(separator: "|")
    }

    /// Stable across launches, unlike Swift's intentionally randomized Hasher.
    private static func tieBreaker(_ value: String, seed: Int) -> UInt64 {
        (String(seed) + value).utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
            ($0 ^ UInt64($1)) &* 1_099_511_628_211
        }
    }
}
