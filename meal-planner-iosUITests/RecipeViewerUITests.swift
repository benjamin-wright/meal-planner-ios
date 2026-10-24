import XCTest

@MainActor
final class RecipeViewerUITests: MealPlannerUITestCase {
    func testRecipeTabsIngredientsAndStepsInFullScreenViewer() {
        let app = XCUIApplication()
        launchInPortrait(app)
        app.tabBars.buttons["Planner"].tap()

        openViewer(in: app)

        XCTContext.runActivity(named: "The viewer covers the app tabs and shows stored recipe details") { _ in
            for tab in ["Data", "Planner", "List", "Settings"] {
                XCTAssertFalse(app.tabBars.buttons[tab].isHittable)
            }
            XCTAssertEqual(element("recipeViewerName", in: app).label, "roast chicken")
            XCTAssertEqual(element("recipeViewerServings", in: app).value as? String, "4")
            XCTAssertEqual(element("recipeViewerTime", in: app).value as? String, "60 minutes")
            XCTAssertTrue(app.staticTexts["Rosemary roast chicken"].exists)
            XCTAssertEqual(recipeTabs(in: app).count, 3)
            attachScreenshot("Recipe viewer - Summary", in: app)
        }

        XCTContext.runActivity(named: "Gathered ingredients belong to each recipe and survive tab switches") { _ in
            selectSection("Ingredients", in: app)
            let chicken = ingredient("chicken thighs", in: app)
            XCTAssertTrue(chicken.waitForExistence(timeout: 5))
            XCTAssertEqual(chicken.label, "chicken thighs, 2")
            XCTAssertEqual(chicken.value as? String, "Not gathered")
            chicken.tap()
            XCTAssertEqual(chicken.value as? String, "Gathered")
            attachScreenshot("Recipe viewer - Ingredients", in: app)

            selectRecipe("mashed potatoes", in: app)
            let potatoes = ingredient("potatoes", in: app)
            XCTAssertTrue(potatoes.waitForExistence(timeout: 5))
            XCTAssertEqual(potatoes.value as? String, "Not gathered")
            potatoes.tap()

            selectRecipe("apple crumble", in: app)
            let apples = ingredient("apples", in: app)
            XCTAssertTrue(apples.waitForExistence(timeout: 5))
            XCTAssertEqual(apples.value as? String, "Not gathered")

            selectRecipe("roast chicken", in: app)
            XCTAssertEqual(ingredient("chicken thighs", in: app).value as? String, "Gathered")
            selectRecipe("mashed potatoes", in: app)
            XCTAssertEqual(ingredient("potatoes", in: app).value as? String, "Gathered")
        }

        XCTContext.runActivity(named: "Steps use the stored text and the selected section follows the recipe") { _ in
            selectSection("Steps", in: app)
            XCTAssertTrue(app.scrollViews["recipeViewerContent"].exists)
            XCTAssertTrue(element("recipeViewerStep-1", in: app).label.contains("Boil the potatoes."))
            XCTAssertTrue(element("recipeViewerStep-2", in: app).label.contains("Mash with the milk."))
            attachScreenshot("Recipe viewer - Steps", in: app)

            selectRecipe("apple crumble", in: app)
            XCTAssertTrue(element("recipeViewerStep-1", in: app).label.contains("Top the sliced apples with crumble."))
            XCTAssertTrue(element("recipeViewerStep-2", in: app).label.contains("Bake until crisp."))
        }

        XCTContext.runActivity(named: "Closing restores Planner and reopening starts a fresh gathering session") { _ in
            closeViewer(in: app)
            XCTAssertTrue(app.tabBars.buttons["Planner"].isSelected)
            for tab in ["Data", "Planner", "List", "Settings"] {
                XCTAssertTrue(app.tabBars.buttons[tab].isHittable)
            }

            openViewer(in: app)
            selectSection("Ingredients", in: app)
            XCTAssertEqual(ingredient("chicken thighs", in: app).value as? String, "Not gathered")
            selectRecipe("mashed potatoes", in: app)
            XCTAssertEqual(ingredient("potatoes", in: app).value as? String, "Not gathered")
            closeViewer(in: app)
        }
    }

