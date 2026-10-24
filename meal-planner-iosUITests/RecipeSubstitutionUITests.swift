import XCTest

@MainActor
final class RecipeSubstitutionUITests: MealPlannerUITestCase {
    private func addSoupToMonday(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        app.tabBars.buttons["Planner"].tap()
        app.buttons["Add dinner for Monday"].tap()
        openDishPicker(in: app, file: file, line: line)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), file: file, line: line)
        search.tap()
        search.typeText("carrot soup")
        let soup = row("carrot soup", in: app)
        XCTAssertTrue(soup.waitForExistence(timeout: 5), file: file, line: line)
        soup.tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5), file: file, line: line)
    }

    private func openSoup(course: String = "Main", in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let soup = component("carrot soup", course: course, in: app)
        performDishAction("Substitute Ingredients", on: soup, in: app, file: file, line: line)
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
        app.staticTexts.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "plannedDinner-", name
        )).firstMatch
    }

    private func editDinner(
        on day: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let actions = app.buttons["plannedDinnerActions-\(day)"]
        scrollTo(actions, in: app, within: app.scrollViews.firstMatch, file: file, line: line)
        actions.tap()
        let edit = app.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), file: file, line: line)
        edit.tap()
        XCTAssertTrue(app.navigationBars["\(day) Dinner"].waitForExistence(timeout: 5), file: file, line: line)
    }

    private func dayRow(_ day: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "dinnerDay-\(day)").firstMatch
    }

    private func expectDinner(
        _ label: String, on day: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let dinner = app.staticTexts["plannedDinner-\(day)"]
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: dinner)
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 5), .completed, app.debugDescription,
                       file: file, line: line)
    }

    private func expectFixedDayBadges(in app: XCUIApplication) {
        let saturday = dayRow("Saturday", in: app).staticTexts["Saturday"]
        let sunday = dayRow("Sunday", in: app).staticTexts["Sunday"]
        let monday = dayRow("Monday", in: app).staticTexts["Monday"]
        XCTAssertTrue(saturday.exists)
        XCTAssertTrue(sunday.exists)
        XCTAssertTrue(monday.exists)
        XCTAssertLessThan(saturday.frame.midY, sunday.frame.midY)
        XCTAssertLessThan(sunday.frame.midY, monday.frame.midY)
    }

    func testPlannedRecipeChangesAndTemplateReplacement() {
        let app = XCUIApplication()
        launchInPortrait(app)

        XCTContext.runActivity(named: "Create Monday dinner and discard staged recipe and plan changes") { _ in
            addSoupToMonday(in: app)
            savePlan("Add", in: app)
            let dinner = plan(named: "carrot soup", in: app)
            XCTAssertTrue(dinner.waitForExistence(timeout: 5))
            editDinner(on: "Monday", in: app)
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
            XCTAssertFalse(plan(named: "carrot soup*", in: app).exists)
            editDinner(on: "Monday", in: app)
            openSoup(in: app)
            openIngredient("carrots", in: app)
            expectQuantity("1", in: app)
        }

        let substitutedID = XCTContext.runActivity(named: "Save a substitution and move the dish to an empty course") { _ in
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
            let soup = component("carrot soup*", course: "Main", in: app)
            XCTAssertTrue(soup.exists)
            let identifier = soup.identifier
            changeCourse(of: soup, to: "Side", in: app)
            savePlan("Save", in: app)
            XCTAssertTrue(plan(named: "carrot soup*", in: app).exists)
            return identifier
        }

        XCTContext.runActivity(named: "Relaunch to verify the substitution, then reset the original recipe") { _ in
            app.terminate()
            launchInPortrait(app)
            app.tabBars.buttons["Planner"].tap()
            let dinner = plan(named: "carrot soup*", in: app)
            XCTAssertTrue(dinner.waitForExistence(timeout: 5))
            editDinner(on: "Monday", in: app)
            XCTAssertTrue(component(withID: substitutedID, course: "Side", in: app).waitForExistence(timeout: 5))
            openSoup(course: "Side", in: app)
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
            XCTAssertFalse(plan(named: "carrot soup*", in: app).exists)
        }

        XCTContext.runActivity(named: "Replace Monday dinner with a lunch template without changing its slot") { _ in
            let originalDinner = plan(named: "carrot soup", in: app)
            XCTAssertTrue(originalDinner.waitForExistence(timeout: 5), app.debugDescription)
            editDinner(on: "Monday", in: app)
            app.buttons["Choose Saved Meal"].tap()
            XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.segmentedControls.buttons["Dinner"].isSelected)
            app.segmentedControls.buttons["Lunch"].tap()
            let lunchTemplate = app.buttons["Salmon Lunch"]
            XCTAssertTrue(lunchTemplate.waitForExistence(timeout: 5), app.debugDescription)
            lunchTemplate.tap()
            XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5))
            savePlan("Save", in: app)

            let updatedDinner = plan(named: "salmon salad", in: app)
            XCTAssertTrue(updatedDinner.waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertFalse(app.buttons["Add dinner for Monday"].exists)
            XCTAssertFalse(originalDinner.exists)
            editDinner(on: "Monday", in: app)
        }

        let dinners = XCTContext.runActivity(named: "Drag Monday onto occupied Saturday without moving the day badges") { _ in
            back(from: "Monday Dinner", to: "Planner", in: app)
            let monday = app.staticTexts["plannedDinner-Monday"]
            let saturday = app.staticTexts["plannedDinner-Saturday"]
            let sunday = app.staticTexts["plannedDinner-Sunday"]
            scrollTo(monday, in: app, within: app.scrollViews.firstMatch)
            scrollTo(saturday, in: app, within: app.scrollViews.firstMatch)
            let labels = (monday: monday.label, saturday: saturday.label, sunday: sunday.label)
            XCTAssertTrue(labels.monday.hasPrefix("salmon salad"))
            XCTAssertNotEqual(labels.monday, labels.saturday)
            expectFixedDayBadges(in: app)
            XCTAssertTrue(monday.isHittable)
            monday.press(forDuration: 1, thenDragTo: dayRow("Saturday", in: app))

            expectDinner(labels.saturday, on: "Monday", in: app)
            expectDinner(labels.monday, on: "Saturday", in: app)
            expectDinner(labels.sunday, on: "Sunday", in: app)
            expectFixedDayBadges(in: app)
            return labels
        }

        XCTContext.runActivity(named: "Move Monday dinner to empty Wednesday through its menu") { _ in
            XCTAssertTrue(app.buttons["Add dinner for Wednesday"].exists)
            let actions = app.buttons["plannedDinnerActions-Monday"]
            scrollTo(actions, in: app, within: app.scrollViews.firstMatch)
            actions.tap()
            let move = app.buttons["Move to…"]
            XCTAssertTrue(move.waitForExistence(timeout: 5))
            move.tap()
            XCTAssertTrue(app.buttons["Swap with Saturday"].waitForExistence(timeout: 5))
            let wednesday = app.buttons["Move to Wednesday"]
            XCTAssertTrue(wednesday.waitForExistence(timeout: 5))
            wednesday.tap()

            XCTAssertTrue(app.buttons["Add dinner for Monday"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.staticTexts["plannedDinner-Monday"].exists)
            expectDinner(dinners.saturday, on: "Wednesday", in: app)
            expectDinner(dinners.monday, on: "Saturday", in: app)
            expectDinner(dinners.sunday, on: "Sunday", in: app)
            expectFixedDayBadges(in: app)
        }

        XCTContext.runActivity(named: "Relaunch to verify the dinner swap and move persisted") { _ in
            app.terminate()
            launchInPortrait(app)
            app.tabBars.buttons["Planner"].tap()
            app.segmentedControls.buttons["Dinner"].tap()
            XCTAssertTrue(app.buttons["Add dinner for Monday"].waitForExistence(timeout: 5))
            expectDinner(dinners.saturday, on: "Wednesday", in: app)
            expectDinner(dinners.monday, on: "Saturday", in: app)
            expectDinner(dinners.sunday, on: "Sunday", in: app)
            expectFixedDayBadges(in: app)
            editDinner(on: "Saturday", in: app)
            XCTAssertTrue(component("salmon salad", course: "Main", in: app).exists)
        }

        XCTContext.runActivity(named: "Delete Saturday dinner through its menu and keep Wednesday dinner") { _ in
            back(from: "Saturday Dinner", to: "Planner", in: app)
            let actions = app.buttons["plannedDinnerActions-Saturday"]
            scrollTo(actions, in: app, within: app.scrollViews.firstMatch)
            actions.tap()
            let delete = app.buttons["Delete"]
            XCTAssertTrue(delete.waitForExistence(timeout: 5))
            delete.tap()
            XCTAssertTrue(app.buttons["Add dinner for Saturday"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.staticTexts["plannedDinner-Saturday"].exists)
            expectDinner(dinners.saturday, on: "Wednesday", in: app)
        }
    }
}
