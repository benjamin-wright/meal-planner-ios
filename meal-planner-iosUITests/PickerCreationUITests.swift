import XCTest

final class PickerCreationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
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
    private func enterName(_ name: String, placeholder: String, in app: XCUIApplication) {
        let field = app.textFields[placeholder]
        XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
        field.tap()
        field.typeText(name + "\n")
    }

    @MainActor
    private func openNewSavedMeal(_ name: String, in app: XCUIApplication) {
        app.tabBars.buttons["Data"].tap()
        app.buttons["Meals"].tap()
        XCTAssertTrue(app.navigationBars["Meals"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Lunch"].tap()
        app.collectionViews.buttons["Add"].tap()
        enterName(name, placeholder: "meal name", in: app)
    }

    @MainActor
    private func openDishCreation(_ kind: String, course: String, in app: XCUIApplication) {
        let addDish = app.buttons["Add \(course) dish"]
        scrollTo(addDish, in: app)
        addDish.tap()
        XCTAssertTrue(app.navigationBars["Dish"].waitForExistence(timeout: 5))
        app.navigationBars["Dish"].buttons["Add"].tap()
        app.buttons[kind].tap()
    }

    @MainActor
    private func saveForm(in app: XCUIApplication) {
        let add = app.collectionViews.buttons["Add"].firstMatch
        scrollTo(add, in: app)
        XCTAssertTrue(add.isEnabled, app.debugDescription)
        add.tap()
    }

    @MainActor
    private func component(_ name: String, course: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@ AND value == %@",
            "mealComponent-", name, course
        )).firstMatch
    }

    @MainActor
    private func assertComponent(_ name: String, course: String, in app: XCUIApplication) {
        let dish = component(name, course: course, in: app)
        scrollTo(dish, in: app)
        XCTAssertTrue(dish.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.navigationBars["Dish"].exists)
    }

    @MainActor
    func testCreatedRecipeAndReadyMealAreAddedToTheirChosenCourses() {
        let app = XCUIApplication()
        app.launch()
        let suffix = UUID().uuidString.lowercased()
        let mealName = "picker meal \(suffix)"
        let recipeName = "picker recipe \(suffix)"
        let readyMealName = "picker ready meal \(suffix)"
        openNewSavedMeal(mealName, in: app)

        openDishCreation("Recipe", course: "Starter", in: app)
        enterName(recipeName, placeholder: "recipe name", in: app)
        app.buttons["saveRecipe"].tap()
        XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
        assertComponent(recipeName, course: "Starter", in: app)

        openDishCreation("Ready Meal", course: "Side", in: app)
        enterName(readyMealName, placeholder: "item name", in: app)
        saveForm(in: app)
        XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
        assertComponent(readyMealName, course: "Side", in: app)
        assertComponent(recipeName, course: "Starter", in: app)
        scrollTo(app.textFields["meal name"], in: app)
        XCTAssertEqual(app.textFields["meal name"].value as? String, mealName)

        saveForm(in: app)
        XCTAssertTrue(app.navigationBars["Meals"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCreatedIngredientAutomaticallyOpensItsPortionEditor() {
        let app = XCUIApplication()
        app.launch()
        let suffix = UUID().uuidString.lowercased()
        let ingredientName = "picker ingredient \(suffix)"
        openNewSavedMeal("picker ingredient meal \(suffix)", in: app)

        openDishCreation("Ingredient", course: "Side", in: app)
        enterName(ingredientName, placeholder: "item name", in: app)
        saveForm(in: app)
        XCTAssertTrue(app.navigationBars["Ingredient Portion"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", ingredientName
        )).firstMatch.exists, app.debugDescription)

        let quantity = app.textFields.firstMatch
        XCTAssertTrue(quantity.waitForExistence(timeout: 5))
        quantity.tap()
        let existing = quantity.value as? String ?? ""
        quantity.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        quantity.typeText("0.5")
        app.buttons["hideKeyboard"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        let savePortion = app.buttons["saveMealComponent"]
        scrollTo(savePortion, in: app)
        XCTAssertTrue(savePortion.isEnabled, app.debugDescription)
        savePortion.tap()

        XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
        assertComponent(ingredientName, course: "Side", in: app)
        XCTAssertTrue(component(ingredientName, course: "Side", in: app).label.contains("0.5 per person"))
        saveForm(in: app)
        XCTAssertTrue(app.navigationBars["Meals"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMealCreatedFromPlannerPickerImmediatelySuppliesItsDishes() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Planner"].tap()
        app.segmentedControls.buttons["Lunch"].tap()
        let addLunch = app.buttons["Add lunch"]
        scrollTo(addLunch, in: app)
        addLunch.tap()
        XCTAssertTrue(app.navigationBars["Lunch"].waitForExistence(timeout: 5))
        app.buttons["Choose Saved Meal"].tap()
        XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["Lunch"].isSelected)
        app.navigationBars["Meal"].buttons["Add"].tap()

        let suffix = UUID().uuidString.lowercased()
        let mealName = "planner picker meal \(suffix)"
        let recipeName = "planner picker recipe \(suffix)"
        enterName(mealName, placeholder: "meal name", in: app)
        openDishCreation("Recipe", course: "Main", in: app)
        enterName(recipeName, placeholder: "recipe name", in: app)
        app.buttons["saveRecipe"].tap()
        assertComponent(recipeName, course: "Main", in: app)
        saveForm(in: app)

        XCTAssertTrue(app.navigationBars["Lunch"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.navigationBars["Meal"].exists)
        assertComponent(recipeName, course: "Main", in: app)
        saveForm(in: app)
        XCTAssertTrue(app.navigationBars["Planner"].waitForExistence(timeout: 5))
        let planned = app.collectionViews.buttons.matching(NSPredicate(format: "label CONTAINS %@", recipeName)).firstMatch
        XCTAssertTrue(planned.waitForExistence(timeout: 5), app.debugDescription)
    }
}
