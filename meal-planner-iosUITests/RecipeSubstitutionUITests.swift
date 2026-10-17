import XCTest

final class RecipeSubstitutionUITests: MealPlannerUITestCase {
    @MainActor
    private func addSoupToMonday(in app: XCUIApplication) {
        app.tabBars.buttons["Planner"].tap()
        app.buttons["Add dinner for Monday"].tap()
        let addMain = app.buttons["Add Main dish"]
        scrollTo(addMain, in: app)
        addMain.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("carrot soup")
        let soup = row("carrot soup", in: app)
        XCTAssertTrue(soup.waitForExistence(timeout: 5))
        soup.tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openSoup(in app: XCUIApplication) {
        let soup = component("carrot soup", course: "Main", in: app)
        scrollTo(soup, in: app)
        soup.tap()
        XCTAssertTrue(app.navigationBars["Planned Recipe"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openIngredient(_ name: String, in app: XCUIApplication) {
        let ingredient = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
            "plannedRecipeIngredient-", name
        )).firstMatch
        XCTAssertTrue(ingredient.waitForExistence(timeout: 5), app.debugDescription)
        ingredient.tap()
        XCTAssertTrue(app.navigationBars["Ingredient"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func saveRecipe(in app: XCUIApplication) {
        let save = app.buttons["savePlannedRecipe"]
        scrollTo(save, in: app)
        save.tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func savePlan(isNew: Bool, in app: XCUIApplication) {
        let save = app.collectionViews.buttons[isNew ? "Add" : "Save"].firstMatch
        scrollTo(save, in: app)
        save.tap()
        XCTAssertTrue(app.navigationBars["Planner"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSubstitutionAndQuantityPersistWithAsterisksAndCanBeReset() {
        let app = XCUIApplication()
        launchInPortrait(app)
        resetSampleData(in: app)
        defer { resetSampleData(in: app) }
        addSoupToMonday(in: app)
        openSoup(in: app)

        openIngredient("carrots", in: app)
        setPortion("99", in: app)
        app.navigationBars["Ingredient"].buttons.element(boundBy: 0).tap()
        openIngredient("carrots", in: app)
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "1")
        setPortion("8", in: app)
        row("Item", in: app).tap()
        XCTAssertTrue(app.navigationBars["Item"].waitForExistence(timeout: 5))
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("potatoes")
        let potatoes = row("potatoes", in: app)
        XCTAssertTrue(potatoes.waitForExistence(timeout: 5))
        potatoes.tap()
        XCTAssertTrue(app.navigationBars["Ingredient"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "8")
        app.collectionViews.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Planned Recipe"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["carrot soup*"].exists)
        saveRecipe(in: app)
        XCTAssertTrue(component("carrot soup*", course: "Main", in: app).exists)
        savePlan(isNew: true, in: app)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "carrot soup*")).firstMatch.exists)

        app.terminate()
        launchInPortrait(app)
        app.tabBars.buttons["Planner"].tap()
        let plan = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "carrot soup*")).firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        plan.tap()
        openSoup(in: app)
        openIngredient("potatoes", in: app)
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "8")
        app.navigationBars["Ingredient"].buttons.element(boundBy: 0).tap()
        let reset = app.buttons["Reset to Original Recipe"]
        scrollTo(reset, in: app)
        reset.tap()
        XCTAssertFalse(app.staticTexts["carrot soup*"].exists)
        openIngredient("carrots", in: app)
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "1")
        app.navigationBars["Ingredient"].buttons.element(boundBy: 0).tap()
        saveRecipe(in: app)
        savePlan(isNew: false, in: app)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "carrot soup*")).firstMatch.exists)
    }

    @MainActor
    func testBackingOutOfRecipeOrPlanDiscardsStagedSubstitutions() {
        let app = XCUIApplication()
        launchInPortrait(app)
        resetSampleData(in: app)
        defer { resetSampleData(in: app) }
        addSoupToMonday(in: app)
        savePlan(isNew: true, in: app)
        let plan = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "carrot soup")).firstMatch
        plan.tap()
        openSoup(in: app)
        openIngredient("carrots", in: app)
        setPortion("9", in: app)
        app.collectionViews.buttons["Save"].tap()
        app.navigationBars["Planned Recipe"].buttons.element(boundBy: 0).tap()
        XCTAssertFalse(component("carrot soup*", course: "Main", in: app).exists)
        openSoup(in: app)
        openIngredient("carrots", in: app)
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "1")
        setPortion("7", in: app)
        app.collectionViews.buttons["Save"].tap()
        saveRecipe(in: app)
        app.navigationBars["Monday Dinner"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Planner"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "carrot soup*")).firstMatch.exists)
        plan.tap()
        openSoup(in: app)
        openIngredient("carrots", in: app)
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "1")
    }
}
