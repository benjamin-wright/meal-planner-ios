import XCTest

final class ShoppingListUITests: MealPlannerUITestCase {
    @MainActor
    func testCheckingCanBeCancelledAndCompletedEntriesCanBeRestored() {
        let app = XCUIApplication()
        launchInPortrait(app)

        let entry = openShoppingList(in: app)
        let originalLabel = entry.label
        let cancel = app.buttons["Cancel pending removal"]
        let undo = app.navigationBars["Shopping List"].buttons["Undo"]

        // Both UI routes to cancellation are exercised here; deadline and
        // multi-entry combinations belong to the completion workflow tests.
        entry.tap()
        XCTAssertTrue(cancel.waitForExistence(timeout: 2), app.debugDescription)
        cancel.tap()
        XCTAssertEqual(entry.value as? String, "Not checked")
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 2), app.debugDescription)
        XCTAssertFalse(undo.exists)

        entry.tap()
        XCTAssertTrue(cancel.waitForExistence(timeout: 2), app.debugDescription)
        entry.tap()
        XCTAssertEqual(entry.value as? String, "Not checked")
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 2), app.debugDescription)
        XCTAssertFalse(undo.exists)

        entry.tap()
        XCTAssertEqual(entry.value as? String, "Checked")
        XCTAssertTrue(cancel.waitForExistence(timeout: 2), app.debugDescription)

        XCTAssertTrue(entry.waitForNonExistence(timeout: 6), app.debugDescription)
        XCTAssertFalse(cancel.exists)
        XCTAssertTrue(undo.waitForExistence(timeout: 2), app.debugDescription)
        undo.tap()

        XCTAssertTrue(entry.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(entry.label, originalLabel)
        XCTAssertEqual(entry.value as? String, "Not checked")
        XCTAssertFalse(cancel.exists)
        XCTAssertFalse(undo.exists)
    }

}
