import XCTest

final class ShoppingListUITests: MealPlannerUITestCase {
    @MainActor
    func testShoppingListRegenerationCompletionUndoAndPlanClearing() {
        let app = XCUIApplication()
        launchInPortrait(app, fixture: .staleShoppingList)

        XCTContext.runActivity(named: "Regenerate a stale shopping list") { _ in
            app.tabBars.buttons["List"].tap()
            XCTAssertTrue(app.navigationBars["Shopping List"].waitForExistence(timeout: 5))
            let previous = row("previous shopping entry", in: app)
            XCTAssertTrue(previous.waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertFalse(row("apples,", in: app).exists)

            app.navigationBars["Shopping List"].buttons["Regenerate"].tap()
            let confirmation = app.buttons["Regenerate List"]
            XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
            confirmation.tap()

            XCTAssertTrue(previous.waitForNonExistence(timeout: 5), app.debugDescription)
            let regenerated = row("apples,", in: app)
            XCTAssertTrue(regenerated.waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertEqual(regenerated.value as? String, "Not checked")
            XCTAssertFalse(app.buttons["Cancel pending removal"].exists)
            XCTAssertFalse(app.alerts["Shopping List"].exists)
        }

        XCTContext.runActivity(named: "Complete an entry and restore it with Undo") { _ in
            let entry = row("apples,", in: app)
            let originalLabel = entry.label
            let undo = app.navigationBars["Shopping List"].buttons["Undo"]

            // Wait for the stable result. Cancellation and deadline permutations
            // use the manual clock in ShoppingListCompletionTests.
            entry.tap()
            XCTAssertTrue(entry.waitForNonExistence(timeout: 10), app.debugDescription)
            XCTAssertTrue(undo.waitForExistence(timeout: 5), app.debugDescription)
            undo.tap()

            XCTAssertTrue(entry.waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertEqual(entry.label, originalLabel)
            XCTAssertEqual(entry.value as? String, "Not checked")
            XCTAssertFalse(app.buttons["Cancel pending removal"].exists)
            XCTAssertFalse(undo.exists)
        }

        XCTContext.runActivity(named: "Cancel plan clearing, then confirm it") { _ in
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
            let cleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"), object: clear)
            XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 5), .completed)
            XCTAssertTrue(app.buttons["Add dinner for Saturday"].waitForExistence(timeout: 5))
            app.segmentedControls.buttons["Misc"].tap()
            XCTAssertFalse(app.buttons["birthday candles"].exists)
        }

        XCTContext.runActivity(named: "Keep the generated shopping list after clearing the plan") { _ in
            app.tabBars.buttons["List"].tap()
            XCTAssertTrue(app.navigationBars["Shopping List"].waitForExistence(timeout: 5))
            let entry = row("birthday candles", in: app)
            for _ in 0..<6 {
                if entry.exists { break }
                app.collectionViews.firstMatch.swipeUp()
            }
            XCTAssertTrue(entry.waitForExistence(timeout: 5))
        }
    }
}
