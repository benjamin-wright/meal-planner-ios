import XCTest

final class ShoppingRegenerationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRegenerationRefreshesVisibleEntriesAndResetsCheckedState() {
        let app = XCUIApplication()
        app.launch()
        resetSampleData(in: app)
        defer { resetSampleData(in: app) }

        app.tabBars.buttons["List"].tap()
        XCTAssertTrue(app.navigationBars["Shopping List"].waitForExistence(timeout: 5))
        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "apples,")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(entry.value as? String, "Not checked")
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

    @MainActor
    private func resetSampleData(in app: XCUIApplication) {
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Reset"].tap()
        app.buttons["Yes, delete it all!"].tap()
    }
}
