import Foundation
import Testing
@testable import meal_planner_ios

struct RecipieIngredientMatchingTests {
    @MainActor
    @Test func catalogueContainsOnlyIngredientItems() {
        let category = Category(name: "Dairy", order: 0)
        let cheese = Item(name: "Cheddar cheese", category: category, kind: .ingredient)
        let meal = Item(name: "Cheddar pasta", category: category, kind: .readymeal)
        let miscellaneous = Item(name: "Cheddar storage box", category: category, kind: .misc)

        let catalogue = RecipieIngredientMatching.catalogue(from: [meal, cheese, miscellaneous])

        #expect(catalogue == [RecipieIngredientCatalogEntry(itemID: cheese.id, name: cheese.name)])
    }

    @Test func shortlistKeepsCheddarTokenMatchAndIsBoundedAndStable() {
        let cheese = entry("Cheddar cheese")
        let catalogue = (0..<80).map { entry("Pantry ingredient \($0)") } + [cheese]

        let candidates = RecipieIngredientMatching.candidates(for: "cheddar", in: catalogue)
        let reordered = RecipieIngredientMatching.candidates(for: "cheddar", in: Array(catalogue.reversed()))

        #expect(candidates.count == 50)
        #expect(candidates.first?.itemID == cheese.itemID)
        #expect(candidates.allSatisfy { (0...100).contains($0.score) })
        #expect(candidates.map(\.score) == candidates.map(\.score).sorted(by: >))
        #expect(Set(candidates.map(\.itemID)).count == 50)
        #expect(candidates == reordered)
    }

    @Test func exactMatchesDoNotAcceptSimilarSpellings() {
        let apple = entry("apple")
        let milk = entry("Milk")
        let cheese = entry("Cheddar cheese")
        let catalogue = [apple, milk, cheese]

        #expect(RecipieIngredientMatching.exactMatch(for: " milk ", in: catalogue) == milk.itemID)
        #expect(RecipieIngredientMatching.exactMatch(for: "apples", in: catalogue) == nil)
        #expect(RecipieIngredientMatching.exactMatch(for: "applf", in: catalogue) == nil)
        #expect(RecipieIngredientMatching.exactMatch(for: "mil", in: catalogue) == nil)
        #expect(RecipieIngredientMatching.exactMatch(for: "cheddar", in: catalogue) == nil)
    }

    @Test func onlyExactMatchesSkipTheSemanticSelector() async throws {
        let catalogue = [entry("apple"), entry("milk")]
        let original = recipe([ingredient("milk"), ingredient("apples"), ingredient("applf")])
        let selector = RecordingIngredientSelector()

        let result = try await RecipieIngredientMatching.matching(original, catalogue: catalogue, selector: selector)

        #expect(await selector.requests.map(\.ingredient.name) == ["apples", "applf"])
        #expect(result.ingredients == original.ingredients)
    }

    @MainActor
    @Test func similarSpellingCannotOverrideASemanticRejection() async throws {
        let category = Category(name: "Milk", order: 0)
        let goatMilk = Item(name: "goat milk", category: category, kind: .ingredient)
        let source = ingredient("oat milk")
        let selector = RecordingIngredientSelector()
        let result = try await RecipieIngredientMatching.matching(
            recipe([source]), catalogue: RecipieIngredientMatching.catalogue(from: [goatMilk]), selector: selector
        )

        #expect(await selector.requests.first?.candidates.first?.itemID == goatMilk.id)
        #expect(result.matchedItemIDs.isEmpty)
        var draft = RecipieDraft()
        RecipieImportMapper.apply(result, to: &draft, items: [goatMilk], units: [weightUnit()])
        #expect(draft.importedIngredients?.first?.itemID == nil)
        #expect(draft.importedIngredients?.first?.sourceText == source.sourceText)
    }

