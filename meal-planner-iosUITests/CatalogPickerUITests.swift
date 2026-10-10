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
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        if !element.isHittable {
            for _ in 0..<6 {
                if element.isHittable { break }
                app.collectionViews.firstMatch.swipeDown()
            }
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
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
        XCTAssertTrue(app.navigationBars["Category"].waitForNonExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    private func assertSelection(_ label: String, is name: String, in app: XCUIApplication) {
        let selected = row(label, in: app).staticTexts[name]
        XCTAssertTrue(selected.waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    private func createUnit(_ name: String, type: String, in app: XCUIApplication) {
        app.navigationBars["Unit"].buttons["Add"].tap()
        let field = app.textFields["unit name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(row("Type", in: app).label.contains(type))
        field.tap()
        field.typeText(name + "\n")

        if type == "Count" {
            XCTAssertFalse(app.textFields["base"].exists)
        } else {
            app.buttons["addUnitMagnitude"].tap()
            for (placeholder, value) in [
                ("abbreviation", "pu"),
                ("singular", "picker unit"),
                ("plural", "picker units"),
            ] {
                let magnitude = app.textFields[placeholder]
                XCTAssertTrue(magnitude.waitForExistence(timeout: 5))
                magnitude.tap()
                magnitude.typeText(value + "\n")
            }
        }

        let add = app.buttons["saveUnit"]
        for _ in 0..<6 {
            if add.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(add.isEnabled, app.debugDescription)
        add.tap()
        XCTAssertTrue(app.navigationBars["Unit"].waitForNonExistence(timeout: 5), app.debugDescription)
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
        assertSelection("Category", is: categoryName, in: app)
        app.collectionViews.buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["Add to List"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.navigationBars["Item"].exists)
        assertSelection("Item", is: itemName, in: app)
        app.navigationBars["Add to List"].buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["Add to List"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Shopping List"].waitForExistence(timeout: 5))
        assertShoppingEntry(itemName, in: app)
    }

    @MainActor
    func testShoppingListNoteAutomaticallySelectsCreatedCategoryAndCountUnit() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["List"].tap()
        app.navigationBars["Shopping List"].buttons["Add"].tap()
        app.segmentedControls.buttons["Quick Note"].tap()
        let noteName = "picker note \(UUID().uuidString.lowercased())"
        let categoryName = "note category \(UUID().uuidString.lowercased())"
        let unitName = "note count \(UUID().uuidString.lowercased())"
        let field = app.textFields["e.g. birthday candles"]
        field.tap()
        field.typeText(noteName + "\n")
        row("Category", in: app).tap()
        createCategory(categoryName, in: app)
        XCTAssertTrue(app.navigationBars["Add to List"].waitForExistence(timeout: 5), app.debugDescription)
        assertSelection("Category", is: categoryName, in: app)
        XCTAssertEqual(field.value as? String, noteName)

        row("Unit", in: app).tap()
        XCTAssertTrue(app.navigationBars["Unit"].waitForExistence(timeout: 5), app.debugDescription)
        app.segmentedControls.buttons["Count"].tap()
        createUnit(unitName, type: "Count", in: app)

        XCTAssertTrue(app.navigationBars["Add to List"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(field.value as? String, noteName)
        assertSelection("Unit", is: unitName, in: app)
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
        let weightName = "picker weight \(UUID().uuidString.lowercased())"
        createUnit(weightName, type: "Weight", in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        assertSelection("Weight", is: weightName, in: app)

        row("Volume", in: app).tap()
        XCTAssertTrue(row("litres", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(row("grams", in: app).exists)
        XCTAssertFalse(row("count", in: app).exists)
        XCTAssertFalse(app.segmentedControls.buttons["All"].exists)
        let volumeName = "picker volume \(UUID().uuidString.lowercased())"
        createUnit(volumeName, type: "Volume", in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        assertSelection("Volume", is: volumeName, in: app)
    }

    @MainActor
    func testRecipeCatalogueAndEditorDoNotHideBehindMealOrCourseFilters() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Data"].tap()
        app.buttons["Recipies"].tap()
        XCTAssertTrue(app.navigationBars["Recipies"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls.firstMatch.exists)
        XCTAssertTrue(app.buttons["recipeFilters"].exists)

        app.collectionViews.buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["Recipe"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls.buttons["Breakfast"].exists)
        XCTAssertFalse(app.segmentedControls.buttons["Main"].exists)
        XCTAssertTrue(app.textFields["recipe name"].exists)
    }

    @MainActor
    func testRecipeStepsCanBeReorderedAndSaved() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Data"].tap()
        app.buttons["Recipies"].tap()
        XCTAssertTrue(app.navigationBars["Recipies"].waitForExistence(timeout: 5))
        let addRecipe = app.collectionViews.buttons["Add"]
        scrollTo(addRecipe, in: app)
        addRecipe.tap()
        XCTAssertTrue(app.navigationBars["Recipe"].waitForExistence(timeout: 5))

        let recipeName = "reordered steps \(UUID().uuidString.lowercased())"
        let name = app.textFields["recipe name"]
        name.tap()
        name.typeText(recipeName + "\n")

        let addStep = app.buttons["addRecipeStep"]
        // Each inserted multiline row can push the Add button out of the visible form.
        for _ in 0..<2 {
            scrollTo(addStep, in: app)
            addStep.tap()
        }

        let firstStep = app.descendants(matching: .any)["recipeStep0"]
        let secondStep = app.descendants(matching: .any)["recipeStep1"]
        scrollTo(firstStep, in: app)
        XCTAssertTrue(firstStep.waitForExistence(timeout: 5))
        firstStep.tap()
        firstStep.typeText("Chop onions.")
        app.buttons["hideKeyboard"].tap()
        scrollTo(secondStep, in: app)
        secondStep.tap()
        secondStep.typeText("Add oil.")
        app.buttons["hideKeyboard"].tap()
        let reorderButtons = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Reorder"))
        XCTAssertEqual(reorderButtons.count, 0)
        app.navigationBars["Recipe"].buttons["Edit"].tap()
        scrollTo(secondStep, in: app)

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
