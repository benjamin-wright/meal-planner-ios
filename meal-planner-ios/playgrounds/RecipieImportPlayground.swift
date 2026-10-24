#if DEBUG
import Foundation
import Playgrounds
import UIKit

// Only the image inputs belong here. Tune the app's shared services and schemas.
#Playground("Recipe images to ingredients and steps") {
    let imagePaths = [
        "E13AC9D2-CD25-4FBE-BBE0-76A1520FD80B_1_201_a.heic",
        "8A850FEE-A263-4732-9679-54B5EA1E6475.heic"
    ]
    guard imagePaths.count <= RecipieImportPipeline.maximumPages else { throw RecipieImportError.tooManyPages }
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let originalData = try imagePaths.map { try Data(contentsOf: directory.appendingPathComponent($0)) }
    let originalImages = originalData.compactMap { UIImage(data: $0) }
    let preparedData = try originalData.map { try RecipieImportImage.prepare($0) }
    let preparedImages = preparedData.compactMap { UIImage(data: $0) }
    let started = ContinuousClock.now
    let text = try await RecipieImportPipeline.recognize(pages: preparedData)
    print(text)
    let recipe = try await RecipiePlaygroundSupport.withoutAutomaticModelFeedback {
        try await FoundationRecipieExtractor().extract(from: text, preservingGenerationErrors: true)
    }
    let elapsed = started.duration(to: .now)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let recipeJSON = String(decoding: try encoder.encode(recipe), as: UTF8.self)
    print(recipeJSON)
    print("OCR and extraction: \(elapsed)")
    // Keep these as named values for expandable canvas image previews.
    _ = originalImages
    _ = preparedImages
}

/// Real model checks for matching prompt/schema changes. No photographs, PDFs or saved catalogue are needed.
/// A snippet can run a subset with `try await RecipieIngredientMatchingPlayground.run(names: ["Ambiguous beef"])`.
@MainActor
enum RecipieIngredientMatchingPlayground {
    struct Result {
        let name: String
        let expected: String
        let actual: String
        let elapsed: Duration
        let passed: Bool
    }

    private struct Case {
        let name: String
        let ingredient: String
        let sourceText: String
        let recipeName: String?
        let candidates: [String]
        let expected: String?
        var acceptsAbstention = false
    }

