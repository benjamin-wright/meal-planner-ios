import XCTest

@MainActor
final class MealDiscoveryUITests: MealPlannerUITestCase {
    private func openMonday(in app: XCUIApplication) {
        app.tabBars.buttons["Planner"].tap()
        app.segmentedControls.buttons["Dinner"].tap()
        let add = app.buttons["Add dinner for Monday"]
        scrollTo(add, in: app, within: app.scrollViews.firstMatch)
        add.tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5))
    }

    private func choose(_ mode: String, title: String, in app: XCUIApplication) {
        let choose = app.buttons["chooseMeal"]
        scrollTo(choose, in: app)
        choose.tap()
        XCTAssertTrue(app.navigationBars["Choose a meal"].waitForExistence(timeout: 5))
        app.buttons["mealDiscovery-\(mode)"].tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
    }

    private func search(_ value: String, field identifier: String, in app: XCUIApplication) {
        let field = app.textFields[identifier]
        scrollTo(field, in: app)
        field.tap()
        // List rows can settle after scrolling back from results. Confirm the
        // keyboard is ready, and resolve the field again if the first tap missed.
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) {
            app.textFields[identifier].tap()
        }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let existing = field.value as? String ?? ""
        if existing != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        field.typeText(value)
    }

    private func selectIngredient(_ name: String, in app: XCUIApplication) {
        search(name, field: "mealIngredientSearch", in: app)
        let ingredient = app.buttons["mealIngredient-\(name)"]
        XCTAssertTrue(ingredient.waitForExistence(timeout: 5))
        ingredient.tap()
        XCTAssertTrue(app.buttons["Remove \(name) filter"].waitForExistence(timeout: 5))
    }

    private func addRecipe(_ name: String, course: String = "Main", in app: XCUIApplication) {
        openDishPicker(course: course, in: app)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name)
        let recipe = row(name, in: app)
        XCTAssertTrue(recipe.waitForExistence(timeout: 5))
        recipe.tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5))
    }

    private func commitMonday(in app: XCUIApplication) {
        let add = app.collectionViews.buttons["Add"].firstMatch
        scrollTo(add, in: app)
        XCTAssertTrue(add.isEnabled)
        add.tap()
        XCTAssertTrue(app.navigationBars["Planner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["plannedDinner-Monday"].waitForExistence(timeout: 5))
    }

    func testIngredientTagsCombineWithDietaryFiltersAndClear() {
        let app = XCUIApplication()
        launchInPortrait(app)
        openMonday(in: app)
        choose("ingredient", title: "By ingredient", in: app)

        selectIngredient("rosemary", in: app)
        let chicken = app.buttons["useMeal-roast chicken"]
        scrollTo(chicken, in: app)
        XCTAssertTrue(chicken.exists)

        let vegetarian = app.buttons["mealFilterVegetarian"]
        // Return from the results before tapping a filter near the navigation bar.
        app.collectionViews.firstMatch.swipeDown()
        scrollTo(vegetarian, in: app)
        vegetarian.tap()
        XCTAssertTrue(vegetarian.isSelected)
        let soup = app.buttons["useMeal-carrot soup"]
        scrollTo(soup, in: app)
        XCTAssertTrue(soup.exists)
        XCTAssertFalse(chicken.exists)
        XCTAssertFalse(app.buttons["useMeal-Roast Chicken Dinner"].exists)

        // No vegetarian meal in the fixture contains both rosemary and apples.
        selectIngredient("apples", in: app)
        let empty = app.staticTexts["No matching meal ideas"]
        scrollTo(empty, in: app)
        XCTAssertTrue(empty.exists)
        XCTAssertFalse(soup.exists)

        let clear = app.buttons["clearMealFilters"]
        scrollTo(clear, in: app)
        clear.tap()
        XCTAssertFalse(app.buttons["Remove rosemary filter"].exists)
        XCTAssertFalse(app.buttons["Remove apples filter"].exists)
        XCTAssertFalse(app.buttons["mealFilterVegetarian"].isSelected)
        let prompt = app.staticTexts["Choose an ingredient above to see meal ideas."]
        scrollTo(prompt, in: app)
        XCTAssertTrue(prompt.exists)
    }

    func testNamePreviewAndMealSelectionStayUncommitted() {
        let app = XCUIApplication()
        launchInPortrait(app)
        openMonday(in: app)
        choose("name", title: "By name", in: app)
        search("carrot soup", field: "mealNameSearch", in: app)

        let preview = app.buttons["previewMeal-carrot soup"]
        scrollTo(preview, in: app)
        preview.tap()
        XCTAssertTrue(app.navigationBars["Meal preview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["For 2 people · Recipe"].exists)
        row("carrot soup", in: app).tap()
        XCTAssertTrue(app.navigationBars["carrot soup"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["A warming carrot and rosemary soup"].exists)
        let onionQuantity = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
            "recipePreviewIngredient-", "onions"
        )).firstMatch
        XCTAssertTrue(onionQuantity.waitForExistence(timeout: 5))
        XCTAssertTrue(onionQuantity.label.contains("40g"), onionQuantity.label)
        XCTAssertFalse(app.buttons["saveRecipe"].exists)
        XCTAssertFalse(app.buttons["savePlannedRecipe"].exists)

        app.navigationBars["carrot soup"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Meal preview"].waitForExistence(timeout: 5))
        app.navigationBars["Meal preview"].buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["By name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["mealNameSearch"].value as? String, "carrot soup")
        let use = app.buttons["useMeal-carrot soup"]
        scrollTo(use, in: app)
        use.tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5))
        XCTAssertTrue(component("carrot soup", course: "Main", in: app).exists)

        // Leaving the draft discards selection and must not produce learned history.
        app.navigationBars["Monday Dinner"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Planner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add dinner for Monday"].exists)
        XCTAssertFalse(app.staticTexts["plannedDinner-Monday"].exists)
        openMonday(in: app)
        choose("name", title: "By name", in: app)
        search("carrot soup", field: "mealNameSearch", in: app)
        scrollTo(app.buttons["previewMeal-carrot soup"], in: app)
        app.buttons["previewMeal-carrot soup"].tap()
        XCTAssertTrue(app.navigationBars["Meal preview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["For 2 people · Recipe"].exists)
        XCTAssertFalse(app.staticTexts["For 2 people · Previously planned"].exists)
    }

    func testPescatarianMealsIncludeFishAndVegetablesButExcludeMeat() {
        let app = XCUIApplication()
        launchInPortrait(app)
        openMonday(in: app)
        choose("ingredient", title: "By ingredient", in: app)
        selectIngredient("apples", in: app)

        let vegetarian = app.buttons["mealFilterVegetarian"]
        scrollTo(vegetarian, in: app)
        vegetarian.tap()
        XCTAssertFalse(app.buttons["useMeal-salmon salad"].exists)

        let pescatarian = app.buttons["mealFilterPescetarian"]
        scrollTo(pescatarian, in: app)
        pescatarian.tap()
        XCTAssertTrue(pescatarian.isSelected)
        XCTAssertFalse(vegetarian.isSelected)
        let fish = app.buttons["useMeal-salmon salad"]
        scrollTo(fish, in: app)
        XCTAssertTrue(fish.exists)
        XCTAssertFalse(app.buttons["useMeal-Roast Chicken Dinner"].exists)
        let vegetable = app.buttons["useMeal-breakfast loaf"]
        scrollTo(vegetable, in: app)
        XCTAssertTrue(vegetable.exists)

        app.buttons["mealDiscoveryBack"].tap()
        app.buttons["mealDiscovery-suggest"].tap()
        let retained = app.buttons["mealFilterPescetarian"]
        scrollTo(retained, in: app)
        XCTAssertTrue(retained.isSelected)
        XCTAssertTrue(app.buttons["Remove apples filter"].exists)
        let clear = app.buttons["clearMealFilters"]
        scrollTo(clear, in: app)
        clear.tap()
        XCTAssertFalse(retained.isSelected)
        XCTAssertFalse(app.buttons["Remove apples filter"].exists)
    }

    func testDishPickerPescatarianFilterAllowsFishWhenSwitchingFromVegetarian() {
        let app = XCUIApplication()
        launchInPortrait(app)
        openMonday(in: app)
        openDishPicker(in: app)
        let vegetarian = app.descendants(matching: .any).matching(identifier: "dishVegetarianFilter").firstMatch
        XCTAssertTrue(vegetarian.waitForExistence(timeout: 5))
        vegetarian.tap()
        XCTAssertFalse(row("salmon salad", in: app).exists)

        let pescatarian = app.descendants(matching: .any).matching(identifier: "dishPescetarianFilter").firstMatch
        if !pescatarian.isHittable { app.scrollViews["dishDietaryFilters"].swipeLeft() }
        XCTAssertTrue(pescatarian.isHittable)
        pescatarian.tap()
        let fish = row("salmon salad", in: app)
        scrollTo(fish, in: app)
        XCTAssertTrue(fish.exists)
        XCTAssertTrue(row("carrot soup", in: app).exists)
        XCTAssertFalse(row("roast chicken", in: app).exists)
        fish.tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5))
        XCTAssertTrue(component("salmon salad", course: "Main", in: app).exists)
    }

    func testCommittedCombinationSurvivesClearAndRelaunch() {
        let app = XCUIApplication()
        launchInPortrait(app)
        openMonday(in: app)
        addRecipe("carrot soup", in: app)
        addRecipe("mashed potatoes", course: "Side", in: app)
        commitMonday(in: app)
        XCTAssertEqual(app.staticTexts["plannedDinner-Monday"].label, "carrot soup, mashed potatoes")

        app.navigationBars["Planner"].buttons["Clear Plan"].tap()
        let clearButtons = app.buttons.matching(identifier: "Clear Plan")
        clearButtons.element(boundBy: clearButtons.count - 1).tap()
        XCTAssertTrue(app.buttons["Add dinner for Monday"].waitForExistence(timeout: 5))
        app.terminate()
        launchInPortrait(app)
        openMonday(in: app)
        choose("name", title: "By name", in: app)
        search("carrot soup, mashed potatoes", field: "mealNameSearch", in: app)
        let preview = app.buttons["previewMeal-carrot soup, mashed potatoes"]
        scrollTo(preview, in: app)
        preview.tap()
        XCTAssertTrue(app.navigationBars["Meal preview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["For 2 people · Previously planned"].exists)
        let use = app.buttons["usePreviewedMeal"]
        scrollTo(use, in: app)
        use.tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5))
        XCTAssertTrue(component("carrot soup", course: "Main", in: app).exists)
        XCTAssertTrue(component("mashed potatoes", course: "Side", in: app).exists)
        commitMonday(in: app)
    }

    func testSuggestionsAvoidPlannedMainsAndReplacementPreservesCourse() {
        let app = XCUIApplication()
        launchInPortrait(app)
        openMonday(in: app)
        choose("suggest", title: "Suggest", in: app)

        let options = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "useMeal-"))
        XCTAssertTrue(options.firstMatch.waitForExistence(timeout: 5))
        var identifiers = Set<String>()
        let more = app.buttons["moreMealSuggestions"]
        for _ in 0..<5 {
            let visibleIDs = options.allElementsBoundByIndex.map(\.identifier)
            XCTAssertEqual(visibleIDs.count, Set(visibleIDs).count, "A suggestion must appear only once")
            identifiers.formUnion(visibleIDs)
            if more.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        // Every other main in the sample catalogue is already in the plan.
        // Don't fill three slots by stripping the sides from Roast Chicken Dinner.
        XCTAssertEqual(identifiers, Set(["useMeal-carrot soup"]))
        XCTAssertFalse(more.isEnabled)
        XCTAssertFalse(identifiers.contains("useMeal-mashed potatoes"), "A learned side is not a complete meal")
        XCTAssertFalse(identifiers.contains("useMeal-apple crumble"), "A learned dessert is not a complete meal")

        let selected = app.buttons[identifiers.sorted().first!]
        scrollTo(selected, in: app)
        selected.tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5))
        let dish = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "mealComponent-")).firstMatch
        XCTAssertTrue(dish.waitForExistence(timeout: 5))
        let componentID = dish.identifier
        changeCourse(of: dish, to: "Side", in: app)
        performDishAction("Replace Dish", on: component(withID: componentID, course: "Side", in: app), in: app)
        XCTAssertTrue(app.navigationBars["Dish"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["dishCoursePicker"].value as? String, "Side")
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("mashed potatoes")
        row("mashed potatoes", in: app).tap()
        XCTAssertTrue(app.navigationBars["Monday Dinner"].waitForExistence(timeout: 5))
        let replacement = component(withID: componentID, course: "Side", in: app)
        XCTAssertTrue(replacement.exists)
        XCTAssertTrue(replacement.label.contains("mashed potatoes"), replacement.label)
    }
}
