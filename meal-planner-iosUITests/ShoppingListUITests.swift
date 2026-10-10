import XCTest

final class ShoppingListUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func resetSampleData(in app: XCUIApplication) {
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Reset"].tap()
        app.buttons["Yes, delete it all!"].tap()
    }

    @MainActor
    private func openShoppingList(in app: XCUIApplication) -> XCUIElement {
        app.tabBars.buttons["List"].tap()
        XCTAssertTrue(app.navigationBars["Shopping List"].waitForExistence(timeout: 5))
        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "apples,")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(entry.value as? String, "Not checked")
        return entry
    }

    @MainActor
    func testCheckedEntryIsRemovedAndUndoRestoresItUnchecked() {
        let app = XCUIApplication()
        app.launch()
        resetSampleData(in: app)
        defer { resetSampleData(in: app) }

        let entry = openShoppingList(in: app)
        let originalLabel = entry.label
        let cancel = app.buttons["Cancel pending removal"]
        entry.tap()
        XCTAssertEqual(entry.value as? String, "Checked")
        XCTAssertTrue(cancel.waitForExistence(timeout: 2), app.debugDescription)

        XCTAssertTrue(entry.waitForNonExistence(timeout: 6), app.debugDescription)
        XCTAssertFalse(cancel.exists)
        let undo = app.navigationBars["Shopping List"].buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2), app.debugDescription)
        undo.tap()

        XCTAssertTrue(entry.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(entry.label, originalLabel)
        XCTAssertEqual(entry.value as? String, "Not checked")
        XCTAssertFalse(cancel.exists)
        XCTAssertFalse(undo.exists)
    }

    @MainActor
    func testCancellingPendingRemovalKeepsEntryUncheckedAfterDeadline() {
        let app = XCUIApplication()
        app.launch()
        resetSampleData(in: app)
        defer { resetSampleData(in: app) }

        let entry = openShoppingList(in: app)
        let cancel = app.buttons["Cancel pending removal"]
        entry.tap()
        XCTAssertEqual(entry.value as? String, "Checked")
        XCTAssertTrue(cancel.waitForExistence(timeout: 2), app.debugDescription)
        cancel.tap()

        XCTAssertEqual(entry.value as? String, "Not checked")
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 2), app.debugDescription)
        XCTAssertFalse(entry.waitForNonExistence(timeout: 4), app.debugDescription)
        XCTAssertEqual(entry.value as? String, "Not checked")
        XCTAssertFalse(app.navigationBars["Shopping List"].buttons["Undo"].exists)
    }

    @MainActor
    func testUncheckingEntryBeforeDeadlineCancelsRemoval() {
        let app = XCUIApplication()
        app.launch()
        resetSampleData(in: app)
        defer { resetSampleData(in: app) }

        let entry = openShoppingList(in: app)
        let cancel = app.buttons["Cancel pending removal"]
        entry.tap()
        XCTAssertEqual(entry.value as? String, "Checked")
        XCTAssertTrue(cancel.waitForExistence(timeout: 2), app.debugDescription)
        entry.tap()

        XCTAssertEqual(entry.value as? String, "Not checked")
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 2), app.debugDescription)
        XCTAssertFalse(entry.waitForNonExistence(timeout: 4), app.debugDescription)
        XCTAssertEqual(entry.value as? String, "Not checked")
        XCTAssertFalse(app.navigationBars["Shopping List"].buttons["Undo"].exists)
    }
}
