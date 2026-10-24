import Foundation
import Testing
@testable import meal_planner_ios

@MainActor
struct MealDiscoveryTests {
    @Test func deduplicatedMealKeepsRecipeAndHistoryNamesSearchable() throws {
        let fixture = Fixture()
        let soup = fixture.recipe("Carrot soup", ingredients: [fixture.carrot])
        let saved = Meal(name: "Weeknight dinner", mealType: .dinner,
                         components: [MealComponent(recipe: soup)])
        let remembered = try history("Soup night", components: [draft(soup)])
        let discovery = fixture.discovery(recipes: [soup], meals: [saved], history: [remembered])
        let canonical = try #require(discovery.candidates(for: .dinner).first)
        #expect(discovery.candidates(for: .dinner).count == 1)
        for name in ["Weeknight dinner", "Soup night", "  CARROT SOUP  "] {
            let matches = discovery.candidates(for: .dinner, filter: .init(search: name))
            #expect(matches.count == 1)
            #expect(matches.first?.id == canonical.id)
            #expect(matches.first?.name == saved.name)
            #expect(matches.first?.sourceMealID == saved.id)
        }
        #expect(discovery.candidates(for: .dinner, filter: .init(
            search: "Carrot soup", ingredientIDs: [fixture.bread.id]
        )).isEmpty)
    }

    @Test func dishNamesFindCompleteMealsWithoutSearchingUnderlyingIngredients() throws {
        let fixture = Fixture()
        let soup = fixture.recipe("Winter soup", ingredients: [fixture.carrot])
        let side = fixture.recipe("Mashed potatoes", ingredients: [fixture.bread])
        let saved = Meal(name: "Family meal", mealType: .dinner, components: [
            MealComponent(recipe: soup), MealComponent(recipe: side, course: .side)
        ])
        let discovery = fixture.discovery(recipes: [soup, side], meals: [saved])
        for name in ["Winter soup", "mashed"] {
            let matches = discovery.candidates(for: .dinner, filter: .init(search: name))
            let complete = try #require(matches.first { $0.sourceMealID == saved.id })
            #expect(complete.name == "Family meal")
            #expect(complete.components.map(\.source) == [.recipe(soup.id), .recipe(side.id)])
            #expect(matches.filter { $0.sourceMealID == saved.id }.count == 1)
        }
        #expect(discovery.candidates(for: .dinner, filter: .init(search: "Carrot")).isEmpty)
    }

    @Test func completeCompositionsDeduplicateAcrossHistoryButKeepPortionsAndOrder() throws {
        let fixture = Fixture()
        let recipe = fixture.recipe("Roast vegetables", ingredients: [fixture.carrot])
        let main = MealComponent(recipe: recipe)
        let side = MealComponent(ingredient: fixture.bread, unit: fixture.count, quantity: 1)
        let saved = Meal(name: "Vegetables and bread", mealType: .dinner, components: [main, side])
        let same = saved.orderedComponents.map { MealComponentDraft(copying: $0) }
        let duplicate = try history("Old name", components: same)
        var larger = same
        larger[1].quantity = 2
        let extraBread = try history("Extra bread", components: larger)
        let discovery = fixture.discovery(recipes: [recipe], meals: [saved], history: [duplicate, extraBread])
        let candidates = discovery.candidates(for: .dinner)
        let pairings = candidates.filter { $0.components.count == 2 }
        #expect(pairings.count == 2)
        let original = try #require(pairings.first { $0.sourceMealID == saved.id })
        #expect(original.name == saved.name)
        #expect(original.components.map(\.source) == [.recipe(recipe.id), .ingredient(fixture.bread.id)])
        #expect(original.components.map(\.course) == [.main, .side])
        #expect(original.components[1].quantity == 1)
        let another = fixture.discovery(recipes: [recipe], meals: [saved], history: [duplicate])
        #expect(another.candidates(for: .dinner).first { $0.sourceMealID == saved.id }?.id == original.id)

        let first = fixture.recipe("First dish", ingredients: [fixture.carrot])
        let second = fixture.recipe("Second dish", ingredients: [fixture.bread])
        let orderA = try history("First order", components: [draft(first), draft(second)])
        let orderB = try history("Reverse order", components: [draft(second), draft(first)])
        let ordered = fixture.discovery(recipes: [first, second], history: [orderA, orderB])
            .candidates(for: .dinner).filter { $0.components.count == 2 }
        #expect(Set(ordered.map(\.id)).count == 2)
    }

    @Test func actualUseOutweighsTemplateWithoutCountingLiveHistoryTwice() throws {
        let fixture = Fixture()
        let rice = fixture.recipe("Rice", ingredients: [fixture.carrot])
        let lentils = fixture.recipe("Lentils", ingredients: [fixture.carrot])
        let main = Meal(name: "Rice dinner", mealType: .dinner, components: [MealComponent(recipe: rice)])
        let plan = PlannedMeal(mealType: .dinner, day: .monday, components: [MealComponent(recipe: rice)])
        let samePlan = try history("Rice dinner", id: plan.id, components: [draft(rice)])
        let sideA = try history("Rice side", components: [draft(lentils), draft(rice, course: .side)])
        let sideB = try history("Rice side again", components: [draft(lentils), draft(rice, course: .side)])
        let lunch = try history("Rice lunch", type: .lunch, components: [draft(rice)])
        let discovery = fixture.discovery(recipes: [rice, lentils], meals: [main],
                                          history: [samePlan, sideA, sideB, lunch], plans: [plan])
        let dinnerFallback = try #require(discovery.candidates(for: .dinner).first {
            $0.originLabel == "Recipe" && $0.name == rice.name
        })
        #expect(dinnerFallback.components[0].course == .side)
        #expect(dinnerFallback.roleNote?.contains("side at dinner") == true)
        // The lunch history and standalone fallback have the same composition; either is a main.
        #expect(discovery.candidates(for: .lunch).allSatisfy { $0.components[0].course == .main })
        #expect(discovery.candidates(for: .breakfast).first?.components[0].course == .main)
    }

    @Test func suggestionsKeepKnownSidesWithTheirMainAndAllowUntriedRecipes() throws {
        let fixture = Fixture()
        let main = fixture.recipe("Bean stew", time: 20, ingredients: [fixture.carrot])
        let side = fixture.recipe("Rice", time: 8, ingredients: [fixture.bread])
        let untried = fixture.recipe("New salad", time: 12, ingredients: [fixture.carrot])
        let meal = Meal(name: "Stew and rice", mealType: .dinner, components: [
            MealComponent(recipe: main), MealComponent(recipe: side, course: .side)
        ])
        let discovery = fixture.discovery(recipes: [main, side, untried], meals: [meal])
        let all = discovery.candidates(for: .dinner)
        #expect(all.contains { $0.name == "Rice" && $0.components[0].course == .side })
        let suggestions = discovery.suggestions(for: .dinner).suggestions.map(\.candidate)
        #expect(suggestions.count == 2)
        #expect(suggestions.contains { $0.sourceMealID == meal.id && $0.components.count == 2 })
        #expect(suggestions.contains { $0.name == "New salad" })
        #expect(!suggestions.contains { $0.name == "Rice" || $0.name == "Bean stew" })
        #expect(discovery.suggestions(for: .dinner).exhausted)
    }

    @Test func ingredientsUseAndSemanticsAndDietaryFiltersCoverEveryDish() throws {
        let fixture = Fixture()
        let soup = fixture.recipe("Carrot soup", ingredients: [fixture.carrot])
        let fish = fixture.recipe("Fish", ingredients: [fixture.fish])
        let vegetableMeal = Meal(name: "Soup with bread", mealType: .lunch, components: [
            MealComponent(recipe: soup), MealComponent(ingredient: fixture.bread, unit: fixture.count, quantity: 1)
        ])
        let fishMeal = Meal(name: "Soup with fish", mealType: .lunch, components: [
            MealComponent(recipe: soup), MealComponent(recipe: fish, course: .side)
        ])
        let discovery = fixture.discovery(recipes: [soup, fish], meals: [vegetableMeal, fishMeal])
        var filter = MealDiscovery.Filter(ingredientIDs: [fixture.carrot.id, fixture.bread.id], vegetarian: true)
        let matching = discovery.candidates(for: .lunch, filter: filter)
        #expect(matching.map(\.name) == ["Soup with bread"])
        filter.glutenFree = true
        #expect(discovery.candidates(for: .lunch, filter: filter).isEmpty)
        filter = MealDiscovery.Filter(ingredientIDs: [fixture.carrot.id], vegetarian: true)
        #expect(!discovery.candidates(for: .lunch, filter: filter).contains { $0.name == "Soup with fish" })
        #expect(discovery.suggestions(for: .lunch, filter: filter).suggestions.allSatisfy { $0.candidate.isVegetarian })
        filter.search = "bread"
        #expect(discovery.candidates(for: .lunch, filter: filter).map(\.name) == ["Soup with bread"])
        filter.clearFilters()
        #expect(!filter.hasActiveFilters)
        #expect(filter.search == "bread")
    }

    @Test func pescetarianFilterAllowsFishAndVegetablesButRejectsMeatSidesAndUnknownRecipes() throws {
        let fixture = Fixture()
        let meat = Item(name: "Bacon", category: fixture.category, kind: .ingredient, dietary: [.meat])
        let fish = fixture.recipe("Fish supper", time: 10, ingredients: [fixture.fish])
        let vegetables = fixture.recipe("Vegetable supper", time: 25, ingredients: [fixture.carrot])
        let bacon = fixture.recipe("Bacon side", ingredients: [meat])
        let unknown = fixture.recipe("Undocumented supper", ingredients: [])
        let mixed = Meal(name: "Fish with bacon", mealType: .dinner, components: [
            MealComponent(recipe: fish), MealComponent(recipe: bacon, course: .side)
        ])
        let discovery = fixture.discovery(recipes: [fish, vegetables, bacon, unknown],
                                          meals: [mixed], extraItems: [meat])
        var filter = MealDiscovery.Filter()
        filter.pescetarian = true
        let candidates = discovery.candidates(for: .dinner, filter: filter)
        #expect(Set(candidates.map(\.name)) == [fish.name, vegetables.name])
        #expect(candidates.allSatisfy { $0.isPescetarian })
        #expect(discovery.candidates(for: .dinner).first { $0.name == unknown.name }?.isPescetarian == false)
        let suggestions = discovery.suggestions(for: .dinner, filter: filter).suggestions
        #expect(Set(suggestions.map { $0.candidate.name }) == [fish.name, vegetables.name])
        #expect(suggestions.allSatisfy { $0.candidate.isPescetarian })
        filter.quick = true
        #expect(discovery.suggestions(for: .dinner, filter: filter).suggestions.map { $0.candidate.name } == [fish.name])

        var lifecycle = MealDiscovery.Filter()
        lifecycle.search = "supper"
        lifecycle.pescetarian = true
        #expect(lifecycle.hasActiveFilters)
        lifecycle.clearFilters()
        #expect(!lifecycle.pescetarian)
        #expect(!lifecycle.hasActiveFilters)
        #expect(lifecycle.search == "supper")
    }

    @Test func pescetarianFilterUsesSubstitutionsIntoAndOutOfMeat() throws {
        let fixture = Fixture()
        let meat = Item(name: "Chicken", category: fixture.category, kind: .ingredient, dietary: [.meat])
        let meatRecipe = fixture.recipe("Chicken dinner", ingredients: [meat])
        let fishRecipe = fixture.recipe("Fish dinner", ingredients: [fixture.fish])
        var replacedMeat = draft(meatRecipe)
        replacedMeat.ingredientOverrides = [RecipeIngredientOverride(ingredient: RecipieIngredientDraft(
            id: meatRecipe.ingredients[0].id, itemID: fixture.fish.id, unitID: fixture.count.id, quantity: 1
        ))]
        var replacedFish = draft(fishRecipe)
        replacedFish.ingredientOverrides = [RecipeIngredientOverride(ingredient: RecipieIngredientDraft(
            id: fishRecipe.ingredients[0].id, itemID: meat.id, unitID: fixture.count.id, quantity: 1
        ))]
        let fishVersion = try history("Fish substitution", components: [replacedMeat])
        let meatVersion = try history("Meat substitution", components: [replacedFish])
        let discovery = fixture.discovery(recipes: [meatRecipe, fishRecipe],
                                          history: [fishVersion, meatVersion], extraItems: [meat])
        var filter = MealDiscovery.Filter()
        filter.pescetarian = true
        let matches = discovery.candidates(for: .dinner, filter: filter)
        #expect(Set(matches.map(\.name)) == [fishRecipe.name, fishVersion.name])
        #expect(matches.allSatisfy { $0.ingredientIDs == [fixture.fish.id] && $0.isPescetarian })
        #expect(discovery.candidates(for: .dinner).first { $0.name == meatVersion.name }?.isPescetarian == false)
        let suggestions = discovery.suggestions(for: .dinner, filter: filter).suggestions
        #expect(suggestions.count == 2)
        #expect(suggestions.allSatisfy { $0.candidate.isPescetarian })
    }

    @Test func pescetarianFilterCoversReadyMealsAndDirectPortions() throws {
        let fixture = Fixture()
        let meat = Item(name: "Ham", category: fixture.category, kind: .ingredient, dietary: [.meat])
        let fishReady = Item(name: "Fish ready meal", category: fixture.category, kind: .readymeal,
                             dietary: [.fish], readymealData: .init(serves: 1, time: 5))
        let meatReady = Item(name: "Meat ready meal", category: fixture.category, kind: .readymeal,
                             dietary: [.meat], readymealData: .init(serves: 1, time: 5))
        let ready = Meal(name: "Packaged fish", mealType: .dinner,
                         components: [MealComponent(readymeal: fishReady)])
        let packagedMeat = Meal(name: "Packaged meat", mealType: .dinner,
                                components: [MealComponent(readymeal: meatReady)])
        let fishPortion = Meal(name: "Fish portion", mealType: .dinner, components: [
            MealComponent(ingredient: fixture.fish, unit: fixture.count, quantity: 1, course: .main)
        ])
        let vegetablePortion = Meal(name: "Vegetable portion", mealType: .dinner, components: [
            MealComponent(ingredient: fixture.carrot, unit: fixture.count, quantity: 1, course: .main)
        ])
        let meatSide = Meal(name: "Fish with ham", mealType: .dinner, components: [
            MealComponent(readymeal: fishReady),
            MealComponent(ingredient: meat, unit: fixture.count, quantity: 1, course: .side)
        ])
        let discovery = fixture.discovery(recipes: [],
            meals: [ready, packagedMeat, fishPortion, vegetablePortion, meatSide],
            extraItems: [meat, fishReady, meatReady])
        var filter = MealDiscovery.Filter()
        filter.pescetarian = true
        let matches = discovery.candidates(for: .dinner, filter: filter)
        #expect(Set(matches.map(\.name)) == [ready.name, fishPortion.name, vegetablePortion.name])
        #expect(matches.allSatisfy { $0.isPescetarian })
        let suggestions = discovery.suggestions(for: .dinner, filter: filter).suggestions
        #expect(suggestions.count == 3)
        #expect(suggestions.allSatisfy { $0.candidate.isPescetarian })
    }

    @Test func substitutionsDetermineMatchingDietAndCompositionIdentity() throws {
        let fixture = Fixture()
        let recipe = fixture.recipe("Fish supper", ingredients: [fixture.fish])
        var substituted = draft(recipe)
        let ingredient = try #require(recipe.ingredients.first)
        substituted.ingredientOverrides = [RecipeIngredientOverride(ingredient: RecipieIngredientDraft(
            id: ingredient.id, itemID: fixture.carrot.id, unitID: fixture.count.id, quantity: 2
        ))]
        let remembered = try history("Vegetable supper", components: [substituted])
        let discovery = fixture.discovery(recipes: [recipe], history: [remembered])
        let all = discovery.candidates(for: .dinner)
        #expect(all.count == 2)
        #expect(Set(all.map(\.id)).count == 2)
        let vegetarian = try #require(all.first { $0.name == "Vegetable supper" })
        #expect(vegetarian.ingredientIDs == [fixture.carrot.id])
        #expect(vegetarian.isVegetarian)
        #expect(vegetarian.components[0].ingredientOverrides == substituted.ingredientOverrides)
        let fishFilter = MealDiscovery.Filter(ingredientIDs: [fixture.fish.id])
        #expect(discovery.candidates(for: .dinner, filter: fishFilter).map(\.name) == ["Fish supper"])
        let veggieFilter = MealDiscovery.Filter(ingredientIDs: [fixture.carrot.id], vegetarian: true)
        #expect(discovery.candidates(for: .dinner, filter: veggieFilter).map(\.name) == ["Vegetable supper"])
    }

    @Test func deletedOrMalformedReferencesOmitTheWholeRememberedMeal() throws {
        let fixture = Fixture()
        let valid = fixture.recipe("Carrot soup", ingredients: [fixture.carrot])
        let missingSource = try history("Incomplete dinner", components: [
            draft(valid), MealComponentDraft(source: .recipe(UUID()), course: .side)
        ])
        let missingUnit = try history("Missing portion unit", components: [
            draft(valid), MealComponentDraft(source: .ingredient(fixture.bread.id), course: .side,
                                           quantity: 1, unitID: UUID())
        ])
        var badOverride = draft(valid)
        badOverride.ingredientOverrides = [RecipeIngredientOverride(ingredient: RecipieIngredientDraft(
            id: valid.ingredients[0].id, itemID: UUID(), unitID: fixture.count.id, quantity: 1
        ))]
        let missingReplacement = try history("Missing replacement", components: [badOverride])
        let discovery = fixture.discovery(recipes: [valid], history: [missingSource, missingUnit, missingReplacement])
        #expect(discovery.candidates(for: .dinner).map(\.name) == ["Carrot soup"])
        let missingCatalog = MealDiscovery(recipes: [valid], items: [], units: [fixture.count],
                                           savedMeals: [], history: [], plannedMeals: [])
        #expect(missingCatalog.candidates(for: .dinner).isEmpty)
    }

    @Test func quickMeansTotalKnownPreparationAndUnknownDietDoesNotPassFilters() throws {
        let fixture = Fixture()
        let first = fixture.recipe("Eight minutes", time: 8, ingredients: [fixture.carrot])
        let second = fixture.recipe("Nine minutes", time: 9, ingredients: [fixture.bread])
        let zero = fixture.recipe("Unknown time", time: 0, ingredients: [fixture.carrot])
        let negative = fixture.recipe("Invalid time", time: -3, ingredients: [fixture.carrot])
        let unknownDiet = fixture.recipe("Missing ingredient details", time: 10, ingredients: [])
        let pair = Meal(name: "Seventeen minute meal", mealType: .dinner,
                        components: [MealComponent(recipe: first), MealComponent(recipe: second, course: .side)])
        let bread = Meal(name: "Soup with a portion", mealType: .dinner, components: [
            MealComponent(recipe: first), MealComponent(ingredient: fixture.bread, unit: fixture.count, quantity: 1)
        ])
        let discovery = fixture.discovery(recipes: [first, second, zero, negative, unknownDiet], meals: [pair, bread])
        let all = discovery.candidates(for: .dinner)
        #expect(all.first { $0.sourceMealID == pair.id }?.estimatedMinutes == 17)
        #expect(all.first { $0.sourceMealID == bread.id }?.estimatedMinutes == nil)
        #expect(all.first { $0.name == "Missing ingredient details" }?.isVegetarian == false)
        let quick = discovery.candidates(for: .dinner, filter: .init(quick: true))
        #expect(quick.contains { $0.name == first.name })
        #expect(!quick.contains { [pair.name, bread.name, zero.name, negative.name].contains($0.name) })
        #expect(quick.allSatisfy { $0.estimatedMinutes.map { $0 > 0 && $0 <= 15 } == true })
    }

    @Test func readyMealsAndDirectPortionsParticipateInWholeMealChecks() throws {
        let fixture = Fixture()
        let ready = Item(name: "Fish ready meal", category: fixture.category, kind: .readymeal,
                         dietary: [.fish], readymealData: .init(serves: 1, time: 4))
        let meal = Meal(name: "Packaged supper", mealType: .dinner, components: [MealComponent(readymeal: ready)])
        let portion = Meal(name: "Bread meal", mealType: .dinner, components: [
            MealComponent(ingredient: fixture.bread, unit: fixture.count, quantity: 2, course: .main)
        ])
        let discovery = fixture.discovery(recipes: [], meals: [meal, portion], extraItems: [ready])
        #expect(discovery.candidates(for: .dinner).count == 2)
        #expect(discovery.candidates(for: .dinner, filter: .init(quick: true)).map(\.name) == [meal.name])
        #expect(discovery.candidates(for: .dinner, filter: .init(vegetarian: true)).map(\.name) == [portion.name])
        #expect(discovery.candidates(for: .dinner, filter: .init(ingredientIDs: [fixture.bread.id])).map(\.name) == [portion.name])
        ready.readymealData = nil
        #expect(fixture.discovery(recipes: [], meals: [meal], extraItems: [ready]).candidates(for: .dinner).isEmpty)
    }

    @Test func suggestionPagesDoNotRepeatCombinationVariants() throws {
        let fixture = Fixture()
        let recipe = fixture.recipe("Vegetable main", ingredients: [fixture.carrot])
        let another = fixture.recipe("Another recipe", ingredients: [fixture.bread])
        let main = draft(recipe)
        let oneSlice = MealComponentDraft(source: .ingredient(fixture.bread.id), course: .main,
                                          quantity: 1, unitID: fixture.count.id)
        var twoSlices = oneSlice
        twoSlices.quantity = 2
        let first = try history("One slice", components: [main, oneSlice])
        let larger = try history("Two slices", components: [main, twoSlices])
        let reordered = try history("Different order", components: [twoSlices, main])
        let discovery = fixture.discovery(recipes: [recipe, another], history: [first, larger, reordered])
        #expect(discovery.candidates(for: .dinner).filter { $0.components.count == 2 }.count == 3)
        let page = discovery.suggestions(for: .dinner)
        #expect(page.suggestions.count == 2)
        #expect(page.suggestions.filter { $0.candidate.components.count == 2 }.count == 1)
        let seen = Set(page.suggestions.map(\.id))
        #expect(discovery.suggestions(for: .dinner, excluding: seen, seed: 123).suggestions.isEmpty)
    }

    @Test func plannedMainCannotReturnWithDifferentSidesPortionsOrderOrSubstitutions() throws {
        let fixture = Fixture()
        let chicken = fixture.recipe("Roast chicken", time: 30, ingredients: [fixture.carrot])
        let potatoes = fixture.recipe("Mashed potatoes", time: 15, ingredients: [fixture.bread])
        let curry = fixture.recipe("Lentil curry", time: 25, ingredients: [fixture.carrot])
        let planned = PlannedMeal(mealType: .dinner, day: .monday, servings: 4, components: [
            MealComponent(recipe: chicken), MealComponent(recipe: potatoes, course: .side)
        ])
        let solo = Meal(name: "Chicken by itself", mealType: .dinner,
                        components: [MealComponent(recipe: chicken)])
        let bread = MealComponentDraft(source: .ingredient(fixture.bread.id), course: .side,
                                       quantity: 1, unitID: fixture.count.id)
        var moreBread = bread
        moreBread.quantity = 2
        var substituted = draft(chicken)
        substituted.ingredientOverrides = [RecipeIngredientOverride(ingredient: RecipieIngredientDraft(
            id: chicken.ingredients[0].id, itemID: fixture.bread.id, unitID: fixture.count.id, quantity: 3
        ))]
        let variations = [
            try history("Chicken and bread", components: [draft(chicken), bread]),
            try history("Larger bread portion", components: [draft(chicken), moreBread]),
            try history("Chicken and curry", components: [draft(chicken), draft(curry)]),
            try history("Reordered mains", components: [draft(curry), draft(chicken)]),
            try history("Substituted chicken", components: [substituted])
        ]
        let discovery = fixture.discovery(recipes: [chicken, potatoes, curry], meals: [solo],
                                          history: variations, plans: [planned])
        let browsableVariations = discovery.candidates(for: .dinner).filter { candidate in
            candidate.components.contains { $0.source == .recipe(chicken.id) && $0.course == .main }
        }
        #expect(browsableVariations.count == 6)
        let page = discovery.suggestions(for: .dinner)
        #expect(page.suggestions.map { $0.candidate.name } == [curry.name])
        #expect(page.exhausted)
        let next = discovery.suggestions(for: .dinner, excluding: Set(page.suggestions.map(\.id)))
        #expect(next.suggestions.isEmpty)
        #expect(next.exhausted)
    }

    @Test(arguments: [CourseType.main, .side])
    func plannedReadyMealCannotReturnAsMainWithDifferentSides(plannedCourse: CourseType) throws {
        let fixture = Fixture()
        let ready = Item(name: "Fish ready meal", category: fixture.category, kind: .readymeal,
                         dietary: [.fish], readymealData: .init(serves: 1, time: 5))
        let different = Item(name: "Vegetable ready meal", category: fixture.category, kind: .readymeal,
                             readymealData: .init(serves: 1, time: 7))
        let planned = PlannedMeal(mealType: .dinner, day: .monday, components: [
            MealComponent(readymeal: ready, course: plannedCourse),
            MealComponent(ingredient: fixture.bread, unit: fixture.count, quantity: 1)
        ])
        let solo = Meal(name: "Fish meal alone", mealType: .dinner,
                        components: [MealComponent(readymeal: ready)])
        let alternative = Meal(name: "Vegetable meal", mealType: .dinner,
                               components: [MealComponent(readymeal: different)])
        let withCarrots = try history("Fish meal with carrots", components: [
            MealComponentDraft(source: .readymeal(ready.id)),
            MealComponentDraft(source: .ingredient(fixture.carrot.id), course: .side,
                               quantity: 2, unitID: fixture.count.id)
        ])
        let discovery = fixture.discovery(recipes: [], meals: [solo, alternative], history: [withCarrots],
                                          plans: [planned], extraItems: [ready, different])
        #expect(discovery.candidates(for: .dinner).count == 3)
        let page = discovery.suggestions(for: .dinner)
        #expect(page.suggestions.map { $0.candidate.sourceMealID } == [alternative.id])
        #expect(page.exhausted)
    }

    @Test func aDifferentMainCanReuseAnAlreadyPlannedSide() throws {
        let fixture = Fixture()
        let chicken = fixture.recipe("Roast chicken", ingredients: [fixture.carrot])
        let curry = fixture.recipe("Lentil curry", ingredients: [fixture.carrot])
        let potatoes = fixture.recipe("Mashed potatoes", ingredients: [fixture.bread])
        let planned = PlannedMeal(mealType: .dinner, day: .monday, components: [
            MealComponent(recipe: chicken), MealComponent(recipe: potatoes, course: .side)
        ])
        let alternative = Meal(name: "Curry and potatoes", mealType: .dinner, components: [
            MealComponent(recipe: curry), MealComponent(recipe: potatoes, course: .side)
        ])
        let discovery = fixture.discovery(recipes: [chicken, curry, potatoes],
                                          meals: [alternative], plans: [planned])
        let page = discovery.suggestions(for: .dinner)
        #expect(page.suggestions.count == 1)
        #expect(page.suggestions.first?.candidate.sourceMealID == alternative.id)
        #expect(page.suggestions.first?.candidate.components.map(\.source)
                == [.recipe(curry.id), .recipe(potatoes.id)])
    }

    @Test func currentPlanAndUnsavedDraftExcludeExistingMainsWhileEditedPlanIsReplaced() throws {
        let fixture = Fixture()
        let first = fixture.recipe("First meal", ingredients: [fixture.carrot])
        let second = fixture.recipe("Second meal", ingredients: [fixture.bread])
        let current = PlannedMeal(mealType: .dinner, day: .monday, components: [MealComponent(recipe: first)])
        let other = PlannedMeal(mealType: .lunch, components: [MealComponent(recipe: second)])
        let normal = fixture.discovery(recipes: [first, second], plans: [current, other])
        #expect(normal.suggestions(for: .dinner).suggestions.isEmpty)
        let editing = fixture.discovery(recipes: [first, second], plans: [current, other], excluding: current.id)
        #expect(editing.suggestions(for: .dinner).suggestions.map { $0.candidate.name } == [first.name])
        let unsaved = fixture.discovery(recipes: [first, second], plans: [current, other], excluding: current.id,
                                        current: [draft(first), draft(second, course: .side)])
        #expect(unsaved.suggestions(for: .dinner).suggestions.isEmpty)
        #expect(unsaved.candidates(for: .dinner).count == 2)

        let paired = Meal(name: "Both together", mealType: .dinner,
                          components: [MealComponent(recipe: first), MealComponent(recipe: second, course: .side)])
        let separate = fixture.discovery(recipes: [first, second], meals: [paired], plans: [current, other])
        #expect(separate.suggestions(for: .dinner).suggestions.isEmpty)
        #expect(separate.suggestions(for: .dinner).exhausted)
        #expect(separate.candidates(for: .dinner).contains { $0.sourceMealID == paired.id })

        let alsoPlannedElsewhere = PlannedMeal(mealType: .lunch, components: [MealComponent(recipe: first)])
        let editingWithAnotherOccurrence = fixture.discovery(recipes: [first, second],
            plans: [current, other, alsoPlannedElsewhere], excluding: current.id)
        #expect(editingWithAnotherOccurrence.suggestions(for: .dinner).suggestions.isEmpty)
    }

    @Test func sharedIngredientExplanationUsesEffectiveUnsavedIngredients() throws {
        let fixture = Fixture()
        let planned = fixture.recipe("Fish plan", time: 40, ingredients: [fixture.fish])
        let quick = fixture.recipe("Quick bread", time: 5, ingredients: [fixture.bread])
        let shared = fixture.recipe("Carrot meal", time: 20, ingredients: [fixture.carrot])
        var changed = draft(planned)
        changed.ingredientOverrides = [RecipeIngredientOverride(ingredient: RecipieIngredientDraft(
            id: planned.ingredients[0].id, itemID: fixture.carrot.id, unitID: fixture.count.id, quantity: 1
        ))]
        let discovery = fixture.discovery(recipes: [planned, quick, shared], current: [changed])
        let suggestions = discovery.suggestions(for: .dinner).suggestions
        let recommendation = try #require(suggestions.first { $0.title == "Shares ingredients" })
        #expect(recommendation.candidate.name == shared.name)
        #expect(recommendation.detail.contains(fixture.carrot.name))
        #expect(!recommendation.detail.contains(fixture.fish.name))
    }

    @Test func paginationIsFiniteDistinctDeterministicAndKeepsFilters() throws {
        let fixture = Fixture()
        let recipes = (0..<7).map { fixture.recipe("Meal \($0)", time: 12, ingredients: [fixture.carrot]) }
        let meat = fixture.recipe("Fish meal", time: 10, ingredients: [fixture.fish])
        let discovery = fixture.discovery(recipes: recipes + [meat])
        let filter = MealDiscovery.Filter(quick: true, vegetarian: true)
        let first = discovery.suggestions(for: .dinner, filter: filter, seed: 12)
        let repeated = discovery.suggestions(for: .dinner, filter: filter, seed: 12)
        #expect(first.suggestions.map(\.id) == repeated.suggestions.map(\.id))
        #expect(first.suggestions.count == 3)
        #expect(first.hasMore)
        var seen = Set(first.suggestions.map(\.id))
        let second = discovery.suggestions(for: .dinner, filter: filter, excluding: seen, seed: 13)
        #expect(second.suggestions.count == 3)
        #expect(seen.isDisjoint(with: second.suggestions.map(\.id)))
        seen.formUnion(second.suggestions.map(\.id))
        let last = discovery.suggestions(for: .dinner, filter: filter, excluding: seen)
        #expect(last.suggestions.count == 1)
        #expect(last.exhausted)
        seen.formUnion(last.suggestions.map(\.id))
        #expect(seen.count == 7)
        #expect(discovery.suggestions(for: .dinner, filter: filter, excluding: seen).suggestions.isEmpty)
        #expect((first.suggestions + second.suggestions + last.suggestions).allSatisfy {
            $0.candidate.isVegetarian && $0.candidate.isQuick
        })
    }

    @Test func tinyOrSideOnlyCollectionsDoNotInventThreeDinners() throws {
        let fixture = Fixture()
        #expect(fixture.discovery(recipes: []).suggestions(for: .dinner).exhausted)
        let recipe = fixture.recipe("Rice", ingredients: [fixture.carrot])
        let new = fixture.discovery(recipes: [recipe]).suggestions(for: .dinner)
        #expect(new.suggestions.count == 1)
        #expect(new.exhausted)
        let usedAsSide = try history("Rice as side", components: [draft(recipe, course: .side)])
        let learned = fixture.discovery(recipes: [recipe], history: [usedAsSide])
        #expect(learned.candidates(for: .dinner).count == 1)
        #expect(learned.suggestions(for: .dinner).suggestions.isEmpty)
    }

    private func draft(_ recipe: Recipie, course: CourseType = .main) -> MealComponentDraft {
        MealComponentDraft(source: .recipe(recipe.id), course: course)
    }

    private func history(_ name: String, id: UUID = UUID(), type: MealType = .dinner,
                         components: [MealComponentDraft]) throws -> MealHistory {
        try MealHistory(id: id, name: name, mealType: type, components: components)
    }

    @MainActor private final class Fixture {
        let category = meal_planner_ios.Category(name: "Food", order: 0)
        let count = meal_planner_ios.Unit(name: "count", type: .count, magnitudes: [])
        lazy var carrot = Item(name: "Carrot", category: category, kind: .ingredient)
        lazy var bread = Item(name: "Bread", category: category, kind: .ingredient, dietary: [.gluten])
        lazy var fish = Item(name: "Fish", category: category, kind: .ingredient, dietary: [.fish])

        func recipe(_ name: String, time: Int = 20, ingredients: [Item]) -> Recipie {
            Recipie(name: name, serves: 2, time: time,
                    ingredients: ingredients.map { RecipieIngredient(item: $0, unit: count, quantity: 1) })
        }

        func discovery(recipes: [Recipie], meals: [Meal] = [], history: [MealHistory] = [],
                       plans: [PlannedMeal] = [], excluding: UUID? = nil,
                       current: [MealComponentDraft] = [], extraItems: [Item] = []) -> MealDiscovery {
            MealDiscovery(recipes: recipes, items: [carrot, bread, fish] + extraItems, units: [count],
                          savedMeals: meals, history: history, plannedMeals: plans,
                          excludingPlannedMealID: excluding, currentComponents: current)
        }
    }
}