    private static let cases: [Case] = [
        Case(name: "Ambiguous beef", ingredient: "beef", sourceText: "200 g beef", recipeName: nil,
             candidates: ["beef steak", "beef mince"], expected: nil),
        Case(name: "Bolognese resolves beef", ingredient: "beef", sourceText: "200 g beef", recipeName: "Spaghetti bolognese",
             candidates: ["beef steak", "beef mince"], expected: "beef mince"),
        Case(name: "Explicit steak overrides dish", ingredient: "beef", sourceText: "200 g beef steak, diced",
             recipeName: "Spaghetti bolognese", candidates: ["beef mince", "beef steak"], expected: "beef steak",
             acceptsAbstention: true),
        Case(name: "Apples are not sauce", ingredient: "apples", sourceText: "2 apples", recipeName: "Apple pie",
             candidates: ["apple sauce"], expected: nil),
        Case(name: "Apples match singular apple", ingredient: "apples", sourceText: "2 apples", recipeName: "Apple pie",
             candidates: ["apple sauce", "apple"], expected: "apple"),
        Case(name: "Preserve dietary qualifier", ingredient: "milk", sourceText: "200 ml lactose-free milk",
             recipeName: "Pancakes", candidates: ["whole milk", "semi-skimmed milk"], expected: nil),
        Case(name: "Preserve fresh form", ingredient: "coriander", sourceText: "a handful of fresh coriander leaves",
             recipeName: "Chicken curry", candidates: ["ground coriander", "coriander seeds"], expected: nil),
        Case(name: "Preserve gluten-free requirement", ingredient: "flour", sourceText: "100 g gluten-free flour",
             recipeName: "Pancakes", candidates: ["plain flour", "self-raising flour"], expected: nil),
        Case(name: "Select qualified milk", ingredient: "milk", sourceText: "200 ml lactose-free milk",
             recipeName: "Pancakes", candidates: ["whole milk", "lactose-free milk"], expected: "lactose-free milk"),
        Case(name: "Select fresh herb", ingredient: "coriander", sourceText: "a handful of fresh coriander leaves",
             recipeName: "Chicken curry", candidates: ["coriander seeds", "fresh coriander leaves"], expected: "fresh coriander leaves"),
        Case(name: "Preserve fresh versus dried", ingredient: "parsley", sourceText: "a handful of fresh parsley",
             recipeName: "Tomato soup", candidates: ["dried parsley"], expected: nil),
        Case(name: "Seeds are not leaves", ingredient: "fennel", sourceText: "1 tsp fennel seeds",
             recipeName: "Tomato sauce", candidates: ["fresh fennel leaves", "fennel bulb"], expected: nil),
        Case(name: "Cheddar with full shortlist", ingredient: "cheddar", sourceText: "50 grams of cheddar",
             recipeName: "Cheese sauce", candidates: [
                "cheddar cheese", "feta cheese", "cream cheese", "cheese sauce", "butter", "milk", "chard",
                "carrots", "onions", "garlic", "potatoes", "tomatoes", "rice", "pasta", "flour", "eggs",
                "salt", "pepper", "olive oil", "chicken", "beef", "pork", "salmon", "tuna", "apples",
                "pears", "bananas", "oranges", "lemons", "limes", "spinach", "broccoli", "cauliflower",
                "cabbage", "lettuce", "cucumber", "celery", "peas", "sweetcorn", "beans", "lentils",
                "chickpeas", "yoghurt", "cream", "sugar", "honey", "oats", "bread", "mustard", "vinegar"
             ], expected: "cheddar cheese")
    ]

    /// Run sequentially to avoid competing for the device model. Errors count as failures, not safe abstentions.
    /// Explicit steak permits abstention, matching the platform test: it must never become beef mince.
    static func run(names: [String]? = nil) async throws -> [Result] {
        var results: [Result] = []
        let selector = FoundationRecipieIngredientSelector()
        for fixture in cases where names?.contains(fixture.name) ?? true {
            try Task.checkCancellation()
            let catalogue = fixture.candidates.map { RecipieIngredientCatalogEntry(itemID: UUID(), name: $0) }
            let candidates = RecipieIngredientMatching.candidates(for: fixture.ingredient, in: catalogue)
            let ingredient = ExtractedRecipieIngredient(sourceText: fixture.sourceText, name: fixture.ingredient,
                                                       quantity: nil, unit: "")
            let started = ContinuousClock.now
            let expected = (fixture.expected ?? "no match") + (fixture.acceptsAbstention ? " or no match" : "")
            let result: Result
            do {
                let selection = try await RecipiePlaygroundSupport.withoutAutomaticModelFeedback {
                    try await selector.select(for: ingredient, recipeName: fixture.recipeName, from: candidates)
                }
                let actual = catalogue.first { $0.itemID == selection }?.name
                let passed = selection == nil
                    ? fixture.expected == nil || fixture.acceptsAbstention
                    : actual != nil && actual == fixture.expected
                result = Result(name: fixture.name, expected: expected, actual: actual ?? "no match",
                                elapsed: started.duration(to: .now), passed: passed)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                result = Result(name: fixture.name, expected: expected, actual: "Error: \(error)",
                                elapsed: started.duration(to: .now), passed: false)
            }
            print("\(result.passed ? "PASS" : "FAIL") \(result.name): expected \(result.expected), got \(result.actual) (\(result.elapsed))")
            results.append(result)
        }
        print("Matching regression checks: \(results.filter(\.passed).count)/\(results.count) passed")
        return results
    }
}

#Playground("Ingredient matching accuracy and latency") {
    let results = try await RecipieIngredientMatchingPlayground.run()
    _ = results
}
#endif
