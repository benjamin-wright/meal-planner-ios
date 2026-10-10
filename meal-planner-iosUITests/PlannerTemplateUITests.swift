import XCTest

final class PlannerTemplateUITests: XCTestCase {
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
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
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
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    @MainActor
    private func plannedMeal(containing dish: String, in app: XCUIApplication) -> XCUIElement {
        app.collectionViews.buttons.matching(NSPredicate(format: "label CONTAINS %@", dish)).firstMatch
    }

    @MainActor
    func testChoosingALunchTemplateKeepsMondayDinnerVisibleAfterSavingAndRelaunching() {
        let app = XCUIApplication()
        app.launch()
        resetSampleData(in: app)
        defer { resetSampleData(in: app) }
        app.tabBars.buttons["Planner"].tap()
        app.segmentedControls.buttons["Dinner"].tap()

        let addMonday = app.buttons["Add dinner for Monday"]
        XCTAssertTrue(addMonday.waitForExistence(timeout: 5), app.debugDescription)
        addMonday.tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5))
        let addMain = app.buttons["Add Main dish"]
        scrollTo(addMain, in: app)
        addMain.tap()
        XCTAssertTrue(app.navigationBars["Dish"].waitForExistence(timeout: 5))
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("carrot soup")
        let recipe = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "carrot soup")).firstMatch
        XCTAssertTrue(recipe.waitForExistence(timeout: 5), app.debugDescription)
        recipe.tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5))
        let add = app.collectionViews.buttons["Add"].firstMatch
        scrollTo(add, in: app)
        add.tap()
        XCTAssertTrue(app.navigationBars["Planner"].waitForExistence(timeout: 5))

        let originalDinner = plannedMeal(containing: "carrot soup", in: app)
        XCTAssertTrue(originalDinner.waitForExistence(timeout: 5), app.debugDescription)
        originalDinner.tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5))
        app.buttons["Choose Saved Meal"].tap()
        XCTAssertTrue(app.navigationBars["Meal"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["Dinner"].isSelected)
        app.segmentedControls.buttons["Lunch"].tap()
        let lunchTemplate = app.buttons["Salmon Lunch"]
        XCTAssertTrue(lunchTemplate.waitForExistence(timeout: 5), app.debugDescription)
        lunchTemplate.tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5))
        let save = app.collectionViews.buttons["Save"].firstMatch
        scrollTo(save, in: app)
        save.tap()
        XCTAssertTrue(app.navigationBars["Planner"].waitForExistence(timeout: 5))

        let updatedDinner = plannedMeal(containing: "salmon salad", in: app)
        XCTAssertTrue(updatedDinner.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["Add dinner for Monday"].exists)
        XCTAssertFalse(originalDinner.exists)
        updatedDinner.tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        app.tabBars.buttons["Planner"].tap()
        app.segmentedControls.buttons["Dinner"].tap()
        let persistedDinner = plannedMeal(containing: "salmon salad", in: app)
        XCTAssertTrue(persistedDinner.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.buttons["Add dinner for Monday"].exists)
        persistedDinner.tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5))
    }
}
