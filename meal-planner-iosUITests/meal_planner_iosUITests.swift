import XCTest

final class meal_planner_iosUITests: MealPlannerUITestCase {
    @MainActor
    func testClearPlanRequiresConfirmationAndLeavesShoppingList() {
        let app = XCUIApplication()
        launchInPortrait(app)
        app.tabBars.buttons["Planner"].tap()

        let clear = app.navigationBars["Planner"].buttons["Clear Plan"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.tap()
        let cancel = app.buttons["Cancel"]
        if cancel.waitForExistence(timeout: 2) {
            cancel.tap()
        } else {
            // Native popover confirmations cancel when tapped outside their content.
            app.tabBars.buttons["Planner"].tap()
        }
        XCTAssertTrue(clear.isEnabled)
        XCTAssertFalse(app.buttons["Add dinner for Saturday"].exists)

        clear.tap()
        let clearButtons = app.buttons.matching(identifier: "Clear Plan")
        clearButtons.element(boundBy: clearButtons.count - 1).tap()
        XCTAssertFalse(clear.isEnabled)
        XCTAssertTrue(app.buttons["Add dinner for Saturday"].exists)
        app.segmentedControls.buttons["Misc"].tap()
        XCTAssertFalse(app.buttons["birthday candles"].exists)

        app.tabBars.buttons["List"].tap()
        XCTAssertTrue(app.navigationBars["Shopping List"].waitForExistence(timeout: 5))
        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "birthday candles")).firstMatch
        for _ in 0..<6 {
            if entry.exists { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
    }

}
