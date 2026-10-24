import Foundation
import Testing
@testable import meal_planner_ios

struct RecipieMatchingFlowTests {
    @MainActor
    @Test(arguments: MatchingBudgetCase.allCases)
    func matchingBudgetPreservesExtractionAndCompletedMatches(budget: MatchingBudgetCase) async throws {
        let fixture = MatchingFlowFixture()
        let selector = MatchingFlowSelector(selections: fixture.selections)
        let model = RecipieImportModel(extractor: MatchingFlowExtractor([fixture.recipe]),
                                      ingredientSelector: selector, matchingLimits: budget.limits)
        model.pdfPages = [matchingFlowPage()]
        let operation = try #require(model.extractPDF(catalogue: fixture.catalogue))
        let finished = MatchingFlowSignal()
        let observer = Task {
            await operation.value
            await finished.signal()
        }

        #expect(await selector.blocked.wait())
        // The selector deliberately ignores task cancellation. A structured task-group
        // timeout would still wait for it, leaving the recipe inaccessible here.
        #expect(await finished.wait())
        #expect(model.result == fixture.recipeWithFirstMatch)
        #expect(!model.isBusy)
        #expect(!model.canReview)
        #expect(model.error == nil)
        #expect(await selector.requests == ["cheddar", "apples"])

        await selector.release()
        await observer.value
        #expect(model.result == fixture.recipeWithFirstMatch)
        #expect(await selector.requests == ["cheddar", "apples"])
    }

    @MainActor
    @Test func reviewNowPublishesCompletedMatchesWithoutWaitingForTheCurrentSelector() async throws {
        let fixture = MatchingFlowFixture()
        let selector = MatchingFlowSelector(selections: fixture.selections)
        let model = RecipieImportModel(extractor: MatchingFlowExtractor([fixture.recipe]),
                                      ingredientSelector: selector, matchingLimits: .init(
                                        perIngredient: .seconds(30), total: .seconds(60)))
        model.pdfPages = [matchingFlowPage()]
        let operation = try #require(model.extractPDF(catalogue: fixture.catalogue))
        #expect(!model.canReview)
        #expect(await selector.blocked.wait())
        #expect(model.canReview)
        #expect(model.result == nil)

        model.reviewNow()

        // These assertions precede releasing the stuck selector: review must be immediate.
        #expect(model.result == fixture.recipeWithFirstMatch)
        #expect(!model.isBusy)
        #expect(!model.canReview)
        #expect(model.error == nil)
        await selector.release()
        await operation.value
        #expect(model.result == fixture.recipeWithFirstMatch)
        #expect(await selector.requests == ["cheddar", "apples"])
    }

    @MainActor
    @Test func reviewingBeforeAnyMatchCompletesStillPreservesTheWholeRecipe() async throws {
        let fixture = MatchingFlowFixture()
        let selector = MatchingFlowSelector(selections: fixture.selections, blockedRequest: 1)
        let model = RecipieImportModel(extractor: MatchingFlowExtractor([fixture.recipe]),
                                      ingredientSelector: selector)
        model.pdfPages = [matchingFlowPage()]
        let operation = try #require(model.extractPDF(catalogue: fixture.catalogue))
        #expect(await selector.blocked.wait())

        model.reviewNow()

        #expect(model.result == fixture.recipe)
        #expect(!model.isBusy)
        await selector.release()
        await operation.value
        #expect(model.result == fixture.recipe)
        #expect(await selector.requests == ["cheddar"])
    }

    @MainActor
    @Test func cancelledMatchingDiscardsTheDraftInsteadOfPublishingIt() async throws {
        let fixture = MatchingFlowFixture()
        let selector = MatchingFlowSelector(selections: fixture.selections)
        let model = RecipieImportModel(extractor: MatchingFlowExtractor([fixture.recipe]),
                                      ingredientSelector: selector)
        model.pdfPages = [matchingFlowPage()]
        let operation = try #require(model.extractPDF(catalogue: fixture.catalogue))
        #expect(await selector.blocked.wait())
        #expect(model.canReview)

        model.cancel()

        #expect(model.result == nil)
        #expect(!model.isBusy)
        #expect(!model.canReview)
        model.reviewNow()
        #expect(model.result == nil)
        await selector.release()
        await operation.value
        #expect(model.result == nil)
        #expect(model.error == nil)
        #expect(await selector.requests == ["cheddar", "apples"])
    }

