import XCTest

final class ShoppingListUITests: MealPlannerUITestCase {
    @MainActor
    func testCheckedEntryIsRemovedAndUndoRestoresItUnchecked() {
        let app = XCUIApplication()
        launchInPortrait(app)
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
        assertCancellationKeepsEntry { _, cancel in cancel.tap() }
    }

    @MainActor
    func testUncheckingEntryBeforeDeadlineCancelsRemoval() {
        assertCancellationKeepsEntry { entry, _ in entry.tap() }
    }

    @MainActor
    private func assertCancellationKeepsEntry(
        file: StaticString = #filePath, line: UInt = #line,
        cancelRemoval: (XCUIElement, XCUIElement) -> Void
    ) {
        let app = XCUIApplication()
        launchInPortrait(app)
        resetSampleData(in: app)
        defer { resetSampleData(in: app) }

        let entry = openShoppingList(in: app, file: file, line: line)
        let cancel = app.buttons["Cancel pending removal"]
        entry.tap()
        XCTAssertEqual(entry.value as? String, "Checked", file: file, line: line)
        XCTAssertTrue(cancel.exists || cancel.waitForExistence(timeout: 2), app.debugDescription, file: file, line: line)
        cancelRemoval(entry, cancel)

        XCTAssertEqual(entry.value as? String, "Not checked", file: file, line: line)
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 2), app.debugDescription, file: file, line: line)
        XCTAssertFalse(entry.waitForNonExistence(timeout: 4), app.debugDescription, file: file, line: line)
        XCTAssertEqual(entry.value as? String, "Not checked", file: file, line: line)
        XCTAssertFalse(app.navigationBars["Shopping List"].buttons["Undo"].exists, file: file, line: line)
    }
}
