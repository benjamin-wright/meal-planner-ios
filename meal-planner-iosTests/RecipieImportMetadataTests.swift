import Foundation
import Testing
@testable import meal_planner_ios

struct RecipieImportMetadataTests {
    @Test func quotedMetadataSurvivesOCRWhitespaceAndCaseDifferences() {
        let source = """
            Tomato soup
            SERVES
            4
            Cooking time:
              20 minutes
            Ingredients
            500 grams tomatoes
            """
        let metadata = ExtractedRecipieMetadata(
            isRecipe: true,
            name: "Homemade tomato soup with roasted garlic and fresh basil leaves",
            summary: "Tomato soup with garlic and basil.",
            servingsSourceText: "Serves 4", serves: 4,
            cookingTimeSourceText: "Cooking time: 20 minutes", cookingMinutes: 20
        )

        let result = RecipieImportMetadataRules.validated(metadata, source: source)

        #expect(result.serves == 4)
        #expect(result.cookingMinutes == 20)
        #expect(result.name == "Homemade tomato soup with roasted garlic and fresh basil")
        #expect(result.summary == metadata.summary)
    }

    @Test func missingSourceQuotesRejectGuessedServingsAndCookingTime() {
        let metadata = ExtractedRecipieMetadata(
            isRecipe: true, name: "Beef sauce", summary: nil,
            servingsSourceText: nil, serves: 4,
            cookingTimeSourceText: nil, cookingMinutes: 0
        )

        let result = RecipieImportMetadataRules.validated(
            metadata, source: "Ingredients\n750 grams beef\n2 onions"
        )

        #expect(result.serves == nil)
        #expect(result.cookingMinutes == nil)
    }

    @Test func sourceQuotesMustActuallyAppearInTheRecipe() {
        let metadata = ExtractedRecipieMetadata(
            isRecipe: true, name: "Beef sauce", summary: nil,
            servingsSourceText: "Serves 4", serves: 4,
            cookingTimeSourceText: "Cooking time: 20 minutes", cookingMinutes: 20
        )

        let result = RecipieImportMetadataRules.validated(
            metadata, source: "Ingredients\n750 grams beef\n2 onions"
        )

        #expect(result.serves == nil)
        #expect(result.cookingMinutes == nil)
    }

    @Test func bareNumberQuotesDoNotGroundMetadata() {
        let metadata = ExtractedRecipieMetadata(
            isRecipe: true, name: "Tomato sauce", summary: nil,
            servingsSourceText: "4", serves: 4,
            cookingTimeSourceText: "20", cookingMinutes: 20
        )

        let result = RecipieImportMetadataRules.validated(
            metadata, source: "Ingredients\n4 onions\n20 tomatoes"
        )

        #expect(result.serves == nil)
        #expect(result.cookingMinutes == nil)
    }

    @Test func quotedServingsStillMustBeWithinTheImportRange() {
        for servings in [0, -1, 25, 750] {
            let quote = "Serves \(servings)"
            let metadata = ExtractedRecipieMetadata(
                isRecipe: true, name: "Tomato soup", summary: nil,
                servingsSourceText: quote, serves: servings,
                cookingTimeSourceText: nil, cookingMinutes: nil
            )

            let result = RecipieImportMetadataRules.validated(metadata, source: "Tomato soup\n\(quote)")

            #expect(result.serves == nil)
        }
    }

    @Test func sourceQuoteMatchingNormalizesDiacriticsAndRequiresLetters() {
        let source = "DURÉE DE CUISSON :\n 20 minutes"

        #expect(RecipieImportMetadataRules.isSourceQuote("duree de cuisson : 20 minutes", in: source))
        #expect(!RecipieImportMetadataRules.isSourceQuote("20", in: source))
        #expect(!RecipieImportMetadataRules.isSourceQuote(" \n ", in: source))
        #expect(!RecipieImportMetadataRules.isSourceQuote(nil, in: source))
    }

    @Test func sourceQuotesCannotMatchPartOfAWordOrNumber() {
        #expect(!RecipieImportMetadataRules.isSourceQuote("Serves 7", in: "Serves 750"))
        #expect(!RecipieImportMetadataRules.isSourceQuote("Cook", in: "Cooked"))
    }

    @Test func partialAndDisagreeingServingNumbersAreRejected() {
        let cases: [(source: String, quote: String, serves: Int)] = [
            ("Serves 750", "Serves 7", 7),
            ("Serves 750", "Serves 750", 4),
            ("Serves 4–6", "Serves 4–6", 4)
        ]

        for testCase in cases {
            let metadata = ExtractedRecipieMetadata(
                isRecipe: true, name: "Tomato soup", summary: nil,
                servingsSourceText: testCase.quote, serves: testCase.serves,
                cookingTimeSourceText: nil, cookingMinutes: nil
            )

            let result = RecipieImportMetadataRules.validated(metadata, source: testCase.source)

            #expect(result.serves == nil)
        }
    }

