import Foundation
import Testing
@testable import meal_planner_ios

struct RecipieIngredientSourceTextTests {
    @Test func restoresCompleteNameFirstRowsFromTruncatedAmountQuotes() {
        let rows: [(name: String, quote: String, full: String)] = [
            ("Onion", "1 large, chopped", "Onion – 1 large, chopped"),
            ("Garlic cloves", "2, crushed", "Garlic cloves – 2, crushed"),
            ("Carrots", "2 medium, sliced", "Carrots – 2 medium, sliced"),
            ("Tinned chopped tomatoes", "400 g", "Tinned chopped tomatoes – 400 g"),
            ("Tomato puree", "2 tablespoons", "Tomato purée – 2 tablespoons"),
            ("beans", "1 × 400 g tin", "Cannellini or butter beans, drained – 1 × 400 g tin"),
            ("Chicken stock", "300 ml", "Chicken stock – 300 ml"),
            ("Dried thyme", "1 teaspoon", "Dried thyme or mixed herbs – 1 teaspoon"),
            ("Bay leaf", "1", "Bay leaf – 1"),
            ("Salt", "to taste", "Salt – to taste")
        ]
        let source = "Ingredients\n" + rows.map(\.full).joined(separator: "\n")
        for row in rows {
            let ingredient = ExtractedRecipieIngredient(sourceText: row.quote, name: row.name, quantity: nil, unit: "")
            let result = RecipieIngredientSourceText.restoringLine(for: ingredient, in: source)
            #expect(result.sourceText == row.full)
            #expect(result.name == ingredient.name)
            #expect(result.quantity == nil && result.unit.isEmpty)
        }
    }

    @Test func recognizesNameFirstSeparatorsWithoutChangingQuantities() {
        for separator in [" – ", " — ", " - ", ": "] {
            let row = "Onions" + separator + "2, finely chopped"
            let ingredient = ExtractedRecipieIngredient(sourceText: "2, finely chopped", name: "onions", quantity: 2, unit: "count")
            let result = RecipieIngredientSourceText.restoringLine(for: ingredient, in: "Ingredients\n" + row)
            #expect(result.sourceText == row)
            #expect(result.quantity == 2 && result.unit == "count")
        }
    }

    @Test func preservesQuotesThatAlreadyContainTheIngredientNameVerbatim() {
        for quote in ["2 onions", "2 ONIONS, CHOPPED", "Onions – 2"] {
            let ingredient = ExtractedRecipieIngredient(sourceText: quote, name: "onions", quantity: 2, unit: "count")
            #expect(RecipieIngredientSourceText.restoringLine(for: ingredient, in: "Onions – 2, finely chopped") == ingredient)
        }
    }

    @Test func repeatedAmountsAreDistinguishedByWholeIngredientNames() {
        let source = "Salt – to taste\nPepper – to taste\nGarlic – 2 cloves\nOnion – 2, chopped"
        let salt = ExtractedRecipieIngredient(sourceText: "to taste", name: "salt", quantity: nil, unit: "")
        let onion = ExtractedRecipieIngredient(sourceText: "2", name: "onion", quantity: 2, unit: "count")
        #expect(RecipieIngredientSourceText.restoringLine(for: salt, in: source).sourceText == "Salt – to taste")
        #expect(RecipieIngredientSourceText.restoringLine(for: onion, in: source).sourceText == "Onion – 2, chopped")
        let oil = ExtractedRecipieIngredient(sourceText: "2 tablespoons", name: "oil", quantity: 2, unit: "tablespoons")
        #expect(RecipieIngredientSourceText.restoringLine(for: oil, in: "Bring to boil – 2 tablespoons") == oil)
    }

    @Test func leavesAmbiguousAndUnverifiableQuotesUnchanged() {
        let ingredient = ExtractedRecipieIngredient(sourceText: "2 tablespoons", name: "sugar", quantity: 2, unit: "tablespoons")
        for source in [
            "Sugar – 2 tablespoons, for the cake\nSugar – 2 tablespoons, for the topping",
            "Flour – 2 tablespoons\nSugar – 3 tablespoons",
            "Sugar – 12 tablespoons",
            "Sugarcane syrup – 2 tablespoons",
            "Stir sugar into 2 tablespoons of water.",
            "Sugar-free icing with 2 tablespoons water",
            "Sugar –\n\n2 tablespoons",
            "Sugar – 3 tablespoons\n2 tablespoons"
        ] {
            #expect(RecipieIngredientSourceText.restoringLine(for: ingredient, in: source) == ingredient)
        }
    }

    @Test func joinsOnlyAnExplicitWrappedNamePrefixAndExactAmountLine() {
        let ingredient = ExtractedRecipieIngredient(sourceText: "2 tablespoons", name: "tomato puree", quantity: 2, unit: "tablespoons")
        let result = RecipieIngredientSourceText.restoringLine(
            for: ingredient, in: "Ingredients\nTomato purée –\n2 tablespoons\nChicken stock – 300 ml"
        )
        #expect(result.sourceText == "Tomato purée – 2 tablespoons")
        #expect(result.quantity == 2 && result.unit == "tablespoons")
    }

    @Test func doesNotInventSourceTextWhenNameOrQuoteIsMissing() {
        let source = "Salt – to taste"
        for ingredient in [
            ExtractedRecipieIngredient(sourceText: "", name: "Salt", quantity: nil, unit: ""),
            ExtractedRecipieIngredient(sourceText: "to taste", name: "", quantity: nil, unit: "")
        ] {
            #expect(RecipieIngredientSourceText.restoringLine(for: ingredient, in: source) == ingredient)
        }
    }
}
