import XCTest

final class CatalogPickerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func row(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    @MainActor
    private func assertShoppingEntry(_ name: String, in app: XCUIApplication) {
        let entry = row(name, in: app)
        for _ in 0..<6 {
            if entry.exists { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(entry.waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    private func createCategory(_ name: String, in app: XCUIApplication) {
        app.navigationBars["Category"].buttons["Add"].tap()
        let field = app.textFields["category"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(name + "\n")
        app.collectionViews.buttons["Add"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name)
        let category = row(name, in: app)
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        category.tap()
    }

    @MainActor
    func testShoppingListCanCreateAnItemAndItsCategoryFromPickers() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["List"].tap()
        app.navigationBars["Shopping List"].buttons["Add"].tap()
        row("Item", in: app).tap()
        app.navigationBars["Item"].buttons["Add"].tap()

        let suffix = UUID().uuidString.lowercased()
        let itemName = "picker item \(suffix)"
        let categoryName = "picker category \(suffix)"
        let field = app.textFields["item name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(itemName + "\n")
        row("Category", in: app).tap()
        createCategory(categoryName, in: app)

        XCTAssertEqual(field.value as? String, itemName)
        app.collectionViews.buttons["Add"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), app.debugDescription)
        search.tap()
        search.typeText(itemName)
        let item = row(itemName, in: app)
        XCTAssertTrue(item.waitForExistence(timeout: 5), app.debugDescription)
        item.tap()
        XCTAssertTrue(app.navigationBars["Add to List"].waitForExistence(timeout: 5))
        app.navigationBars["Add to List"].buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["Add to List"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Shopping List"].waitForExistence(timeout: 5))
        assertShoppingEntry(itemName, in: app)
    }

    @MainActor
    func testShoppingListNoteSurvivesCategoryCreationAndUnitSelection() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["List"].tap()
        app.navigationBars["Shopping List"].buttons["Add"].tap()
        app.segmentedControls.buttons["Quick Note"].tap()
        let noteName = "picker note \(UUID().uuidString.lowercased())"
        let field = app.textFields["e.g. birthday candles"]
        field.tap()
        field.typeText(noteName + "\n")
        row("Category", in: app).tap()
        createCategory("note category \(UUID().uuidString.lowercased())", in: app)
        XCTAssertEqual(field.value as? String, noteName)

        row("Unit", in: app).tap()
        XCTAssertTrue(app.navigationBars["Unit"].waitForExistence(timeout: 5), app.debugDescription)
        app.segmentedControls.buttons["Count"].tap()
        app.navigationBars["Unit"].buttons["Add"].tap()
        XCTAssertTrue(app.textFields["unit name"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["base"].exists)
        app.navigationBars["Unit"].buttons.element(boundBy: 0).tap()
        row("count", in: app).tap()

        XCTAssertEqual(field.value as? String, noteName)
        app.navigationBars["Add to List"].buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["Add to List"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Shopping List"].waitForExistence(timeout: 5))
        assertShoppingEntry(noteName, in: app)
    }

    @MainActor
    func testSettingsUseTypeRestrictedUnitPickers() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        row("Weight", in: app).tap()
        XCTAssertTrue(row("grams", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(row("litres", in: app).exists)
        XCTAssertFalse(row("count", in: app).exists)
        XCTAssertFalse(app.segmentedControls.buttons["All"].exists)
        row("grams", in: app).tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        row("Volume", in: app).tap()
        XCTAssertTrue(row("litres", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(row("grams", in: app).exists)
        XCTAssertFalse(row("count", in: app).exists)
        app.navigationBars["Unit"].buttons["Add"].tap()
        XCTAssertTrue(app.textFields["unit name"].waitForExistence(timeout: 5))
        XCTAssertTrue(row("Type", in: app).label.contains("Volume"))
        XCTAssertFalse(app.segmentedControls.firstMatch.exists)
        app.navigationBars["Unit"].buttons.element(boundBy: 0).tap()
        row("litres", in: app).tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRecipeEnumPickersRemainSegmentedAndSelectable() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Data"].tap()
        app.buttons["Recipies"].tap()

        let lunch = app.segmentedControls.buttons["Lunch"]
        XCTAssertTrue(lunch.waitForExistence(timeout: 5))
        lunch.tap()
        XCTAssertTrue(lunch.isSelected)
        app.segmentedControls.buttons["Dinner"].tap()

        app.collectionViews.buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["Recipe"].waitForExistence(timeout: 5))
        let breakfast = app.segmentedControls.buttons["Breakfast"]
        XCTAssertTrue(breakfast.waitForExistence(timeout: 5))
        breakfast.tap()
        XCTAssertTrue(breakfast.isSelected)
    }

    @MainActor
    func testRecipeStepsCanBeReorderedAndSaved() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Data"].tap()
        app.buttons["Recipies"].tap()
        app.collectionViews.buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["Recipe"].waitForExistence(timeout: 5))

        let recipeName = "reordered steps \(UUID().uuidString.lowercased())"
        let name = app.textFields["recipe name"]
        name.tap()
        name.typeText(recipeName + "\n")

        let addStep = app.buttons["addRecipeStep"]
        for _ in 0..<6 {
            if addStep.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(addStep.isHittable, app.debugDescription)
        addStep.tap()
        addStep.tap()

        let firstStep = app.descendants(matching: .any)["recipeStep0"]
        let secondStep = app.descendants(matching: .any)["recipeStep1"]
        XCTAssertTrue(firstStep.waitForExistence(timeout: 5))
        firstStep.tap()
        firstStep.typeText("Chop onions.")
        secondStep.tap()
        secondStep.typeText("Add oil.")
        let reorderButtons = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Reorder"))
        XCTAssertEqual(reorderButtons.count, 0)
        app.navigationBars["Recipe"].buttons["Edit"].tap()
        for _ in 0..<6 {
            if secondStep.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }

        XCTAssertEqual(reorderButtons.count, 2, app.debugDescription)
        XCTAssertFalse(app.buttons["saveRecipe"].isEnabled)
        reorderButtons.element(boundBy: 1).press(
            forDuration: 1,
            thenDragTo: reorderButtons.element(boundBy: 0)
        )
        XCTAssertEqual(firstStep.value as? String, "Add oil.")
        XCTAssertEqual(secondStep.value as? String, "Chop onions.")
        app.navigationBars["Recipe"].buttons["Done"].tap()
        app.buttons["saveRecipe"].tap()
        XCTAssertTrue(app.navigationBars["Recipies"].waitForExistence(timeout: 5))

        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText(recipeName)
        let recipe = row(recipeName, in: app)
        XCTAssertTrue(recipe.waitForExistence(timeout: 5))
        recipe.tap()
        XCTAssertTrue(app.navigationBars["Recipe"].waitForExistence(timeout: 5))
        for _ in 0..<6 {
            if firstStep.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertEqual(firstStep.value as? String, "Add oil.")
        XCTAssertEqual(secondStep.value as? String, "Chop onions.")
    }

    @MainActor
    func testRecipeStepsAllowMultilineReview() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Data"].tap()
        app.buttons["Recipies"].tap()
        app.collectionViews.buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["Recipe"].waitForExistence(timeout: 5))

        let addStep = app.buttons["addRecipeStep"]
        for _ in 0..<6 {
            if addStep.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(addStep.isHittable, app.debugDescription)
        addStep.tap()

        let step = app.descendants(matching: .any)["recipeStep0"]
        XCTAssertTrue(step.waitForExistence(timeout: 5))
        step.tap()
        step.typeText("Chop onions.\nAdd oil.")
        XCTAssertTrue((step.value as? String)?.contains("\n") == true)
        XCTAssertGreaterThan(step.frame.height, 44)
    }
}