    @MainActor
    @Test func semanticChoiceUsesScoredCandidatesAndPreservesTheOriginalAmountAndText() async throws {
        let category = Category(name: "Dairy", order: 0)
        let cheese = Item(name: "Cheddar cheese", category: category, kind: .ingredient)
        let butter = Item(name: "Butter", category: category, kind: .ingredient)
        let catalogue = RecipieIngredientMatching.catalogue(from: [butter, cheese])
        let source = ExtractedRecipieIngredient(
            sourceText: "50 grams of cheddar", name: "cheddar", quantity: 50, unit: "grams"
        )
        let original = recipe([source])
        let selector = RecordingIngredientSelector(selections: ["cheddar": cheese.id])

        let result = try await RecipieIngredientMatching.matching(original, catalogue: catalogue, selector: selector)

        let request = try #require(await selector.requests.first)
        #expect(request.ingredient == source)
        #expect(request.recipeName == original.name)
        #expect(request.candidates == RecipieIngredientMatching.candidates(for: "cheddar", in: catalogue))
        #expect(result.matchedItemIDs[0] == cheese.id)
        #expect(result.ingredients == original.ingredients)
        #expect(result.name == original.name)
        #expect(result.steps == original.steps)

        let grams = weightUnit()
        var draft = RecipieDraft()
        RecipieImportMapper.apply(result, to: &draft, items: [cheese, butter], units: [grams])
        let mapped = try #require(draft.importedIngredients?.first)
        #expect(mapped.itemID == cheese.id)
        #expect(mapped.sourceText == "50 grams of cheddar")
        #expect(mapped.name == "cheddar")
        #expect(mapped.quantityText == "50")
        #expect(mapped.quantity(units: [grams]) == 50)
        #expect(mapped.isResolved(items: [cheese, butter], units: [grams]))
    }

    @Test func recipeTitleProvidesContextForAnAmbiguousIngredient() async throws {
        let mince = entry("Beef mince")
        let steak = entry("Beef steak")
        let source = ExtractedRecipieIngredient(
            sourceText: "500 grams of beef", name: "beef", quantity: 500, unit: "grams"
        )
        var original = recipe([source])
        original.name = "Spaghetti Bolognese"
        let selector = RecordingIngredientSelector(selections: ["beef": mince.itemID])

        let result = try await RecipieIngredientMatching.matching(
            original, catalogue: [steak, mince], selector: selector
        )

        let request = try #require(await selector.requests.first)
        #expect(request.recipeName == "Spaghetti Bolognese")
        #expect(request.ingredient == source)
        #expect(Set(request.candidates.map(\.itemID)) == Set([mince.itemID, steak.itemID]))
        #expect(result.matchedItemIDs[0] == mince.itemID)
        #expect(result.ingredients == [source])
        #expect(result.name == original.name)
    }

    @Test func noMatchAndUnknownSelectionsLeaveTheIngredientUnresolved() async throws {
        let catalogue = [entry("Cheddar cheese")]
        let original = recipe([ingredient("cheddar")])
        let selectors = [
            RecordingIngredientSelector(),
            RecordingIngredientSelector(selections: ["cheddar": UUID()])
        ]

        for selector in selectors {
            let result = try await RecipieIngredientMatching.matching(original, catalogue: catalogue, selector: selector)
            #expect(result.matchedItemIDs[0] == nil)
            #expect(result.ingredients == original.ingredients)
            #expect(await selector.requests.count == 1)
        }
    }

