import XCTest

final class RecipieExperimentUITests: XCTestCase {
    @MainActor
    func testComparisonRunsOutsideCanvas() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-recipe-experiment"]
        app.launch()

        let run = app.buttons["runRecipeComparison"]
        XCTAssertTrue(run.waitForExistence(timeout: 10))
        XCTAssertTrue(run.isEnabled, "The bundled OCR fixture must load before running.")
        guard app.staticTexts["Model: available"].exists else {
            throw XCTSkip("This simulator needs an available Apple Intelligence model.")
        }
        run.tap()
        XCTAssertTrue(app.staticTexts["Finished"].waitForExistence(timeout: 120))
        let report = app.staticTexts["recipeComparisonReport"].label
        for variant in ["Combined", "Ingredients", "Steps"] {
            XCTAssertTrue(report.contains("\(variant) —"))
        }
        XCTAssertFalse(report.contains("Failed:"), report)
        let ingredientSection = try XCTUnwrap(report.components(separatedBy: "\n\nIngredients —").last)
            .components(separatedBy: "\n\nSteps —")[0]
        let jsonStart = try XCTUnwrap(ingredientSection.firstIndex(of: "{"))
        let object = try JSONSerialization.jsonObject(with: Data(ingredientSection[jsonStart...].utf8))
        let ingredients = try XCTUnwrap((object as? [String: Any])?["ingredients"] as? [[String: Any]])
        for (sourcePrefix, amount, unit) in [("80g", 80.0, "g"), ("15ml soy sauce", 15.0, "ml"), ("1 ginger paste sachet", 15.0, "g")] {
            let ingredient = try XCTUnwrap(ingredients.first { ($0["sourceText"] as? String)?.hasPrefix(sourcePrefix) == true })
            XCTAssertEqual((ingredient["quantity"] as? NSNumber)?.doubleValue, amount)
            XCTAssertEqual(ingredient["unit"] as? String, unit)
        }
        XCTAssertTrue(run.isEnabled, "A completed run must allow another comparison.")
    }
}
