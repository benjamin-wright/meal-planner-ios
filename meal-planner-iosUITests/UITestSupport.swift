import XCTest

class MealPlannerUITestCase: XCTestCase {
    enum Fixture: String {
        case sample
        case longMeal = "long-meal"
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
        file: StaticString = #filePath, line: UInt = #line
    ) {
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