    @Test func selectionsOutsideTheSuppliedShortlistAreRejected() async throws {
        let catalogue = (0..<80).map { entry("Pantry ingredient \($0)") } + [entry("Cheddar cheese")]
        let candidates = RecipieIngredientMatching.candidates(for: "cheddar", in: catalogue)
        let omitted = try #require(catalogue.first { candidate in
            !candidates.contains { $0.itemID == candidate.itemID }
        })
        let selector = RecordingIngredientSelector(selections: ["cheddar": omitted.itemID])

        let result = try await RecipieIngredientMatching.matching(
            recipe([ingredient("cheddar")]), catalogue: catalogue, selector: selector
        )

        #expect(result.matchedItemIDs[0] == nil)
        #expect(await selector.requests.first?.candidates.count == 50)
    }

    @Test func failedSelectionKeepsExtractionAndContinuesWithOtherIngredients() async throws {
        let cheese = entry("Cheddar cheese")
        let tomato = entry("Tomato paste")
        let original = recipe([ingredient("cheddar"), ingredient("tomato concentrate")])
        let selector = RecordingIngredientSelector(
            selections: ["tomato concentrate": tomato.itemID], failures: ["cheddar"]
        )

        let result = try await RecipieIngredientMatching.matching(
            original, catalogue: [cheese, tomato], selector: selector
        )

        #expect(result.matchedItemIDs[0] == nil)
        #expect(result.matchedItemIDs[1] == tomato.itemID)
        #expect(result.ingredients == original.ingredients)
        #expect(await selector.requests.count == 2)
    }

    @Test func duplicateNormalizedNamesCannotBeSelectedAutomaticallyOrSemantically() async throws {
        let cheese = entry("Cheddar cheese")
        let duplicate = entry(" CHEDDAR   CHEESE ")
        let catalogue = [cheese, duplicate]
        let selector = RecordingIngredientSelector(selections: ["cheddar": cheese.itemID])

        #expect(RecipieIngredientMatching.exactMatch(for: "cheddar cheese", in: catalogue) == nil)
        let result = try await RecipieIngredientMatching.matching(
            recipe([ingredient("cheddar")]), catalogue: catalogue, selector: selector
        )

        #expect(result.matchedItemIDs[0] == nil)
    }

    @MainActor
    @Test func mappingRejectsMissingAndChangedKindSelections() {
        let category = Category(name: "Dairy", order: 0)
        let cheese = Item(name: "Cheddar cheese", category: category, kind: .ingredient)
        let source = ingredient("cheddar")

        let missing = RecipieImportMapper.ingredient(source, items: [], units: [], matchedItemID: cheese.id)
        #expect(missing.itemID == nil)

        cheese.kind = ItemKind.misc.rawValue
        let changedKind = RecipieImportMapper.ingredient(
            source, items: [cheese], units: [], matchedItemID: cheese.id
        )
        #expect(changedKind.itemID == nil)
    }

    @MainActor
    @Test func mappingRejectsSelectionsThatHaveBecomeAmbiguous() {
        let category = Category(name: "Dairy", order: 0)
        let cheese = Item(name: "Cheddar cheese", category: category, kind: .ingredient)
        let duplicate = Item(name: " CHEDDAR   CHEESE ", category: category, kind: .ingredient)

        let result = RecipieImportMapper.ingredient(
            ingredient("cheddar"), items: [cheese, duplicate], units: [], matchedItemID: cheese.id
        )

        #expect(result.itemID == nil)
    }

    @MainActor
    @Test func filteringNoiseKeepsMatchesAlignedWithTheOriginalIngredientIndices() throws {
        let category = Category(name: "Dairy", order: 0)
        let cheese = Item(name: "Cheddar cheese", category: category, kind: .ingredient)
        let noise = ExtractedRecipieIngredient(sourceText: "A1,A3", name: "A1,A3", quantity: nil, unit: "")
        let source = ExtractedRecipieIngredient(
            sourceText: "50 grams of cheddar", name: "cheddar", quantity: 50, unit: "grams"
        )
        var extracted = recipe([noise, source])
        extracted.matchedItemIDs = [1: cheese.id]
        var draft = RecipieDraft()

        RecipieImportMapper.apply(extracted, to: &draft, items: [cheese], units: [weightUnit()])

        let rows = try #require(draft.importedIngredients)
        #expect(rows.count == 1)
        #expect(rows.first?.itemID == cheese.id)
        #expect(rows.first?.sourceText == source.sourceText)
    }

    private func entry(_ name: String) -> RecipieIngredientCatalogEntry {
        RecipieIngredientCatalogEntry(itemID: UUID(), name: name)
    }

    private func ingredient(_ name: String) -> ExtractedRecipieIngredient {
        ExtractedRecipieIngredient(sourceText: "50 grams of \(name)", name: name, quantity: 50, unit: "grams")
    }

    private func recipe(_ ingredients: [ExtractedRecipieIngredient]) -> ExtractedRecipie {
        ExtractedRecipie(isRecipe: true, name: "Cheese sauce", summary: "A simple sauce", serves: 2,
                        cookingMinutes: 10, ingredients: ingredients, steps: ["Mix the ingredients."])
    }

    private func weightUnit() -> meal_planner_ios.Unit {
        Unit(name: "grams", type: .weight, magnitudes: [
            Magnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1)
        ])
    }
}

private actor RecordingIngredientSelector: RecipieIngredientSelecting {
    struct Request {
        let ingredient: ExtractedRecipieIngredient
        let recipeName: String?
        let candidates: [RecipieIngredientCandidate]
    }

    enum Failure: Error { case unavailable }

    let selections: [String: UUID]
    let failures: Set<String>
    private(set) var requests: [Request] = []

    init(selections: [String: UUID] = [:], failures: Set<String> = []) {
        self.selections = selections
        self.failures = failures
    }

    func select(for ingredient: ExtractedRecipieIngredient,
                recipeName: String?,
                from candidates: [RecipieIngredientCandidate]) async throws -> UUID? {
        requests.append(Request(ingredient: ingredient, recipeName: recipeName, candidates: candidates))
        if failures.contains(ingredient.name) { throw Failure.unavailable }
        return selections[ingredient.name]
    }
}