    @Test func quotedServingCountsWrittenAsWordsRetainTheModelsInterpretation() {
        let metadata = ExtractedRecipieMetadata(
            isRecipe: true, name: "Tomato soup", summary: nil,
            servingsSourceText: "Serves four", serves: 4,
            cookingTimeSourceText: nil, cookingMinutes: nil
        )

        let result = RecipieImportMetadataRules.validated(metadata, source: "Serves four")

        #expect(result.serves == 4)
    }

    @MainActor
    @Test func longImportedTitlesEndAtACompleteWordWithinTheLimit() {
        let title = "  Homemade tomato soup with roasted garlic and fresh basil leaves  "
        let expected = "Homemade tomato soup with roasted garlic and fresh basil"
        var draft = existingDraft()

        RecipieImportMapper.apply(recipe(name: title), to: &draft, items: [], units: [])

        #expect(draft.name == expected)
        #expect(draft.name.count <= 60)
        #expect(RecipieImportMetadataRules.name(title) == expected)
    }

    @MainActor
    @Test func importedTitlesNormalizeWhitespaceAndPreserveUnicodeAndShortWords() {
        let titles = [
            (" \nCrème  brûlée\t à l’orange 🍊 \n", "Crème brûlée à l’orange 🍊"),
            ("A pot of rice with a bit of oil and a lot of herbs", "A pot of rice with a bit of oil and a lot of herbs")
        ]

        for (source, expected) in titles {
            var draft = existingDraft()
            RecipieImportMapper.apply(recipe(name: source), to: &draft, items: [], units: [])
            #expect(draft.name == expected)
            #expect(RecipieImportMetadataRules.name(source) == expected)
        }
    }

    @MainActor
    @Test func validImportedServingBoundariesReplaceTheCurrentValue() {
        for servings in [1, 24] {
            var draft = existingDraft()
            let extracted = recipe(serves: servings)

            RecipieImportMapper.apply(extracted, to: &draft, items: [], units: [])

            #expect(draft.serves == servings)
            #expect(RecipieImportMetadataRules.servings(servings) == servings)
            #expect(!RecipieImportMapper.reviewMessage(for: extracted)
                .localizedCaseInsensitiveContains(String(localized: "servings")))
        }
    }

    @MainActor
    @Test func missingOrInvalidImportedServingsKeepTheCurrentValueAndRequestReview() {
        let invalidValues: [Int?] = [0, -1, 25, 750, nil]

        for servings in invalidValues {
            var draft = existingDraft()
            let extracted = recipe(serves: servings)

            RecipieImportMapper.apply(extracted, to: &draft, items: [], units: [])

            #expect(draft.serves == 5)
            #expect(RecipieImportMetadataRules.servings(servings) == nil)
            #expect(RecipieImportMapper.reviewMessage(for: extracted)
                .localizedCaseInsensitiveContains(String(localized: "servings")))
        }
    }

    @Test func manuallyEnteredLargeServingCountsRemainValid() {
        var draft = existingDraft()
        draft.serves = 750

        #expect(draft.validate().isEmpty)
    }

    @MainActor
    @Test func missingOrBlankImportedTitlesKeepTheCurrentTitle() {
        let emptyTitles: [String?] = [nil, "", " \n\t "]

        for title in emptyTitles {
            var draft = existingDraft()

            RecipieImportMapper.apply(recipe(name: title), to: &draft, items: [], units: [])

            #expect(draft.name == "Existing recipe")
            #expect(RecipieImportMetadataRules.name(title) == nil)
        }
    }

    @MainActor
    @Test func ingredientOnlyImportsKeepExistingInstructionsAndMetadata() throws {
        let ingredient = ExtractedRecipieIngredient(
            sourceText: "50 grams of cheddar", name: "cheddar", quantity: 50, unit: "grams"
        )
        let extracted = ExtractedRecipie(
            isRecipe: true, name: nil, summary: nil, serves: nil, cookingMinutes: nil,
            ingredients: [ingredient], steps: []
        )
        var draft = existingDraft()

        RecipieImportMapper.apply(extracted, to: &draft, items: [], units: [])

        #expect(draft.name == "Existing recipe")
        #expect(draft.summary == "Existing description")
        #expect(draft.serves == 5)
        #expect(draft.time == 40)
        #expect(draft.steps == ["Keep these instructions."])
        let ingredients = try #require(draft.importedIngredients)
        #expect(ingredients.count == 1)
        #expect(ingredients.first?.sourceText == ingredient.sourceText)
        #expect(ingredients.first?.quantityText == "50")
    }

    private func existingDraft() -> RecipieDraft {
        var draft = RecipieDraft()
        draft.name = "Existing recipe"
        draft.summary = "Existing description"
        draft.serves = 5
        draft.time = 40
        draft.steps = ["Keep these instructions."]
        return draft
    }

    private func recipe(name: String? = "Imported recipe", serves: Int? = 2) -> ExtractedRecipie {
        ExtractedRecipie(
            isRecipe: true, name: name, summary: nil, serves: serves, cookingMinutes: 10,
            ingredients: [ExtractedRecipieIngredient(
                sourceText: "50 grams of cheddar", name: "cheddar", quantity: 50, unit: "grams"
            )],
            steps: ["Mix the ingredients."]
        )
    }
}
