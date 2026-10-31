import XCTest

final class PickerCreationUITests: MealPlannerUITestCase {
    @MainActor
    func testNestedCreationAddsDishesAndPreservesParentDrafts() {
        let app = XCUIApplication()
        launchInPortrait(app)
        let mealName = "picker meal"
        openNewSavedMeal(mealName, in: app)

        XCTContext.runActivity(named: "Create recipe and ready-meal dishes in one meal") { _ in
            createRecipeAndReadyMeal(in: app, mealName: mealName)
        }
        XCTContext.runActivity(named: "Create an ingredient portion and save the same meal") { _ in
            createIngredientPortion(in: app)
            assertComponent("picker recipe", course: "Starter", in: app)
            assertComponent("picker ready meal", course: "Side", in: app)
            scrollTo(app.textFields["meal name"], in: app)
            XCTAssertEqual(app.textFields["meal name"].value as? String, mealName)
            saveForm(in: app)
            XCTAssertTrue(app.navigationBars["Meals"].waitForExistence(timeout: 5))
        }
        XCTContext.runActivity(named: "Create a meal and its recipe from the planner picker") { _ in
            createMealFromPlannerPicker(in: app)
        }
        let miscItemName = "new planner misc item"
        XCTContext.runActivity(named: "Create a misc item and reopen its saved planner entry") { _ in
            createAndReopenMiscEntry(itemName: miscItemName, in: app)
        }
        XCTContext.runActivity(named: "Replace the reopened entry's item after searching and creating a category") { _ in
            replaceItemInOpenMiscEntry(previousItemName: miscItemName, in: app)
        }
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
        openDishPicker(course: course, in: app)
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
    private func assertComponent(_ name: String, course: String, in app: XCUIApplication) {
        let dish = component(name, course: course, in: app)
        scrollTo(dish, in: app)
        XCTAssertTrue(dish.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.navigationBars["Dish"].exists)
    }

    @MainActor
    private func createRecipeAndReadyMeal(in app: XCUIApplication, mealName: String) {
        let recipeName = "picker recipe"
        let readyMealName = "picker ready meal"

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
    }

    @MainActor
    private func createIngredientPortion(in app: XCUIApplication) {
        let ingredientName = "picker ingredient"

        openDishCreation("Ingredient", course: "Side", in: app)
        enterName(ingredientName, placeholder: "item name", in: app)
        saveForm(in: app)
        XCTAssertTrue(app.navigationBars["Ingredient Portion"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", ingredientName
        )).firstMatch.exists, app.debugDescription)

        setPortion("0.5", in: app)
        let savePortion = app.buttons["saveMealComponent"]
        scrollTo(savePortion, in: app)
        XCTAssertTrue(savePortion.isEnabled, app.debugDescription)
        savePortion.tap()

        XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
        assertComponent(ingredientName, course: "Side", in: app)
        XCTAssertTrue(component(ingredientName, course: "Side", in: app).label.contains("0.5 per person"))
    }

    @MainActor
    private func createMealFromPlannerPicker(in app: XCUIApplication) {
        app.tabBars.buttons["Planner"].tap()
        app.segmentedControls.buttons["Lunch"].tap()
        let addLunch = app.buttons["Add lunch"]
        scrollTo(addLunch, in: app)
        addLunch.tap()
        XCTAssertTrue(app.navigationBars["Lunch"].waitForExistence(timeout: 5))
        app.buttons["chooseMeal"].tap()
        XCTAssertTrue(app.navigationBars["Choose a meal"].waitForExistence(timeout: 5))
        app.buttons["mealDiscovery-name"].tap()
        XCTAssertTrue(app.navigationBars["By name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["discoveryMealType"].value as? String, "Lunch")
        app.buttons["createDiscoveryMeal"].tap()
        XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))

        let mealName = "planner picker meal"
        let recipeName = "planner picker recipe"
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
        let planned = app.collectionViews.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", recipeName)).firstMatch
        XCTAssertTrue(planned.waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    private func createAndReopenMiscEntry(itemName: String, in app: XCUIApplication) {
        app.tabBars.buttons["Planner"].tap()
        app.segmentedControls.buttons["Misc"].tap()
        app.buttons["Add item or note"].tap()
        XCTAssertTrue(app.navigationBars["Misc Entry"].waitForExistence(timeout: 5))

        setPortion("3", in: app)
        row("Item", in: app).tap()
        app.navigationBars["Item"].buttons["Add"].tap()
        enterName(itemName, placeholder: "item name", in: app)
        app.segmentedControls.buttons["Misc"].tap()
        saveForm(in: app)

        XCTAssertTrue(app.navigationBars["Misc Entry"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.navigationBars["Item"].exists)
        XCTAssertTrue(row("Item", in: app).staticTexts[itemName].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "3")
        let save = app.buttons["Save Item"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.navigationBars["Planner"].waitForExistence(timeout: 5))
        let entry = row(itemName, in: app)
        XCTAssertTrue(entry.waitForExistence(timeout: 5), app.debugDescription)
        entry.tap()
        XCTAssertTrue(app.navigationBars["Misc Entry"].waitForExistence(timeout: 5))
        XCTAssertTrue(row("Item", in: app).staticTexts[itemName].exists)
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "3")
    }

    @MainActor
    private func replaceItemInOpenMiscEntry(previousItemName: String, in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Misc Entry"].waitForExistence(timeout: 5))
        setPortion("4", in: app)
        row("Item", in: app).tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("missing misc item")
        app.navigationBars["Item"].buttons["Close"].tap()
        app.navigationBars["Item"].buttons["Add"].tap()
        let itemName = "replacement planner misc item"
        enterName(itemName, placeholder: "item name", in: app)
        app.segmentedControls.buttons["Misc"].tap()
        row("Category", in: app).tap()
        app.navigationBars["Category"].buttons["createCategory"].tap()
        enterName("new misc category", placeholder: "category", in: app)
        saveForm(in: app)
        XCTAssertTrue(app.textFields["item name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["item name"].value as? String, itemName)
        saveForm(in: app)

        XCTAssertTrue(app.navigationBars["Misc Entry"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(row("Item", in: app).staticTexts[itemName].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "4")
        app.buttons["Save Item"].tap()
        XCTAssertTrue(app.navigationBars["Planner"].waitForExistence(timeout: 5))
        XCTAssertTrue(row(itemName, in: app).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(row(previousItemName, in: app).exists)
    }
}
