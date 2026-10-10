import XCTest

final class MealComponentUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func row(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
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
    private func openLunchMeals(in app: XCUIApplication) {
        app.tabBars.buttons["Data"].tap()
        app.buttons["Meals"].tap()
        XCTAssertTrue(app.navigationBars["Meals"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Lunch"].tap()
    }

    @MainActor
    private func openSavedMeal(_ name: String, in app: XCUIApplication) {
        openLunchMeals(in: app)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name)
        let meal = row(name, in: app)
        XCTAssertTrue(meal.waitForExistence(timeout: 5), app.debugDescription)
        meal.tap()
        XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func chooseAppleSide(in app: XCUIApplication) {
        let addSide = app.buttons["Add Side dish"]
        scrollTo(addSide, in: app)
        addSide.tap()
        XCTAssertTrue(app.navigationBars["Dish"].waitForExistence(timeout: 5))
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
    private func setPortion(_ quantity: String, in app: XCUIApplication) {
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        let existing = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        field.typeText(quantity)
        app.buttons["hideKeyboard"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    }

    @MainActor
    private func applePortion(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "mealComponent-")).firstMatch
    }

    @MainActor
    private func assertApplePortion(_ quantity: String, in app: XCUIApplication) {
        let portion = applePortion(in: app)
        scrollTo(portion, in: app)
        XCTAssertTrue(portion.label.contains("apples"), portion.label)
        XCTAssertTrue(portion.label.contains("\(quantity) per person"), portion.label)
    }

    @MainActor
    func testIngredientPortionsCanBeCancelledEditedAndPersisted() {
        let app = XCUIApplication()
        app.launch()
        openLunchMeals(in: app)
        app.collectionViews.buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))

        let name = "ingredient lunch \(UUID().uuidString.lowercased())"
        let nameField = app.textFields["meal name"]
        nameField.tap()
        nameField.typeText(name + "\n")

        chooseAppleSide(in: app)
        setPortion("0.5", in: app)
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

        app.terminate()
        app.launch()
        openSavedMeal(name, in: app)
        assertApplePortion("0.5", in: app)
        applePortion(in: app).tap()
        XCTAssertTrue(app.navigationBars["Ingredient Portion"].waitForExistence(timeout: 5))
        setPortion("2", in: app)
        app.buttons["saveMealComponent"].tap()
        XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
        assertApplePortion("2", in: app)
        let saveMeal = app.collectionViews.buttons["Save"].firstMatch
        scrollTo(saveMeal, in: app)
        saveMeal.tap()
        XCTAssertTrue(app.navigationBars["Meals"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        openSavedMeal(name, in: app)
        assertApplePortion("2", in: app)
    }

    @MainActor
    private func chooseRecipe(_ name: String, course: String, editorTitle: String, in app: XCUIApplication) {
        let addDish = app.buttons["Add \(course) dish"]
        scrollTo(addDish, in: app)
        addDish.tap()
        XCTAssertTrue(app.navigationBars["Dish"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["Recipes"].isSelected)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name)
        let recipe = row(name, in: app)
        XCTAssertTrue(recipe.waitForExistence(timeout: 5), app.debugDescription)
        recipe.tap()
        XCTAssertTrue(app.navigationBars[editorTitle].waitForExistence(timeout: 5))
    }

    @MainActor
    private func soupComponent(course: String, in app: XCUIApplication) -> XCUIElement {
        component("carrot soup", course: course, in: app)
    }

    @MainActor
    private func component(_ name: String, course: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@ AND value == %@",
            "mealComponent-", name, course
        )).firstMatch
    }

    @MainActor
    private func component(withID identifier: String, course: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier == %@ AND value == %@", identifier, course
        )).firstMatch
    }

    @MainActor
    private func moveComponent(
        _ name: String, from sourceCourse: String, to destinationCourse: String,
        sourceID: String? = nil, after: Bool = false, editorTitle: String, in app: XCUIApplication
    ) {
        app.navigationBars[editorTitle].buttons["Edit"].tap()
        let source = sourceID.map { component(withID: $0, course: sourceCourse, in: app) }
            ?? component(name, course: sourceCourse, in: app)
        scrollTo(source, in: app)
        let movedID = source.identifier
        scrollTo(app.descendants(matching: .any)["courseHeader-\(destinationCourse)"], in: app)
        let emptyCourse = app.descendants(matching: .any)["courseDrop-\(destinationCourse)"]
        let destination = emptyCourse.exists ? emptyCourse : app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier != %@ AND value == %@",
            "mealComponent-", movedID, destinationCourse
        )).firstMatch
        scrollTo(destination, in: app)
        let list = app.collectionViews.firstMatch
        let centeringDistance = min(
            max(0, destination.frame.midY - list.frame.midY),
            max(0, source.frame.minY - list.frame.minY - 60)
        )
        if centeringDistance > 20 {
            let scrollStart = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            scrollStart.press(
                forDuration: 0.01,
                thenDragTo: scrollStart.withOffset(CGVector(dx: 0, dy: -centeringDistance)),
                withVelocity: 500,
                thenHoldForDuration: 0
            )
        }
        XCTAssertTrue(source.isHittable, app.debugDescription)
        XCTAssertTrue(destination.isHittable, app.debugDescription)
        let handleID = movedID.replacingOccurrences(of: "mealComponent-", with: "reorderMealComponent-")
        let handle = app.descendants(matching: .any)[handleID]
        XCTAssertTrue(handle.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(handle.isHittable, app.debugDescription)
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(CGVector(
            dx: destination.frame.midX - app.frame.minX,
            dy: destination.frame.minY + destination.frame.height * (after ? 0.75 : 0.25) - app.frame.minY
        ))
        start.press(forDuration: 1, thenDragTo: end, withVelocity: 100, thenHoldForDuration: 0.5)
        XCTAssertTrue(component(withID: movedID, course: destinationCourse, in: app).waitForExistence(timeout: 5), app.debugDescription)
        app.navigationBars[editorTitle].buttons["Done"].tap()
        XCTAssertFalse(app.navigationBars["Dish Details"].exists)
    }

    @MainActor
    func testRecipeCourseBelongsToEachMealComponent() {
        let app = XCUIApplication()
        app.launch()
        openLunchMeals(in: app)
        app.collectionViews.buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
        let name = "course lunch \(UUID().uuidString.lowercased())"
        let nameField = app.textFields["meal name"]
        nameField.tap()
        nameField.typeText(name + "\n")

        chooseRecipe("carrot soup", course: "Starter", editorTitle: "Meal", in: app)
        chooseRecipe("carrot soup", course: "Main", editorTitle: "Meal", in: app)
        let starter = soupComponent(course: "Starter", in: app)
        scrollTo(starter, in: app)
        XCTAssertTrue(starter.exists, app.debugDescription)
        let starterID = starter.identifier
        let originalMain = soupComponent(course: "Main", in: app)
        scrollTo(originalMain, in: app)
        let mainID = originalMain.identifier

        moveComponent("carrot soup", from: "Starter", to: "Main", sourceID: starterID, editorTitle: "Meal", in: app)
        XCTAssertFalse(soupComponent(course: "Starter", in: app).exists)
        XCTAssertTrue(component(withID: starterID, course: "Main", in: app).exists, app.debugDescription)
        XCTAssertTrue(component(withID: mainID, course: "Main", in: app).exists, app.debugDescription)
        let movedMain = component(withID: starterID, course: "Main", in: app)
        let unchangedMain = component(withID: mainID, course: "Main", in: app)
        scrollTo(movedMain, in: app)
        scrollTo(unchangedMain, in: app)
        XCTAssertLessThan(movedMain.frame.midY, unchangedMain.frame.midY)

        moveComponent("carrot soup", from: "Main", to: "Main", sourceID: starterID,
                      after: true, editorTitle: "Meal", in: app)
        scrollTo(unchangedMain, in: app)
        scrollTo(movedMain, in: app)
        XCTAssertGreaterThan(movedMain.frame.midY, unchangedMain.frame.midY)
        let addMeal = app.collectionViews.buttons["Add"].firstMatch
        scrollTo(addMeal, in: app)
        addMeal.tap()
        XCTAssertTrue(app.navigationBars["Meals"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        openSavedMeal(name, in: app)
        let persistedMovedMain = component(withID: starterID, course: "Main", in: app)
        let persistedOriginalMain = component(withID: mainID, course: "Main", in: app)
        scrollTo(persistedOriginalMain, in: app)
        scrollTo(persistedMovedMain, in: app)
        XCTAssertGreaterThan(persistedMovedMain.frame.midY, persistedOriginalMain.frame.midY)

        moveComponent("carrot soup", from: "Main", to: "Side", sourceID: starterID, editorTitle: "Meal", in: app)
        let main = component(withID: mainID, course: "Main", in: app)
        scrollTo(main, in: app)
        XCTAssertTrue(main.exists, app.debugDescription)
        let side = component(withID: starterID, course: "Side", in: app)
        scrollTo(side, in: app)
        XCTAssertTrue(side.exists, app.debugDescription)

        let save = app.collectionViews.buttons["Save"].firstMatch
        scrollTo(save, in: app)
        save.tap()
        XCTAssertTrue(app.navigationBars["Meals"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        openSavedMeal(name, in: app)
        scrollTo(component(withID: mainID, course: "Main", in: app), in: app)
        XCTAssertTrue(component(withID: mainID, course: "Main", in: app).exists)
        scrollTo(component(withID: starterID, course: "Side", in: app), in: app)
        XCTAssertTrue(component(withID: starterID, course: "Side", in: app).exists)

        app.navigationBars["Meal"].buttons["Edit"].tap()
        let removeID = starterID.replacingOccurrences(of: "mealComponent-", with: "removeMealComponent-")
        let remove = app.buttons[removeID]
        scrollTo(remove, in: app)
        remove.tap()
        XCTAssertTrue(app.descendants(matching: .any)[starterID].waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(component(withID: mainID, course: "Main", in: app).exists, app.debugDescription)
        app.navigationBars["Meal"].buttons["Done"].tap()
        let saveAfterRemoval = app.collectionViews.buttons["Save"].firstMatch
        scrollTo(saveAfterRemoval, in: app)
        saveAfterRemoval.tap()
        XCTAssertTrue(app.navigationBars["Meals"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        openSavedMeal(name, in: app)
        let remaining = component(withID: mainID, course: "Main", in: app)
        scrollTo(remaining, in: app)
        XCTAssertTrue(remaining.exists, app.debugDescription)
        XCTAssertFalse(app.descendants(matching: .any)[starterID].exists, app.debugDescription)
    }

    @MainActor
    func testPlannedMealCanMoveARecipeIntoAnEmptyCourseAndPersistIt() {
        let app = XCUIApplication()
        app.launch()
        let recipeName = "planned course recipe \(UUID().uuidString.lowercased())"
        app.tabBars.buttons["Data"].tap()
        app.buttons["Recipies"].tap()
        XCTAssertTrue(app.navigationBars["Recipies"].waitForExistence(timeout: 5))
        let addRecipe = app.collectionViews.buttons["Add"].firstMatch
        scrollTo(addRecipe, in: app)
        addRecipe.tap()
        XCTAssertTrue(app.navigationBars["Recipe"].waitForExistence(timeout: 5))
        let nameField = app.textFields["recipe name"]
        nameField.tap()
        nameField.typeText(recipeName + "\n")
        app.buttons["saveRecipe"].tap()
        XCTAssertTrue(app.navigationBars["Recipies"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Planner"].tap()
        app.segmentedControls.buttons["Lunch"].tap()
        let addLunch = app.buttons["Add lunch"]
        scrollTo(addLunch, in: app)
        addLunch.tap()
        XCTAssertTrue(app.navigationBars["Lunch"].waitForExistence(timeout: 5))
        let componentCount = 10
        for _ in 0..<componentCount {
            chooseRecipe(recipeName, course: "Main", editorTitle: "Lunch", in: app)
        }
        let mainComponents = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@ AND value == %@",
            "mealComponent-", recipeName, "Main"
        ))
        let mainIDs = mainComponents.allElementsBoundByIndex.map(\.identifier)
        XCTAssertEqual(mainIDs.count, componentCount)
        let movedID = mainComponents.firstMatch.identifier
        let remainingIDs = Set(mainIDs.filter { $0 != movedID })

        app.navigationBars["Lunch"].buttons["Edit"].tap()
        let source = component(withID: movedID, course: "Main", in: app)
        scrollTo(source, in: app)
        XCTAssertFalse(app.descendants(matching: .any)["courseHeader-Side"].isHittable, app.debugDescription)
        XCTAssertFalse(app.descendants(matching: .any)["courseHeader-Dessert"].isHittable, app.debugDescription)
        let handleID = movedID.replacingOccurrences(of: "mealComponent-", with: "reorderMealComponent-")
        let handle = app.descendants(matching: .any)[handleID]
        XCTAssertTrue(handle.isHittable, app.debugDescription)
        let list = app.collectionViews.firstMatch
        let bottom = min(list.frame.maxY, app.tabBars.firstMatch.frame.minY) - 25
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(CGVector(
            dx: list.frame.midX - app.frame.minX,
            dy: bottom - app.frame.minY
        ))
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 1, thenDragTo: edge, withVelocity: 100, thenHoldForDuration: 4
        )
        XCTAssertTrue(component(withID: movedID, course: "Dessert", in: app).waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(Set(mainComponents.allElementsBoundByIndex.map(\.identifier)), remainingIDs)
        app.navigationBars["Lunch"].buttons["Done"].tap()
        let save = app.collectionViews.buttons["Add"].firstMatch
        scrollTo(save, in: app)
        save.tap()
        XCTAssertTrue(app.navigationBars["Planner"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        app.tabBars.buttons["Planner"].tap()
        app.segmentedControls.buttons["Lunch"].tap()
        let plannedMeal = row(recipeName, in: app)
        scrollTo(plannedMeal, in: app)
        plannedMeal.tap()
        XCTAssertTrue(app.navigationBars["Lunch"].waitForExistence(timeout: 5))
        let persisted = component(withID: movedID, course: "Dessert", in: app)
        scrollTo(persisted, in: app)
        XCTAssertTrue(persisted.exists, app.debugDescription)
        XCTAssertEqual(Set(mainComponents.allElementsBoundByIndex.map(\.identifier)), remainingIDs)
    }

}