    @MainActor
    @Test func lateMatchCannotOverwriteARecipeImportedAfterReviewing() async throws {
        let fixture = MatchingFlowFixture()
        var replacement = fixture.recipe
        replacement.name = "A different recipe"
        replacement.steps = ["Prepare the replacement recipe."]
        let selector = MatchingFlowSelector(selections: fixture.selections)
        let model = RecipieImportModel(extractor: MatchingFlowExtractor([fixture.recipe, replacement]),
                                      ingredientSelector: selector)
        model.pdfPages = [matchingFlowPage()]
        let firstOperation = try #require(model.extractPDF(catalogue: fixture.catalogue))
        #expect(await selector.blocked.wait())
        model.reviewNow()
        #expect(model.result == fixture.recipeWithFirstMatch)

        let secondOperation = model.extractPDF()
        #expect(secondOperation != nil)
        #expect(model.result == nil)
        #expect(!model.canReview)
        await secondOperation?.value
        #expect(model.result == replacement)

        await selector.release()
        await firstOperation.value
        #expect(model.result == replacement)
        #expect(!model.isBusy)
        #expect(!model.canReview)
        #expect(model.error == nil)
    }
}

enum MatchingBudgetCase: CaseIterable {
    case perIngredient, entireImport

    var limits: RecipieMatchingLimits {
        switch self {
        case .perIngredient: .init(perIngredient: .milliseconds(250), total: .seconds(30))
        case .entireImport: .init(perIngredient: .seconds(30), total: .milliseconds(250))
        }
    }
}

private struct MatchingFlowFixture {
    let catalogue = [
        RecipieIngredientCatalogEntry(itemID: UUID(), name: "cheddar cheese"),
        RecipieIngredientCatalogEntry(itemID: UUID(), name: "apple"),
        RecipieIngredientCatalogEntry(itemID: UUID(), name: "tomato")
    ]
    let recipe = ExtractedRecipie(
        isRecipe: true, name: "Cheese and fruit salad", summary: "A simple lunch", serves: 2,
        cookingMinutes: 5,
        ingredients: [
            ExtractedRecipieIngredient(sourceText: "50 g cheddar, grated", name: "cheddar", quantity: 50, unit: "g"),
            ExtractedRecipieIngredient(sourceText: "2 apples, sliced", name: "apples", quantity: 2, unit: "count"),
            ExtractedRecipieIngredient(sourceText: "3 tomatoes, chopped", name: "tomatoes", quantity: 3, unit: "count")
        ], steps: ["Prepare the fruit and tomatoes.", "Toss with the cheese."])

    var selections: [String: UUID] {
        Dictionary(uniqueKeysWithValues: zip(recipe.ingredients.map(\.name), catalogue.map(\.itemID)))
    }

    var recipeWithFirstMatch: ExtractedRecipie {
        var result = recipe
        result.matchedItemIDs[0] = catalogue[0].itemID
        return result
    }
}

private func matchingFlowPage() -> RecipiePDFPage {
    RecipiePDFPage(pageNumber: 1, text: "Recipe ingredients and method", thumbnailData: Data())
}

private actor MatchingFlowExtractor: RecipieExtracting {
    private var recipes: [ExtractedRecipie]

    init(_ recipes: [ExtractedRecipie]) { self.recipes = recipes }

    func extract(from text: String) async throws -> ExtractedRecipie {
        recipes.removeFirst()
    }
}

private actor MatchingFlowSelector: RecipieIngredientSelecting {
    let blocked = MatchingFlowSignal()
    private let selections: [String: UUID]
    private let blockedRequest: Int
    private(set) var requests: [String] = []
    private var continuation: CheckedContinuation<Void, Never>?
    private var isReleased = false

    init(selections: [String: UUID], blockedRequest: Int = 2) {
        self.selections = selections
        self.blockedRequest = blockedRequest
    }

    func select(for ingredient: ExtractedRecipieIngredient, recipeName: String?,
                from candidates: [RecipieIngredientCandidate]) async throws -> UUID? {
        requests.append(ingredient.name)
        if requests.count == blockedRequest {
            await blocked.signal()
            if !isReleased {
                await withCheckedContinuation { continuation = $0 }
            }
        }
        // Do not check cancellation: the tests exercise an inference call that is
        // slow to cooperate with cancellation and eventually returns a stale choice.
        return selections[ingredient.name]
    }

    func release() {
        isReleased = true
        continuation?.resume()
        continuation = nil
    }
}

/// An observable milestone with a deadline keeps a broken timeout implementation
/// from hanging the test runner; the tests then release their suspended selector.
private actor MatchingFlowSignal {
    private var outcome: Bool?
    private var continuation: CheckedContinuation<Bool, Never>?
    private var timer: Task<Void, Never>?

    func signal() { complete(true) }

    func wait() async -> Bool {
        if let outcome { return outcome }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            timer = Task {
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                complete(false)
            }
        }
    }

    private func complete(_ value: Bool) {
        guard outcome == nil else { return }
        outcome = value
        timer?.cancel()
        timer = nil
        continuation?.resume(returning: value)
        continuation = nil
    }
}
