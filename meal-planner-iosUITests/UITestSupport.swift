import XCTest

class MealPlannerUITestCase: XCTestCase {
    enum Fixture: String {
        case sample
        case staleShoppingList = "stale-shopping-list"
        case recipeViewer = "recipe-viewer"
    }

    private var storeIdentifier = UUID().uuidString

    override func setUpWithError() throws {
        continueAfterFailure = false
        storeIdentifier = UUID().uuidString
    }

    @MainActor
    func launchInPortrait(_ app: XCUIApplication, fixture: Fixture? = nil) {
        launch(app, fixture: fixture)
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func launch(_ app: XCUIApplication, fixture: Fixture? = nil) {
        app.launchEnvironment["MEAL_PLANNER_UI_TEST_STORE"] = storeIdentifier
        if let fixture {
            app.launchEnvironment["MEAL_PLANNER_UI_TEST_FIXTURE"] = fixture.rawValue
        } else if app.launchEnvironment["MEAL_PLANNER_UI_TEST_FIXTURE"] == nil {
            app.launchEnvironment["MEAL_PLANNER_UI_TEST_FIXTURE"] = Fixture.sample.rawValue
        }
        app.launch()
    }

    @MainActor
    func scrollTo(
        _ element: XCUIElement, in app: XCUIApplication,
        within container: XCUIElement? = nil,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let container = container ?? app.collectionViews.firstMatch
        for _ in 0..<6 {
            if element.isHittable { break }
            container.swipeUp()
        }
        if !element.isHittable {
            for _ in 0..<6 {
                if element.isHittable { break }
                container.swipeDown()
            }
        }
        XCTAssertTrue(element.isHittable, app.debugDescription, file: file, line: line)
    }

    @MainActor
    func row(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    @MainActor
    func openRecipeCatalogue(
        in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        app.tabBars.buttons["Data"].tap()
        app.buttons["Recipies"].tap()
        XCTAssertTrue(app.navigationBars["Recipies"].waitForExistence(timeout: 5), file: file, line: line)
    }

    @MainActor
    func openNewRecipe(
        in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        let add = app.collectionViews.buttons["Add"].firstMatch
        scrollTo(add, in: app, file: file, line: line)
        add.tap()
        XCTAssertTrue(app.navigationBars["Recipe"].waitForExistence(timeout: 5), file: file, line: line)
    }

    @MainActor
    func component(_ name: String, course: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@ AND value == %@",
            "mealComponent-", name, course
        )).firstMatch
    }

    @MainActor
    func component(withID identifier: String, course: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "identifier == %@ AND value == %@", identifier, course
        )).firstMatch
    }

    @MainActor
    func openDishPicker(
        course: String = "Main", in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let add = app.buttons["addDish"]
        scrollTo(add, in: app, file: file, line: line)
        add.tap()
        XCTAssertTrue(app.navigationBars["Dish"].waitForExistence(timeout: 5), file: file, line: line)
        let picker = app.buttons["dishCoursePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(picker.value as? String, "Main", file: file, line: line)
        if course != "Main" {
            picker.tap()
            let option = app.buttons[course]
            XCTAssertTrue(option.waitForExistence(timeout: 5), file: file, line: line)
            option.tap()
            XCTAssertEqual(picker.value as? String, course, file: file, line: line)
        }
    }

    @MainActor
    func performDishAction(
        _ action: String, on element: XCUIElement, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        scrollTo(element, in: app, file: file, line: line)
        element.tap()
        let option = app.buttons[action]
        XCTAssertTrue(option.waitForExistence(timeout: 5), file: file, line: line)
        option.tap()
    }

    @MainActor
    func changeCourse(
        of element: XCUIElement, to course: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let identifier = element.identifier
        performDishAction("Course", on: element, in: app, file: file, line: line)
        let option = app.buttons[course]
        XCTAssertTrue(option.waitForExistence(timeout: 5), file: file, line: line)
        option.tap()
        XCTAssertTrue(component(withID: identifier, course: course, in: app).waitForExistence(timeout: 5),
                      file: file, line: line)
    }

    @MainActor
    func setPortion(
        _ quantity: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), file: file, line: line)
        field.tap()
        let existing = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        field.typeText(quantity)
        app.buttons["hideKeyboard"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), file: file, line: line)
    }

    @MainActor
    func openShoppingList(
        in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        app.tabBars.buttons["List"].tap()
        XCTAssertTrue(app.navigationBars["Shopping List"].waitForExistence(timeout: 5), file: file, line: line)
        let entry = row("apples,", in: app)
        XCTAssertTrue(entry.waitForExistence(timeout: 5), app.debugDescription, file: file, line: line)
        XCTAssertEqual(entry.value as? String, "Not checked", file: file, line: line)
        return entry
    }
}
