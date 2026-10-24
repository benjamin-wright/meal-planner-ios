import XCTest

final class CatalogPickerUITests: MealPlannerUITestCase {
    @MainActor
    func testCatalogueCreationAndSelectionAcrossShoppingSettingsAndRecipes() {
        let app = XCUIApplication()
        launchInPortrait(app)

        XCTContext.runActivity(named: "Create a shopping item and its category") { _ in
            createShoppingItemAndCategory(in: app)
        }
        XCTContext.runActivity(named: "Create a shopping note, category and count unit") { _ in
            createShoppingNoteCategoryAndUnit(in: app)
        }
        XCTContext.runActivity(named: "Select new weight and volume units in Settings") { _ in
            selectRestrictedUnitsInSettings(in: app)
        }
        XCTContext.runActivity(named: "Author, reorder and reopen multiline recipe steps") { _ in
            authorRecipeSteps(in: app)
        }
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
            let addMagnitude = app.buttons["addUnitMagnitude"]
            scrollTo(addMagnitude, in: app)
            addMagnitude.tap()
            for (placeholder, value) in [
                ("abbreviation", "pu"),
                ("singular", "picker unit"),
                ("plural", "picker units"),
            ] {
                let magnitude = app.textFields[placeholder]
                XCTAssertTrue(magnitude.waitForExistence(timeout: 5))
                scrollTo(magnitude, in: app)
                magnitude.tap()
                magnitude.typeText(value + "\n")
            }
        }

        let add = app.buttons["saveUnit"]
        scrollTo(add, in: app)
        XCTAssertTrue(add.isEnabled, app.debugDescription)
        add.tap()
        XCTAssertTrue(app.navigationBars["Unit"].waitForNonExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    private func createShoppingItemAndCategory(in app: XCUIApplication) {
        app.tabBars.buttons["List"].tap()
        app.navigationBars["Shopping List"].buttons["Add"].tap()
        row("Item", in: app).tap()
        app.navigationBars["Item"].buttons["Add"].tap()

        let itemName = "Mixed Case Item"
        let categoryName = "Mixed Case Category"
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
    private func createShoppingNoteCategoryAndUnit(in app: XCUIApplication) {
        app.navigationBars["Shopping List"].buttons["Add"].tap()
        app.segmentedControls.buttons["Quick Note"].tap()
        let noteName = "picker note"
        let categoryName = "note category"
        let unitName = "note count"
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
    private func selectRestrictedUnitsInSettings(in app: XCUIApplication) {
        app.tabBars.buttons["Settings"].tap()
        for (type, included, excluded) in [
            ("Weight", "grams", "litres"),
            ("Volume", "litres", "grams"),
        ] {
            row(type, in: app).tap()
            XCTAssertTrue(row(included, in: app).waitForExistence(timeout: 5), type)
            XCTAssertFalse(row(excluded, in: app).exists, type)
            XCTAssertFalse(row("count", in: app).exists, type)
            XCTAssertFalse(app.segmentedControls.buttons["All"].exists, type)
            let name = "picker \(type.lowercased())"
            createUnit(name, type: type, in: app)
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5), type)
            assertSelection(type, is: name, in: app)
        }
    }

    @MainActor
    private func authorRecipeSteps(in app: XCUIApplication) {
        openRecipeCatalogue(in: app)
        XCTAssertFalse(app.segmentedControls.firstMatch.exists)
        XCTAssertTrue(app.buttons["recipeFilters"].exists)
        openNewRecipe(in: app)
        XCTAssertFalse(app.segmentedControls.buttons["Breakfast"].exists)
        XCTAssertFalse(app.segmentedControls.buttons["Main"].exists)

        let recipeName = "reordered steps"
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
        let multilineStep = "Chop onions.\nKeep the pieces small."
        firstStep.typeText(multilineStep)
        XCTAssertEqual(firstStep.value as? String, multilineStep)
        XCTAssertGreaterThan(firstStep.frame.height, 44)
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
        scrollTo(firstStep, in: app)
        XCTAssertEqual(firstStep.value as? String, "Add oil.")
        scrollTo(secondStep, in: app)
        XCTAssertEqual(secondStep.value as? String, multilineStep)
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
        scrollTo(firstStep, in: app)
        XCTAssertEqual(firstStep.value as? String, "Add oil.")
        scrollTo(secondStep, in: app)
        XCTAssertEqual(secondStep.value as? String, multilineStep)
    }

}
