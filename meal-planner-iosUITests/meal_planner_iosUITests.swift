//
//  meal_planner_iosUITests.swift
//  meal-planner-iosUITests
//
//  Created by Benjamin Wright on 09/09/2025.
//

import XCTest

final class meal_planner_iosUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testClearPlanRequiresConfirmationAndLeavesShoppingList() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Planner"].tap()

        let clear = app.navigationBars["Planner"].buttons["Clear Plan"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.tap()
        XCTAssertTrue(app.buttons["Clear Plan"].count >= 2)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(clear.isEnabled)

        clear.tap()
        app.buttons["Clear Plan"].lastMatch.tap()
        XCTAssertFalse(clear.isEnabled)
        XCTAssertTrue(app.buttons["Add dinner for Saturday"].exists)
        app.segmentedControls.buttons["Misc"].tap()
        XCTAssertFalse(app.buttons["birthday candles"].exists)

        app.tabBars.buttons["List"].tap()
        XCTAssertTrue(app.navigationBars["Shopping List"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["birthday candles"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
