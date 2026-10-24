import XCTest

final class ShoppingRegenerationUITests: MealPlannerUITestCase {
    @MainActor
    func testRegenerationRefreshesVisibleEntriesAndResetsCheckedState() {
        let app = XCUIApplication()
        launchInPortrait(app)

        let entry = openShoppingList(in: app)
        entry.tap()
        XCTAssertEqual(entry.value as? String, "Checked")

        app.navigationBars["Shopping List"].buttons["Regenerate"].tap()
        let confirmation = app.buttons["Regenerate List"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.tap()

        let refreshed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Not checked"), object: entry
        )
        XCTAssertEqual(XCTWaiter.wait(for: [refreshed], timeout: 5), .completed, app.debugDescription)
        XCTAssertFalse(app.buttons["Cancel pending removal"].exists)
        XCTAssertFalse(app.alerts["Shopping List"].exists)

        // Rows from the isolated save must still be editable through the shared context.
        entry.tap()
        XCTAssertEqual(entry.value as? String, "Checked")
        app.buttons["Cancel pending removal"].tap()
        XCTAssertEqual(entry.value as? String, "Not checked")
    }
}
