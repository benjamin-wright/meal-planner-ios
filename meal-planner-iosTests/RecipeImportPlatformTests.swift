import Foundation
import FoundationModels
import Testing
import UIKit
@testable import meal_planner_ios

/// Live framework checks, selected explicitly by the Platform Integration test plan.
@Suite(.serialized)
struct RecipeImportPlatformTests {
    @MainActor
    @Test func visionRecognizesRenderedRecipeText() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1000))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 1000))
            let text = "CARROT SOUP\nServes 2\nIngredients\n200 g carrots\n500 ml milk\nSteps\n1. Chop the carrots.\n2. Simmer with milk for 20 minutes."
            (text as NSString).draw(in: CGRect(x: 80, y: 80, width: 1040, height: 840), withAttributes: [
                .font: UIFont.systemFont(ofSize: 44), .foregroundColor: UIColor.black
            ])
        }
        let data = try #require(image.pngData())
        let prepared = try RecipieImportImage.prepare(data)
        let text = try await VisionRecipieTextRecognizer().text(from: prepared)
        #expect(text.localizedCaseInsensitiveContains("carrot soup"))
        #expect(text.contains("500"))
        #expect(text.localizedCaseInsensitiveContains("milk"))
    }

    @Test(.enabled(if: SystemLanguageModel.default.availability == .available,
                   "Requires Apple Intelligence on the simulator host"))
    func foundationModelsExtractsRecipeText() async throws {
        let result = try await FoundationRecipieExtractor().extract(from: """
            Carrot soup
            Serves 2
            Cooking time: 20 minutes
            Ingredients:
            200 g carrots
            500 ml milk
            Method:
            1. Chop the carrots.
            2. Simmer the carrots in the milk for 20 minutes.
            """
        )
        #expect(result.isRecipe)
        #expect(result.serves == 2)
        #expect(result.ingredients.count == 2)
        #expect(result.ingredients.first(where: { $0.name.localizedCaseInsensitiveContains("carrot") })?.quantity == 200)
        #expect(result.ingredients.first(where: { $0.name.localizedCaseInsensitiveContains("milk") })?.unit == "ml")
        #expect(!result.steps.isEmpty)
    }

    @Test(.enabled(if: SystemLanguageModel.default.availability == .available,
                   "Requires Apple Intelligence on the simulator host"))
    func foundationModelsPreservesNamesInNameFirstIngredientQuotes() async throws {
        let lines = [
            "Onion – 1 large, chopped",
            "Garlic cloves – 2, crushed",
            "Carrots – 2 medium, sliced",
            "Tinned chopped tomatoes – 400 g",
            "Tomato purée – 2 tablespoons",
            "Cannellini or butter beans, drained – 1 × 400 g tin",
            "Chicken stock – 300 ml",
            "Dried thyme or mixed herbs – 1 teaspoon",
            "Bay leaf – 1",
            "Salt – to taste"
        ]
        let result = try await FoundationRecipieExtractor().extractIngredients(
            from: "Chicken and bean stew\nIngredients\n" + lines.joined(separator: "\n")
        )
        #expect(result.ingredients.count == lines.count)
        #expect(Set(result.ingredients.map { RecipieImportMapper.key($0.sourceText) })
                == Set(lines.map { RecipieImportMapper.key($0) }))
    }

    @Test(.enabled(if: SystemLanguageModel.default.availability == .available,
                   "Requires Apple Intelligence on the simulator host"))
    func foundationModelsGroupsWrappedInstructionsIntoSteps() async throws {
        let result = try await FoundationRecipieExtractor().extract(from: """
            Carrot soup
            Ingredients:
            200 g carrots
            500 ml milk
            Method:
            1. Chop the carrots
            into small pieces so they
            cook evenly.
            2. Simmer the carrots in the milk
            for 20 minutes, stirring
            occasionally.
            """
        )
        #expect(result.steps.count == 2)
        if result.steps.count == 2 {
            #expect(result.steps[0].localizedCaseInsensitiveContains("small pieces"))
            #expect(result.steps[0].localizedCaseInsensitiveContains("evenly"))
            #expect(result.steps[1].contains("20 minutes"))
            #expect(result.steps[1].localizedCaseInsensitiveContains("occasionally"))
        }
    }

    @Test(.enabled(if: SystemLanguageModel.default.availability == .available,
                   "Requires Apple Intelligence on the simulator host"))
    func foundationModelsImportsIngredientsWithoutInventingStepsOrServings() async throws {
        let result = try await FoundationRecipieExtractor().extract(from: """
            Ingredients
            1. 750 g beef mince
            2. 2 onions, chopped
            3. 400 g chopped tomatoes
            4. 500 ml beef stock
            5. 50 g cheddar, grated
            """)
        #expect(result.isRecipe)
        #expect(result.ingredients.count == 5)
        #expect(result.ingredients.first(where: { $0.name.localizedCaseInsensitiveContains("beef mince") })?.quantity == 750)
        #expect(result.steps.isEmpty)
        #expect(result.serves == nil)
        #expect(result.cookingMinutes == nil)
        #expect((result.name?.count ?? 0) <= 60)
    }

    @Test(.enabled(if: SystemLanguageModel.default.availability == .available,
                   "Requires Apple Intelligence on the simulator host"))
    func foundationModelsKeepsNamesShortAndDistinguishesServingsFromYield() async throws {
        let extractor = FoundationRecipieExtractor()
        let title = "Bolognese — The Ultimate Rich and Delicious Family Favourite for Cosy Evenings and Special Gatherings"
        for (servingLine, expected) in [("Serves 4", 4 as Int?), ("Makes 750 g", nil), ("Serves 750", nil)] {
            let metadata = try await extractor.extractMetadata(from: """
                \(title)
                \(servingLine)
                Ingredients:
                750 g beef mince
                2 onions
                400 g tomatoes
                """)
            #expect(metadata.isRecipe)
            #expect(metadata.serves == expected, "Unexpected servings for: \(servingLine)")
            let name = try #require(metadata.name)
            #expect(name.count <= 60)
            #expect(name.split(whereSeparator: \.isWhitespace).count <= 6)
            #expect(name.localizedCaseInsensitiveContains("bolognese"))
        }
    }

    @Test(.enabled(if: SystemLanguageModel.default.availability == .available,
                   "Requires Apple Intelligence on the simulator host"))
    func foundationModelsMatchesCheddarFromRankedCandidates() async throws {
        let names = ["cheddar cheese", "feta cheese", "cream cheese", "cheese sauce", "butter", "milk", "chard",
                     "carrots", "onions", "garlic", "potatoes", "tomatoes", "rice", "pasta", "flour", "eggs",
                     "salt", "pepper", "olive oil", "chicken", "beef", "pork", "salmon", "tuna", "apples",
                     "pears", "bananas", "oranges", "lemons", "limes", "spinach", "broccoli", "cauliflower",
                     "cabbage", "lettuce", "cucumber", "celery", "peas", "sweetcorn", "beans", "lentils",
                     "chickpeas", "yoghurt", "cream", "sugar", "honey", "oats", "bread", "mustard", "vinegar"]
        let catalogue = names.map { RecipieIngredientCatalogEntry(itemID: UUID(), name: $0) }
        let candidates = RecipieIngredientMatching.candidates(for: "cheddar", in: catalogue)
        #expect(candidates.count == 50)
        let result = try await FoundationRecipieIngredientSelector().select(
            for: ExtractedRecipieIngredient(sourceText: "50 grams of cheddar", name: "cheddar", quantity: 50, unit: "grams"),
            recipeName: "Cheese sauce",
            from: candidates
        )
        #expect(result == catalogue[0].itemID)
    }

    @Test(.enabled(if: SystemLanguageModel.default.availability == .available,
                   "Requires Apple Intelligence on the simulator host"))
    func foundationModelsDoesNotSubstitutePreparedIngredient() async throws {
        let catalogue = [RecipieIngredientCatalogEntry(itemID: UUID(), name: "apple sauce")]
        let result = try await FoundationRecipieIngredientSelector().select(
            for: ExtractedRecipieIngredient(sourceText: "2 apples", name: "apples", quantity: 2, unit: "count"),
            recipeName: "Apple pie",
            from: RecipieIngredientMatching.candidates(for: "apples", in: catalogue)
        )
        #expect(result == nil)
    }

    @Test(.enabled(if: SystemLanguageModel.default.availability == .available,
                   "Requires Apple Intelligence on the simulator host"))
    func foundationModelsUsesRecipeTitleWithoutOverridingExplicitIngredients() async throws {
        let mince = RecipieIngredientCatalogEntry(itemID: UUID(), name: "beef mince")
        let steak = RecipieIngredientCatalogEntry(itemID: UUID(), name: "beef steak")
        let candidates = RecipieIngredientMatching.candidates(for: "beef", in: [steak, mince])
        let selector = FoundationRecipieIngredientSelector()
        let shorthand = ExtractedRecipieIngredient(sourceText: "200 g beef", name: "beef", quantity: 200, unit: "g")
        let contextual = try await selector.select(for: shorthand, recipeName: "Spaghetti bolognese", from: candidates)
        #expect(contextual == mince.itemID)

        let explicit = ExtractedRecipieIngredient(sourceText: "200 g beef steak, diced", name: "beef", quantity: 200, unit: "g")
        let originalLineWins = try await selector.select(for: explicit, recipeName: "Spaghetti bolognese", from: candidates)
        // Abstaining is safe; the recipe title must never turn explicit steak into mince.
        #expect(originalLineWins == nil || originalLineWins == steak.itemID)

        let ambiguous = try await selector.select(for: shorthand, recipeName: nil, from: candidates)
        #expect(ambiguous == nil)
    }
}
