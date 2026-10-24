import XCTest

final class MealComponentUITests: MealPlannerUITestCase {
    @MainActor
    private func openLunchMeals(in app: XCUIApplication) {
        app.tabBars.buttons["Data"].tap()
        app.buttons["Meals"].tap()
        XCTAssertTrue(app.navigationBars["Meals"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Lunch"].tap()
    }

    @MainActor
    private func openSavedMeal(_ name: String, in app: XCUIApplication) {
        if !app.navigationBars["Meals"].exists {
            openLunchMeals(in: app)
        }
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        let existing = search.value as? String ?? ""
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        search.typeText(name)
        let meal = row(name, in: app)
        XCTAssertTrue(meal.waitForExistence(timeout: 5), app.debugDescription)
        meal.tap()
        XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func chooseAppleSide(in app: XCUIApplication) {
        openDishPicker(course: "Side", in: app)
        XCTAssertTrue(app.segmentedControls.buttons["Recipes"].isSelected)
        app.segmentedControls.buttons["Items"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("apples")
        let apples = row("apples", in: app)
        XCTAssertTrue(apples.waitForExistence(timeout: 5), app.debugDescription)
        apples.tap()
        XCTAssertTrue(app.navigationBars["Ingredient Portion"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func applePortion(in app: XCUIApplication) -> XCUIElement {
        component("apples", course: "Side", in: app)
    }

    @MainActor
    private func assertApplePortion(_ quantity: String, in app: XCUIApplication) {
        let portion = applePortion(in: app)
        scrollTo(portion, in: app)
        XCTAssertTrue(portion.label.contains("apples"), portion.label)
        XCTAssertTrue(portion.label.contains("\(quantity) per person"), portion.label)
    }

    @MainActor
    func testSavedMealPortionsCoursesAndRemovalPersist() {
        let app = XCUIApplication()
        launchInPortrait(app)
        let name = "component lunch"

        XCTContext.runActivity(named: "Create an ingredient portion and cancel a second portion") { _ in
            openLunchMeals(in: app)
            app.collectionViews.buttons["Add"].tap()
            XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
            let nameField = app.textFields["meal name"]
            nameField.tap()
            nameField.typeText(name + "\n")

            chooseAppleSide(in: app)
            setPortion("0.5", in: app)
            scrollTo(app.buttons["saveMealComponent"], in: app)
            app.buttons["saveMealComponent"].tap()
            XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.navigationBars["Dish"].exists)
            assertApplePortion("0.5", in: app)

            chooseAppleSide(in: app)
            XCTAssertEqual(app.textFields.firstMatch.value as? String, "1")
            setPortion("99", in: app)
            app.navigationBars["Ingredient Portion"].buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.navigationBars["Dish"].waitForExistence(timeout: 5))
            app.navigationBars["Dish"].buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "mealComponent-")).count, 1)
            assertApplePortion("0.5", in: app)

            let addMeal = app.collectionViews.buttons["Add"].firstMatch
            scrollTo(addMeal, in: app)
            XCTAssertTrue(addMeal.isEnabled)
            addMeal.tap()
            XCTAssertTrue(app.navigationBars["Meals"].waitForExistence(timeout: 5))
        }

        XCTContext.runActivity(named: "Reopen the saved meal and edit its portion") { _ in
            openSavedMeal(name, in: app)
            assertApplePortion("0.5", in: app)
            performDishAction("Edit Portion", on: applePortion(in: app), in: app)
            XCTAssertTrue(app.navigationBars["Ingredient Portion"].waitForExistence(timeout: 5))
            setPortion("2", in: app)
            scrollTo(app.buttons["saveMealComponent"], in: app)
            app.buttons["saveMealComponent"].tap()
            XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
            assertApplePortion("2", in: app)
        }

        let componentIDs = XCTContext.runActivity(named: "Change one of two identical recipes to an empty course") { _ in
            chooseRecipe("carrot soup", course: "Starter", in: app)
            chooseRecipe("carrot soup", course: "Main", in: app)
            let starter = component("carrot soup", course: "Starter", in: app)
            let originalMain = component("carrot soup", course: "Main", in: app)
            let starterID = starter.identifier
            let mainID = originalMain.identifier
            let portionID = applePortion(in: app).identifier

            changeCourse(of: starter, to: "Dessert", in: app)
            XCTAssertFalse(component("carrot soup", course: "Starter", in: app).exists)
            XCTAssertTrue(component(withID: mainID, course: "Main", in: app).exists)
            XCTAssertEqual(componentIdentifiers(in: app), [mainID, portionID, starterID])
            assertApplePortion("2", in: app)
            let saveMeal = app.collectionViews.buttons["Save"].firstMatch
            scrollTo(saveMeal, in: app)
            saveMeal.tap()
            XCTAssertTrue(app.navigationBars["Meals"].waitForExistence(timeout: 5))
            return (changed: starterID, original: mainID, portion: portionID)
        }

        XCTContext.runActivity(named: "Reopen the meal and delete only the original recipe") { _ in
            openSavedMeal(name, in: app)
            XCTAssertTrue(component(withID: componentIDs.changed, course: "Dessert", in: app).exists)
            XCTAssertTrue(component(withID: componentIDs.portion, course: "Side", in: app).exists)
            XCTAssertEqual(componentIdentifiers(in: app), [componentIDs.original, componentIDs.portion, componentIDs.changed])

            let original = component(withID: componentIDs.original, course: "Main", in: app)
            performDishAction("Delete Dish", on: original, in: app)
            XCTAssertTrue(app.buttons[componentIDs.original].waitForNonExistence(timeout: 5), app.debugDescription)
            XCTAssertTrue(component(withID: componentIDs.changed, course: "Dessert", in: app).exists)
            let save = app.collectionViews.buttons["Save"].firstMatch
            scrollTo(save, in: app)
            save.tap()
            XCTAssertTrue(app.navigationBars["Meals"].waitForExistence(timeout: 5))
        }

        XCTContext.runActivity(named: "Relaunch to verify portion, changed course and deletion") { _ in
            app.terminate()
            launchInPortrait(app)
            openSavedMeal(name, in: app)
            assertApplePortion("2", in: app)
            let remaining = component(withID: componentIDs.changed, course: "Dessert", in: app)
            scrollTo(remaining, in: app)
            XCTAssertTrue(remaining.exists, app.debugDescription)
            XCTAssertEqual(componentIdentifiers(in: app), [componentIDs.portion, componentIDs.changed])
            XCTAssertFalse(app.buttons[componentIDs.original].exists)
        }
    }

    @MainActor
    private func chooseRecipe(_ name: String, course: String, in app: XCUIApplication) {
        openDishPicker(course: course, in: app)
        XCTAssertTrue(app.segmentedControls.buttons["Recipes"].isSelected)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name)
        let recipe = row(name, in: app)
        XCTAssertTrue(recipe.waitForExistence(timeout: 5), app.debugDescription)
        recipe.tap()
        XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func componentIdentifiers(in app: XCUIApplication) -> [String] {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "mealComponent-"))
            .allElementsBoundByIndex.map(\.identifier)
    }
}