    func testViewerUsesPlannedServingsAndIngredientSubstitutions() {
        let app = XCUIApplication()
        launchInPortrait(app)
        app.tabBars.buttons["Planner"].tap()
        app.buttons["plannedDinnerActions-Saturday"].tap()
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars["Saturday Dinner"].waitForExistence(timeout: 5))

        XCTContext.runActivity(named: "Plan two servings and substitute carrots for chicken") { _ in
            let decreaseServings = app.buttons.matching(NSPredicate(
                format: "label ENDSWITH %@", "Decrease Servings"
            )).firstMatch
            XCTAssertTrue(decreaseServings.waitForExistence(timeout: 5))
            decreaseServings.tap()
            decreaseServings.tap()

            performDishAction("Substitute Ingredients", on: component("roast chicken", course: "Main", in: app), in: app)
            XCTAssertTrue(app.navigationBars["Planned Recipe"].waitForExistence(timeout: 5))
            let chicken = app.buttons.matching(NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "plannedRecipeIngredient-", "chicken thighs"
            )).firstMatch
            XCTAssertTrue(chicken.waitForExistence(timeout: 5))
            chicken.tap()
            XCTAssertTrue(app.navigationBars["Ingredient"].waitForExistence(timeout: 5))
            setPortion("6", in: app)
            row("Item", in: app).tap()
            XCTAssertTrue(app.navigationBars["Item"].waitForExistence(timeout: 5))
            let search = app.searchFields.firstMatch
            search.tap()
            search.typeText("carrots")
            let carrots = row("carrots", in: app)
            XCTAssertTrue(carrots.waitForExistence(timeout: 5))
            carrots.tap()
            XCTAssertTrue(app.navigationBars["Ingredient"].waitForExistence(timeout: 5))

