import XCTest

@MainActor
final class RecipeSubstitutionUITests: MealPlannerUITestCase {
    private func addSoupToMonday(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        app.tabBars.buttons["Planner"].tap()
        app.buttons["Add dinner for Monday"].tap()
        let addMain = app.buttons["Add Main dish"]
        scrollTo(addMain, in: app, file: file, line: line)
        addMain.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), file: file, line: line)
        search.tap()
        search.typeText("carrot soup")
        let soup = row("carrot soup", in: app)
        XCTAssertTrue(soup.waitForExistence(timeout: 5), file: file, line: line)
        soup.tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5), file: file, line: line)
    }

    private func openSoup(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let soup = component("carrot soup", course: "Main", in: app)
        scrollTo(soup, in: app, file: file, line: line)
        soup.tap()
        XCTAssertTrue(app.navigationBars["Planned Recipe"].waitForExistence(timeout: 5), file: file, line: line)
    }

    private func openIngredient(_ name: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let ingredient = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
            "plannedRecipeIngredient-", name
        )).firstMatch
        XCTAssertTrue(ingredient.waitForExistence(timeout: 5), app.debugDescription, file: file, line: line)
        ingredient.tap()
        XCTAssertTrue(app.navigationBars["Ingredient"].waitForExistence(timeout: 5), file: file, line: line)
    }

    private func saveRecipe(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        save(app.buttons["savePlannedRecipe"], returningTo: "Monday Dinner", in: app, file: file, line: line)
    }

    private func savePlan(_ action: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        save(app.collectionViews.buttons[action].firstMatch, returningTo: "Planner", in: app, file: file, line: line)
    }

    private func saveIngredient(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        save(app.collectionViews.buttons["Save"], returningTo: "Planned Recipe", in: app, file: file, line: line)
    }

    private func save(_ button: XCUIElement, returningTo title: String, in app: XCUIApplication, file: StaticString, line: UInt) {
        scrollTo(button, in: app, file: file, line: line)
        button.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), file: file, line: line)
    }

    private func back(from title: String, to parent: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        app.navigationBars[title].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars[parent].waitForExistence(timeout: 5), file: file, line: line)
    }

    private func expectQuantity(_ quantity: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(field.value as? String, quantity, file: file, line: line)
    }

    private func plan(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    func testSubstitutionAndQuantityPersistWithAsterisksAndCanBeReset() {
        let app = XCUIApplication()
        launchInPortrait(app)
        resetSampleData(in: app)
        defer { resetSampleData(in: app) }
        addSoupToMonday(in: app)
        openSoup(in: app)

        openIngredient("carrots", in: app)
        setPortion("99", in: app)
        back(from: "Ingredient", to: "Planned Recipe", in: app)
        openIngredient("carrots", in: app)
        expectQuantity("1", in: app)
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
        expectQuantity("8", in: app)
        saveIngredient(in: app)
        XCTAssertTrue(app.staticTexts["carrot soup*"].exists)
        saveRecipe(in: app)
        XCTAssertTrue(component("carrot soup*", course: "Main", in: app).exists)
        savePlan("Add", in: app)
        XCTAssertTrue(self.plan(named: "carrot soup*", in: app).exists)

        app.terminate()
        launchInPortrait(app)
        app.tabBars.buttons["Planner"].tap()
        let plan = self.plan(named: "carrot soup*", in: app)
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        plan.tap()
        openSoup(in: app)
        openIngredient("potatoes", in: app)
        expectQuantity("8", in: app)
        back(from: "Ingredient", to: "Planned Recipe", in: app)
        let reset = app.buttons["Reset to Original Recipe"]
        scrollTo(reset, in: app)
        reset.tap()
        XCTAssertFalse(app.staticTexts["carrot soup*"].exists)
        openIngredient("carrots", in: app)
        expectQuantity("1", in: app)
        back(from: "Ingredient", to: "Planned Recipe", in: app)
        saveRecipe(in: app)
        savePlan("Save", in: app)
        XCTAssertFalse(self.plan(named: "carrot soup*", in: app).exists)
    }

    func testBackingOutOfRecipeOrPlanDiscardsStagedSubstitutions() {
        let app = XCUIApplication()
        launchInPortrait(app)
        resetSampleData(in: app)
        defer { resetSampleData(in: app) }
        addSoupToMonday(in: app)
        savePlan("Add", in: app)
        let plan = self.plan(named: "carrot soup", in: app)
        plan.tap()
        openSoup(in: app)
        openIngredient("carrots", in: app)
        setPortion("9", in: app)
        saveIngredient(in: app)
        back(from: "Planned Recipe", to: "Monday Dinner", in: app)
        XCTAssertFalse(component("carrot soup*", course: "Main", in: app).exists)
        openSoup(in: app)
        openIngredient("carrots", in: app)
        expectQuantity("1", in: app)
        setPortion("7", in: app)
        saveIngredient(in: app)
        saveRecipe(in: app)
        back(from: "Monday Dinner", to: "Planner", in: app)
        XCTAssertFalse(self.plan(named: "carrot soup*", in: app).exists)
        plan.tap()
        openSoup(in: app)
        openIngredient("carrots", in: app)
        expectQuantity("1", in: app)
    }
}