            save(app.collectionViews.buttons["Save"].firstMatch, returningTo: "Planned Recipe", in: app)
            save(app.buttons["savePlannedRecipe"], returningTo: "Saturday Dinner", in: app)
            save(app.collectionViews.buttons["Save"].firstMatch, returningTo: "Planner", in: app)
        }

        XCTContext.runActivity(named: "The viewer uses the planned recipe and scales its ingredients") { _ in
            openViewer(in: app)
            XCTAssertEqual(element("recipeViewerName", in: app).label, "roast chicken")
            XCTAssertTrue(app.staticTexts["Includes your ingredient substitutions"].exists)
            XCTAssertTrue(recipeTabs(in: app).matching(NSPredicate(format: "label == %@", "roast chicken*")).firstMatch.isSelected)
            XCTAssertEqual(element("recipeViewerServings", in: app).value as? String, "2")
            XCTAssertEqual(element("recipeViewerTime", in: app).value as? String, "60 minutes")
            selectSection("Ingredients", in: app)
            XCTAssertEqual(ingredient("carrots", in: app).label, "carrots, 3")
            XCTAssertEqual(ingredient("rosemary", in: app).label, "rosemary, 2.5g")
            XCTAssertFalse(ingredient("chicken thighs", in: app).exists)
            closeViewer(in: app)
        }
    }

    func testLunchAndBreakfastMenusOpenViewerAndPreserveEditing() {
        let app = XCUIApplication()
        launchInPortrait(app)
        app.tabBars.buttons["Planner"].tap()

        for (section, recipe) in [("Lunch", "salmon salad"), ("Breakfast", "breakfast loaf")] {
            XCTContext.runActivity(named: "View and edit \(section.lowercased()) independently") { _ in
                app.segmentedControls.buttons[section].tap()
                let actions = app.buttons.matching(NSPredicate(
                    format: "identifier BEGINSWITH %@", "plannedMealActions-"
                )).firstMatch
                XCTAssertTrue(actions.waitForExistence(timeout: 5))
                actions.tap()
                let view = app.buttons["View"]
                XCTAssertTrue(view.waitForExistence(timeout: 5))
                XCTAssertFalse(app.navigationBars[section].exists)
                view.tap()
                XCTAssertTrue(app.buttons["closeRecipeViewer"].waitForExistence(timeout: 5))
                XCTAssertEqual(element("recipeViewerName", in: app).label, recipe)
                XCTAssertEqual(recipeTabs(in: app).count, 1)

                closeViewer(in: app)
                XCTAssertTrue(app.segmentedControls.buttons[section].isSelected)
                XCTAssertTrue(app.tabBars.buttons["Planner"].isSelected)
                XCTAssertTrue(actions.isHittable)

                let meal = row(recipe, in: app)
                XCTAssertTrue(meal.isHittable)
                meal.tap()
                XCTAssertTrue(app.navigationBars[section].waitForExistence(timeout: 5))
                app.navigationBars[section].buttons.element(boundBy: 0).tap()
                XCTAssertTrue(app.navigationBars["Planner"].waitForExistence(timeout: 5))
                XCTAssertTrue(app.segmentedControls.buttons[section].isSelected)
            }
        }
    }

    func testLongStepsScrollWhileRecipeAndSectionControlsStayVisible() {
        let app = XCUIApplication()
        launchInPortrait(app, fixture: .recipeViewer)
        app.tabBars.buttons["Planner"].tap()
        openViewer(in: app)
        selectSection("Steps", in: app)

        let firstStep = element("recipeViewerStep-1", in: app)
        let lastStep = element("recipeViewerStep-15", in: app)
        XCTAssertTrue(firstStep.isHittable)
        XCTAssertFalse(lastStep.isHittable)
        let recipeTab = recipeTabs(in: app).matching(NSPredicate(format: "label == %@", "roast chicken")).firstMatch
        let recipeTabY = recipeTab.frame.midY
        let sectionsY = app.buttons["recipeViewerSection-Steps"].frame.midY
        let content = app.scrollViews["recipeViewerContent"]
        for _ in 0..<15 {
            if lastStep.isHittable { break }
            content.swipeUp()
        }

        XCTAssertTrue(lastStep.isHittable)
        XCTAssertTrue(lastStep.label.contains("Test instruction 15."))
        XCTAssertFalse(firstStep.isHittable)
        XCTAssertTrue(app.buttons["closeRecipeViewer"].isHittable)
        XCTAssertTrue(recipeTab.isHittable)
        XCTAssertEqual(recipeTab.frame.midY, recipeTabY, accuracy: 1)
        for section in ["Summary", "Ingredients", "Steps"] {
            XCTAssertTrue(app.buttons["recipeViewerSection-\(section)"].isHittable)
        }
        XCTAssertEqual(app.buttons["recipeViewerSection-Steps"].frame.midY, sectionsY, accuracy: 1)
        attachScreenshot("Recipe viewer - Scrolled steps", in: app)

        selectRecipe("mashed potatoes", in: app)
        selectRecipe("roast chicken", in: app)
        XCTAssertTrue(firstStep.isHittable)
        XCTAssertFalse(lastStep.isHittable)
        closeViewer(in: app)
    }

    func testLandscapeShowsScrollableStepsAndControls() {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        launch(app, fixture: .recipeViewer)
        app.tabBars.buttons["Planner"].tap()
        openViewer(in: app)
        selectSection("Steps", in: app)

        XCTAssertTrue(app.buttons["closeRecipeViewer"].isHittable)
        XCTAssertGreaterThan(app.frame.width, app.frame.height)
        for section in ["Summary", "Ingredients", "Steps"] {
            XCTAssertTrue(app.buttons["recipeViewerSection-\(section)"].isHittable)
        }

        let content = app.scrollViews["recipeViewerContent"]
        let lastStep = element("recipeViewerStep-15", in: app)
        for _ in 0..<25 {
            if lastStep.isHittable { break }
            let frame = content.frame
            let footerTop = app.buttons["recipeViewerSection-Steps"].frame.minY
            let origin = content.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(
                dx: frame.width / 2,
                dy: min(frame.maxY, footerTop - 16) - frame.minY
            ))
            let end = origin.withOffset(CGVector(dx: frame.width / 2, dy: 20))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(lastStep.isHittable)
        XCTAssertTrue(lastStep.label.contains("Test instruction 15."))
        XCTAssertTrue(app.buttons["closeRecipeViewer"].isHittable)
        for section in ["Summary", "Ingredients", "Steps"] {
            XCTAssertTrue(app.buttons["recipeViewerSection-\(section)"].isHittable)
        }
        attachScreenshot("Recipe viewer - Landscape scrolled steps", in: app)

        closeViewer(in: app)
        XCTAssertTrue(app.tabBars.buttons["Planner"].isSelected)
    }

    func testAccessibilityTextSizeKeepsSelectedRecipeTabVisible() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launchInPortrait(app)
        app.tabBars.buttons["Planner"].tap()
        openViewer(in: app)

        selectRecipe("apple crumble", in: app)
        let selectedRecipe = recipeTabs(in: app).matching(NSPredicate(
            format: "label == %@", "apple crumble"
        )).firstMatch
        XCTAssertTrue(selectedRecipe.isSelected)
        XCTAssertTrue(selectedRecipe.isHittable)

        let steps = app.buttons["recipeViewerSection-Steps"]
        let sections = app.scrollViews["recipeViewerSections"]
        XCTAssertTrue(sections.waitForExistence(timeout: 5))
        for _ in 0..<3 {
            if isHittable(steps, within: sections) { break }
            sections.swipeLeft()
        }
        XCTAssertTrue(isHittable(steps, within: sections))
        steps.tap()
        XCTAssertTrue(steps.isSelected)
        XCTAssertTrue(steps.isHittable)
        XCTAssertTrue(selectedRecipe.isSelected)
        XCTAssertTrue(selectedRecipe.isHittable)
        attachScreenshot("Recipe viewer - Accessibility selected recipe", in: app)

        let firstStep = element("recipeViewerStep-1", in: app)
        scrollTo(firstStep, in: app, within: app.scrollViews["recipeViewerContent"])
        XCTAssertTrue(firstStep.label.contains("Top the sliced apples with crumble."))
        XCTAssertTrue(app.buttons["closeRecipeViewer"].isHittable)
        closeViewer(in: app)
        XCTAssertTrue(app.tabBars.buttons["Planner"].isSelected)
    }

    private func openViewer(
        in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        let actions = app.buttons["plannedDinnerActions-Saturday"]
        XCTAssertTrue(actions.waitForExistence(timeout: 5), file: file, line: line)
        actions.tap()
        let view = app.buttons["View"]
        XCTAssertTrue(view.waitForExistence(timeout: 5), file: file, line: line)
        view.tap()
        XCTAssertTrue(app.buttons["closeRecipeViewer"].waitForExistence(timeout: 5), file: file, line: line)
    }

    private func closeViewer(
        in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) {
        app.buttons["closeRecipeViewer"].tap()
        XCTAssertTrue(app.buttons["closeRecipeViewer"].waitForNonExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(app.navigationBars["Planner"].waitForExistence(timeout: 5), file: file, line: line)
    }

    private func save(
        _ button: XCUIElement, returningTo title: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        scrollTo(button, in: app, file: file, line: line)
        button.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), file: file, line: line)
    }

    private func attachScreenshot(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func recipeTabs(in app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipeViewerTab-"))
    }

    private func isHittable(_ element: XCUIElement, within strip: XCUIElement) -> Bool {
        let frame = element.frame
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return strip.frame.contains(center) && element.isHittable
    }

    private func selectRecipe(
        _ name: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let tab = recipeTabs(in: app).matching(NSPredicate(format: "label == %@", name)).firstMatch
        let tabs = app.scrollViews["recipeViewerTabs"]
        for _ in 0..<3 {
            if isHittable(tab, within: tabs) { break }
            tabs.swipeLeft()
        }
        for _ in 0..<3 {
            if isHittable(tab, within: tabs) { break }
            tabs.swipeRight()
        }
        XCTAssertTrue(isHittable(tab, within: tabs), app.debugDescription, file: file, line: line)
        tab.tap()
    }

    private func selectSection(
        _ section: String, in app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let button = app.buttons["recipeViewerSection-\(section)"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), file: file, line: line)
        button.tap()
    }

    private func ingredient(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@",
            "recipeViewerIngredient-", "\(name),"
        )).firstMatch
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
