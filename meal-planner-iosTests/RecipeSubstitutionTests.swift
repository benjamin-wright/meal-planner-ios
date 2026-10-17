import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct RecipeSubstitutionTests {
    @Test func overridesAreSparseAndKeyedByIngredientRatherThanItem() throws {
        let fixture = try makeFixture()
        var draft = MealComponentDraft(source: .recipe(fixture.recipe.id))
        let original = RecipieIngredientDraft(ingredient: fixture.firstIngredient)
        #expect(draft.ingredientOverrides.isEmpty)
        #expect(draft.ingredients(for: fixture.recipe) == fixture.recipe.ingredients.map {
            RecipieIngredientDraft(ingredient: $0)
        })
        draft.updateIngredient(original, in: fixture.recipe)
        #expect(draft.ingredientOverrides.isEmpty)

        var changed = original
        changed.itemID = fixture.substitute.id
        changed.unitID = fixture.kilograms.id
        changed.quantity = 0.2
        draft.updateIngredient(changed, in: fixture.recipe)
        let override = try #require(draft.ingredientOverrides.first)
        #expect(override.id == original.id)
        #expect(override.itemID == changed.itemID)
        #expect(override.unitID == changed.unitID)
        #expect(override.quantity == changed.quantity)
        #expect(override.draft == changed)
        #expect(try JSONDecoder().decode(
            RecipeIngredientOverride.self, from: JSONEncoder().encode(override)
        ) == override)
        #expect(draft.ingredients(for: fixture.recipe).first { $0.id == original.id } == changed)
        #expect(draft.ingredients(for: fixture.recipe).first { $0.id == fixture.secondIngredient.id }
                == RecipieIngredientDraft(ingredient: fixture.secondIngredient))

        changed.quantity = 0.4
        draft.updateIngredient(changed, in: fixture.recipe)
        #expect(draft.ingredientOverrides.count == 1)
        #expect(draft.ingredientOverrides.first?.quantity == 0.4)
        draft.updateIngredient(RecipieIngredientDraft(
            itemID: fixture.substitute.id, unitID: fixture.grams.id, quantity: 1
        ), in: fixture.recipe)
        #expect(draft.ingredientOverrides.count == 1)
        draft.updateIngredient(original, in: fixture.recipe)
        #expect(draft.ingredientOverrides.isEmpty)
        #expect(fixture.firstIngredient.item.id == fixture.original.id)
        #expect(fixture.firstIngredient.unit.id == fixture.grams.id)
        #expect(fixture.firstIngredient.quantity == 100)
        #expect(!fixture.context.hasChanges)
    }

    @Test func changingAnySingleIngredientFieldCreatesAnOverride() throws {
        let fixture = try makeFixture()
        let original = RecipieIngredientDraft(ingredient: fixture.firstIngredient)
        var itemOnly = original
        itemOnly.itemID = fixture.substitute.id
        var unitOnly = original
        unitOnly.unitID = fixture.kilograms.id
        var quantityOnly = original
        quantityOnly.quantity = 200
        for changed in [itemOnly, unitOnly, quantityOnly] {
            var draft = MealComponentDraft(source: .recipe(fixture.recipe.id))
            draft.updateIngredient(changed, in: fixture.recipe)
            #expect(draft.ingredientOverrides == [RecipeIngredientOverride(ingredient: changed)])
            draft.updateIngredient(original, in: fixture.recipe)
            #expect(draft.ingredientOverrides.isEmpty)
        }
    }

    @Test func savedOverridesReloadAndResetWithoutChangingOtherOccurrences() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let modified = modifiedComponent(fixture)
        let untouched = MealComponentDraft(source: .recipe(fixture.recipe.id), course: .side)
        var draft = MealDraft(mealType: .lunch)
        draft.name = "Two versions"
        draft.components = [modified, untouched]
        let store = MealStore(context: context)
        let id = try store.save(draft, id: nil)

        let verification = ModelContext(context.container)
        verification.autosaveEnabled = false
        let meal = try #require(verification.fetch(Meal.descriptor(id: id)).first)
        #expect(meal.orderedComponents[0].ingredientOverrides == modified.ingredientOverrides)
        #expect(meal.orderedComponents[0].displayName == "Vegetable stew*")
        #expect(meal.orderedComponents[1].ingredientOverrides == nil)
        #expect(meal.orderedComponents[1].displayName == "Vegetable stew")
        #expect(try MealStore(context: verification).draft(id: id).components == draft.components)
        #expect(MealComponentDraft(component: meal.orderedComponents[0]) == modified)

        draft.components[0].updateIngredient(
            RecipieIngredientDraft(ingredient: fixture.firstIngredient), in: fixture.recipe
        )
        try store.save(draft, id: id)
        let reset = try #require(ModelContext(context.container).fetch(Meal.descriptor(id: id)).first)
        #expect(reset.orderedComponents[0].id == modified.id)
        #expect(reset.orderedComponents[0].ingredientOverrides == nil)
        #expect(reset.orderedComponents[0].displayName == "Vegetable stew")
        #expect(reset.orderedComponents[1].id == untouched.id)
        #expect(reset.orderedComponents[1].ingredientOverrides == nil)
        #expect(fixture.firstIngredient.quantity == 100)
    }

    @Test func mealCopiesPreserveOverridesButHaveIndependentComponentIdentities() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let mealStore = MealStore(context: context)
        var templateDraft = MealDraft(mealType: .lunch)
        templateDraft.name = "Substituted template"
        templateDraft.components = [modifiedComponent(fixture)]
        let templateID = try mealStore.save(templateDraft, id: nil)
        let template = try #require(context.fetch(Meal.descriptor(id: templateID)).first)
        let component = try #require(template.components.first)
        let expected = templateDraft.components[0].ingredientOverrides
        let modelCopy = MealComponent(copying: component)
        #expect(modelCopy.id != component.id)
        #expect(modelCopy.ingredientOverrides == expected)
        modelCopy.ingredientOverrides = nil
        #expect(component.ingredientOverrides == expected)
        let draftCopy = MealComponentDraft(copying: templateDraft.components[0])
        #expect(draftCopy.id != component.id)
        #expect(draftCopy.ingredientOverrides == expected)
        let modelDraftCopy = MealComponentDraft(copying: component)
        #expect(modelDraftCopy.id != component.id)
        #expect(modelDraftCopy.ingredientOverrides == expected)

        let firstDraft = PlannedMealDraft(meal: template)
        let secondDraft = PlannedMealDraft(meal: template)
        #expect(firstDraft.components[0].id != component.id)
        #expect(firstDraft.components[0].id != secondDraft.components[0].id)
        #expect(firstDraft.components[0].ingredientOverrides == expected)
        let plannedStore = PlannedMealStore(context: context)
        try plannedStore.save(firstDraft, id: nil, mealType: .lunch, day: nil, sourceMealID: templateID)
        try plannedStore.save(secondDraft, id: nil, mealType: .lunch, day: nil, sourceMealID: templateID)
        let plans = try context.fetch(FetchDescriptor<PlannedMeal>()).sorted { $0.sortOrder < $1.sortOrder }
        let first = try #require(plans.first)
        let second = try #require(plans.last)
        var edited = try plannedStore.draft(id: first.id)
        #expect(edited.components == firstDraft.components)
        #expect(first.displayName == "Vegetable stew*")
        edited.components[0].ingredientOverrides[0].quantity = 0.5
        try plannedStore.save(edited, id: first.id, mealType: .lunch, day: nil)
        var copiedMeal = MealDraft(plannedMeal: edited, mealType: .lunch)
        copiedMeal.name = "Copied plan"
        #expect(copiedMeal.components[0].id != edited.components[0].id)
        #expect(copiedMeal.components[0].ingredientOverrides == edited.components[0].ingredientOverrides)
        let copiedID = try mealStore.save(copiedMeal, id: nil)

        let verification = ModelContext(context.container)
        let savedFirst = try #require(verification.fetch(PlannedMeal.descriptor(id: first.id)).first)
        let savedSecond = try #require(verification.fetch(PlannedMeal.descriptor(id: second.id)).first)
        #expect(savedFirst.components.first?.ingredientOverrides?.first?.quantity == 0.5)
        #expect(savedSecond.components.first?.ingredientOverrides == expected)
        #expect(savedFirst.sourceMealID == templateID)
        #expect(try verification.fetch(Meal.descriptor(id: templateID)).first?.components.first?
            .ingredientOverrides == expected)
        #expect(try verification.fetch(Meal.descriptor(id: copiedID)).first?.components.first?
            .ingredientOverrides == edited.components[0].ingredientOverrides)

        edited.components[0].updateIngredient(
            RecipieIngredientDraft(ingredient: fixture.firstIngredient), in: fixture.recipe
        )
        try plannedStore.save(edited, id: first.id, mealType: .lunch, day: nil)
        let resetContext = ModelContext(context.container)
        let reset = try #require(resetContext.fetch(PlannedMeal.descriptor(id: first.id)).first)
        #expect(reset.components.first?.ingredientOverrides == nil)
        #expect(reset.displayName == "Vegetable stew")
        #expect(try resetContext.fetch(PlannedMeal.descriptor(id: second.id)).first?.displayName
                == "Vegetable stew*")
    }

    @Test(arguments: [CourseType.starter, .dessert])
    func hiddenCourseModificationsStillMarkThePlannedMeal(course: CourseType) throws {
        let fixture = try makeFixture()
        let main = MealComponent(recipe: fixture.recipe)
        let hidden = MealComponent(recipe: fixture.recipe, course: course)
        hidden.ingredientOverrides = modifiedComponent(fixture).ingredientOverrides
        let meal = PlannedMeal(mealType: .lunch, components: [main, hidden])
        #expect(hidden.displayName == "Vegetable stew*")
        #expect(meal.displayName == "Vegetable stew*")
        hidden.ingredientOverrides = nil
        #expect(meal.displayName == "Vegetable stew")
        main.ingredientOverrides = modifiedComponent(fixture).ingredientOverrides
        #expect(meal.displayName == "Vegetable stew*")
        let hiddenOnly = PlannedMeal(mealType: .lunch, components: [
            MealComponent(recipe: fixture.recipe, course: course)
        ])
        hiddenOnly.components[0].ingredientOverrides = main.ingredientOverrides
        #expect(hiddenOnly.displayName == "Vegetable stew*")
    }

    @Test(arguments: [false, true])
    func nestedIngredientEditingPreservesThePlannedComponentCallback(dismissDishPicker: Bool) throws {
        let fixture = try makeFixture()
        let router = FlowRouter()
        let originalPath: [FlowRouter.Route] = [.editPlannedMeal(UUID())]
        router.path = originalPath
        if dismissDishPicker {
            router.path.append(.dishPicker(course: .main))
        }
        let editorParentPath = router.path
        var component = MealComponentDraft(source: .recipe(fixture.recipe.id))
        var savedComponents: [MealComponentDraft] = []
        router.showMealComponent(
            component, isEditing: true, dismissDishPickerOnSave: dismissDishPicker,
            allowsRecipeEditing: true
        ) { savedComponents.append($0) }
        #expect(router.path == editorParentPath + [.plannedRecipe])
        #expect(router.mealComponent == component)
        #expect(router.isEditingMealComponent)
        let ingredient = RecipieIngredientDraft(ingredient: fixture.firstIngredient)
        var ingredientSaves = 0
        router.showRecipieIngredient(ingredient, isEditing: true) { updated in
            ingredientSaves += 1
            component.updateIngredient(updated, in: fixture.recipe)
        }
        #expect(router.path == editorParentPath + [.plannedRecipe, .recipieIngredient])
        #expect(router.recipieIngredient == ingredient)
        #expect(router.isEditingRecipieIngredient)

        var updatedIngredient = ingredient
        router.showItemPicker(selectedID: ingredient.itemID, kindFilter: .ingredient) {
            updatedIngredient.itemID = $0
        }
        #expect(router.itemKindFilter == .ingredient)
        router.selectItem(fixture.substitute.id)
        router.path.removeLast()
        updatedIngredient.quantity = 200
        router.saveRecipieIngredient(updatedIngredient)
        router.path.removeLast()
        #expect(router.path == editorParentPath + [.plannedRecipe])
        #expect(ingredientSaves == 1)
        #expect(savedComponents.isEmpty)
        #expect(component.ingredientOverrides == [
            RecipeIngredientOverride(ingredient: updatedIngredient)
        ])

        router.saveMealComponent(component)
        #expect(savedComponents == [component])
        #expect(router.path == originalPath)
        router.saveMealComponent(component)
        #expect(savedComponents.count == 1)
        #expect(router.path == originalPath)
        #expect(fixture.firstIngredient.item.id == fixture.original.id)
        #expect(fixture.firstIngredient.quantity == 100)
        #expect(!fixture.context.hasChanges)
    }

    @Test func ordinaryItemPickerClearsThePreviousIngredientOnlyFilter() {
        let router = FlowRouter()
        let initialItemID = UUID()
        let ingredientID = UUID()
        let ordinaryItemID = UUID()
        var ingredientSelections: [UUID] = []
        var ordinarySelections: [UUID] = []
        router.path = [.newPlannedMisc]
        router.showItemPicker(selectedID: initialItemID, kindFilter: .ingredient) {
            ingredientSelections.append($0)
        }
        #expect(router.itemKindFilter == .ingredient)
        #expect(router.selectedItemID == initialItemID)
        router.selectItem(ingredientID)
        router.path.removeLast()
        router.showItemPicker(selectedID: ordinaryItemID) { ordinarySelections.append($0) }
        #expect(router.path == [.newPlannedMisc, .itemPicker])
        #expect(router.itemKindFilter == nil)
        #expect(router.selectedItemID == ordinaryItemID)
        router.selectItem(ordinaryItemID)
        #expect(ingredientSelections == [ingredientID])
        #expect(ordinarySelections == [ordinaryItemID])
    }

    @Test func shoppingUsesEffectiveIngredientsScaledPerOccurrenceWithoutEditingTheCatalogue() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let store = PlannedMealStore(context: context)
        let first = modifiedComponent(fixture)
        var second = MealComponentDraft(copying: first)
        second.ingredientOverrides[0].quantity = 0.4
        try store.save(PlannedMealDraft(components: [
            first, second, MealComponentDraft(source: .recipe(fixture.recipe.id))
        ], servings: 2), id: nil, mealType: .lunch, day: nil)
        try store.save(PlannedMealDraft(components: [
            MealComponentDraft(source: .recipe(fixture.recipe.id))
        ], servings: 8), id: nil, mealType: .dinner, day: .monday)
        try ShoppingListStore(context: context).regenerate()

        let verification = ModelContext(context.container)
        let entries = try verification.fetch(FetchDescriptor<ShoppingListEntry>())
        #expect(entries.count == 2)
        let substituted = try #require(entries.first { $0.item?.id == fixture.substitute.id })
        #expect(substituted.name == fixture.substitute.name)
        #expect(substituted.category?.id == fixture.substitute.category.id)
        #expect(substituted.unit?.id == fixture.grams.id)
        #expect(abs(substituted.quantity - 300) < 0.000_001)
        let original = try #require(entries.first { $0.item?.id == fixture.original.id })
        #expect(original.unit?.id == fixture.grams.id)
        #expect(abs(original.quantity - 425) < 0.000_001)
        let recipe = try #require(verification.fetch(Recipie.descriptor(id: fixture.recipe.id)).first)
        #expect(recipe.serves == 4)
        #expect(recipe.ingredients.allSatisfy { $0.item.id == fixture.original.id && $0.unit.id == fixture.grams.id })
        #expect(recipe.ingredients.first { $0.id == fixture.firstIngredient.id }?.quantity == 100)
        #expect(recipe.ingredients.first { $0.id == fixture.secondIngredient.id }?.quantity == 50)
        let plans = try verification.fetch(FetchDescriptor<PlannedMeal>())
        #expect(plans.first { $0.mealTypeEnum == .dinner }?.components.first?.ingredientOverrides == nil)
        let lunch = try #require(plans.first { $0.mealTypeEnum == .lunch })
        #expect(lunch.orderedComponents[0].ingredientOverrides == first.ingredientOverrides)
        #expect(lunch.orderedComponents[1].ingredientOverrides == second.ingredientOverrides)
        #expect(lunch.orderedComponents[2].ingredientOverrides == nil)
    }

    @Test func substitutedVolumeAndDistinctCountUnitsKeepTheirConversionRules() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let packet = meal_planner_ios.Unit(name: "packet", type: .count, magnitudes: [])
        let count = meal_planner_ios.Unit(name: "count", type: .count, magnitudes: [])
        context.insert(packet)
        context.insert(count)
        try context.save()
        var components: [MealComponentDraft] = []
        for (unit, quantity) in [(fixture.litres, 0.5), (packet, 2.0), (count, 3.0)] {
            var draft = modifiedComponent(fixture)
            draft.ingredientOverrides[0].unitID = unit.id
            draft.ingredientOverrides[0].quantity = quantity
            components.append(draft)
        }
        try PlannedMealStore(context: context).save(
            PlannedMealDraft(components: components, servings: 2),
            id: nil, mealType: .lunch, day: nil
        )
        try ShoppingListStore(context: context).regenerate()
        let entries = try ModelContext(context.container).fetch(FetchDescriptor<ShoppingListEntry>())
            .filter { $0.item?.id == fixture.substitute.id }
        #expect(entries.count == 3)
        #expect(entries.first { $0.unit?.id == fixture.millilitres.id }?.quantity == 250)
        #expect(entries.first { $0.unit?.id == packet.id }?.quantity == 1)
        #expect(entries.first { $0.unit?.id == count.id }?.quantity == 1.5)
    }

    @Test(arguments: InvalidOverride.allCases)
    func invalidOverridesCannotInsertOrMutateSavedOrPlannedMeals(invalid: InvalidOverride) throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let mealStore = MealStore(context: context)
        let plannedStore = PlannedMealStore(context: context)
        var initial = MealDraft(mealType: .lunch)
        initial.name = "Original meal"
        initial.components = [modifiedComponent(fixture)]
        let mealID = try mealStore.save(initial, id: nil)
        let meal = try #require(context.fetch(Meal.descriptor(id: mealID)).first)
        try plannedStore.save(PlannedMealDraft(meal: meal), id: nil, mealType: .lunch, day: nil)
        let planned = try #require(context.fetch(FetchDescriptor<PlannedMeal>()).first)
        let originalPlan = try plannedStore.draft(id: planned.id)
        let bad = invalidComponent(invalid, fixture: fixture)

        var newMeal = MealDraft(mealType: .dinner)
        newMeal.name = "Rejected meal"
        newMeal.components = [modifiedComponent(fixture), bad]
        #expect(throws: MealStore.Error.self) { try mealStore.save(newMeal, id: nil) }
        #expect(throws: PlannedMealStore.Error.self) {
            try plannedStore.save(PlannedMealDraft(components: newMeal.components),
                                  id: nil, mealType: .dinner, day: .monday)
        }
        var changed = initial
        changed.name = "Changed name"
        changed.mealType = .dinner
        changed.components[0].ingredientOverrides[0].quantity = 0.9
        changed.components.append(bad)
        #expect(throws: MealStore.Error.self) { try mealStore.save(changed, id: mealID) }
        var changedPlan = originalPlan
        changedPlan.servings = 9
        changedPlan.components[0].ingredientOverrides[0].quantity = 0.9
        changedPlan.components.append(bad)
        #expect(throws: PlannedMealStore.Error.self) {
            try plannedStore.save(changedPlan, id: planned.id, mealType: .dinner, day: .tuesday)
        }
        #expect(!context.hasChanges)
        #expect(try mealStore.draft(id: mealID) == initial)
        #expect(try plannedStore.draft(id: planned.id).components == originalPlan.components)
        #expect(planned.servings == 2)
        #expect(planned.mealTypeEnum == .lunch)
        #expect(planned.dayEnum == nil)
        let verification = ModelContext(context.container)
        #expect(try verification.fetch(FetchDescriptor<Meal>()).count == 1)
        #expect(try verification.fetch(FetchDescriptor<PlannedMeal>()).count == 1)
        #expect(try verification.fetch(FetchDescriptor<MealComponent>()).count == 2)
        #expect(try MealStore(context: verification).draft(id: mealID) == initial)
        let savedPlan = try PlannedMealStore(context: verification).draft(id: planned.id)
        #expect(savedPlan.components == originalPlan.components)
        #expect(savedPlan.servings == originalPlan.servings)
    }

    @Test(arguments: [MealComponentKind.ingredient, .readymeal])
    func nonRecipeComponentsRejectOverrides(kind: MealComponentKind) throws {
        let fixture = try makeFixture()
        var component: MealComponentDraft
        if kind == .ingredient {
            component = MealComponentDraft(source: .ingredient(fixture.original.id),
                                           quantity: 1, unitID: fixture.grams.id)
        } else {
            component = MealComponentDraft(source: .readymeal(fixture.readymeal.id))
        }
        component.ingredientOverrides = modifiedComponent(fixture).ingredientOverrides
        #expect(!component.hasValidPortion)
        var meal = MealDraft(mealType: .lunch)
        meal.name = "Invalid substitution"
        meal.components = [component]
        #expect(throws: MealStore.Error.self) {
            try MealStore(context: fixture.context).save(meal, id: nil)
        }
        #expect(throws: PlannedMealStore.Error.self) {
            try PlannedMealStore(context: fixture.context).save(
                PlannedMealDraft(components: [component]), id: nil, mealType: .lunch, day: nil
            )
        }
        #expect(!fixture.context.hasChanges)
        #expect(try fixture.context.fetch(FetchDescriptor<MealComponent>()).isEmpty)
    }

    @Test(arguments: InvalidOverride.allCases)
    func invalidShoppingOverridesPreserveExistingEntriesAndPendingEdits(invalid: InvalidOverride) throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let plan = PlannedMeal(mealType: .lunch, components: [MealComponent(recipe: fixture.recipe)])
        context.insert(plan)
        try context.save()
        plan.components[0].ingredientOverrides = invalidComponent(invalid, fixture: fixture).ingredientOverrides
        fixture.original.name = "Pending catalogue edit"
        #expect(throws: ShoppingListStore.Error.self) {
            try ShoppingListStore(context: context).regenerate()
        }
        #expect(context.hasChanges)
        #expect(fixture.original.name == "Pending catalogue edit")
        try expectOriginalList(fixture, in: context)
        try expectOriginalList(fixture, in: ModelContext(context.container))
    }

    @Test(arguments: [
        InvalidOverride.missingItem, .missingUnit, .staleIngredient, .duplicateIngredient,
        .readymealItem, .miscellaneousItem, .invalidUnitType, .zeroUnitBase, .infiniteUnitBase,
        .zeroQuantity, .negativeQuantity,
    ])
    func invalidStoredShoppingOverridesPreserveTheListAfterReload(invalid: InvalidOverride) throws {
        let fixture = try makeFixture()
        let component = MealComponent(recipe: fixture.recipe)
        component.ingredientOverrides = invalidComponent(invalid, fixture: fixture).ingredientOverrides
        fixture.context.insert(PlannedMeal(mealType: .lunch, components: [component]))
        try fixture.context.save()
        let reloaded = ModelContext(fixture.context.container)
        reloaded.autosaveEnabled = false
        #expect(throws: ShoppingListStore.Error.self) {
            try ShoppingListStore(context: reloaded).regenerate()
        }
        #expect(!reloaded.hasChanges)
        try expectOriginalList(fixture, in: reloaded)
        try expectOriginalList(fixture, in: ModelContext(fixture.context.container))
    }

    @Test func deletedIngredientIDsAreRejectedEvenWhenTheRecipeStillExists() throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let plannedStore = PlannedMealStore(context: context)
        try plannedStore.save(PlannedMealDraft(components: [modifiedComponent(fixture)]),
                              id: nil, mealType: .lunch, day: nil)
        let plan = try #require(context.fetch(FetchDescriptor<PlannedMeal>()).first)
        let draft = try plannedStore.draft(id: plan.id)
        fixture.recipe.ingredients.removeAll { $0.id == fixture.firstIngredient.id }
        context.delete(fixture.firstIngredient)
        try context.save()
        #expect(throws: PlannedMealStore.Error.self) {
            try plannedStore.save(draft, id: plan.id, mealType: .lunch, day: nil)
        }
        #expect(throws: ShoppingListStore.Error.self) {
            try ShoppingListStore(context: context).regenerate()
        }
        #expect(!context.hasChanges)
        try expectOriginalList(fixture, in: ModelContext(context.container))
    }

    @Test(arguments: [false, true])
    func substitutionDependenciesProtectItemsAndUnitsUntilReset(planned: Bool) throws {
        let fixture = try makeFixture()
        let context = fixture.context
        let unusedItem = Item(name: "Unused ingredient", category: fixture.original.category, kind: .ingredient)
        let unusedUnit = meal_planner_ios.Unit(name: "Unused count", type: .count, magnitudes: [])
        context.insert(unusedItem)
        context.insert(unusedUnit)
        let component = MealComponent(recipe: fixture.recipe)
        component.ingredientOverrides = modifiedComponent(fixture).ingredientOverrides
        if planned {
            context.insert(PlannedMeal(mealType: .lunch, components: [component]))
        } else {
            context.insert(Meal(name: "Substituted meal", mealType: .lunch, components: [component]))
        }
        try context.save()
        #expect(fixture.substitute.mealComponents.isEmpty)
        let itemStore = ItemStore(context: context)
        let unitStore = UnitStore(context: context)
        #expect {
            try itemStore.delete(ids: [unusedItem.id, fixture.substitute.id])
        } throws: { error in
            guard let error = error as? ItemStore.Error,
                  case .usedInSubstitution(let name) = error else { return false }
            return name == fixture.substitute.name
        }
        #expect(throws: UnitStore.Error.self) {
            try unitStore.delete(ids: [unusedUnit.id, fixture.kilograms.id])
        }
        var kindChange = ItemDraft(item: fixture.substitute)
        kindChange.name = "Rejected rename"
        kindChange.kind = .misc
        #expect(throws: ItemStore.Error.self) {
            try itemStore.save(kindChange, id: fixture.substitute.id)
        }
        #expect(!context.hasChanges)
        let verification = ModelContext(context.container)
        #expect(try verification.fetch(Item.descriptor(id: unusedItem.id)).count == 1)
        let savedItem = try #require(verification.fetch(Item.descriptor(id: fixture.substitute.id)).first)
        #expect(savedItem.name == fixture.substitute.name)
        #expect(savedItem.itemKind == .ingredient)
        #expect(try verification.fetch(meal_planner_ios.Unit.descriptor(id: unusedUnit.id)).count == 1)
        #expect(try verification.fetch(meal_planner_ios.Unit.descriptor(id: fixture.kilograms.id)).count == 1)
        #expect(try verification.fetch(FetchDescriptor<MealComponent>()).first?.ingredientOverrides
                == component.ingredientOverrides)

        component.ingredientOverrides = nil
        try context.save()
        try itemStore.save(kindChange, id: fixture.substitute.id)
        try itemStore.delete(ids: [unusedItem.id, fixture.substitute.id])
        try unitStore.delete(ids: [unusedUnit.id, fixture.kilograms.id])
        let reset = ModelContext(context.container)
        #expect(try reset.fetch(Item.descriptor(id: fixture.substitute.id)).isEmpty)
        #expect(try reset.fetch(meal_planner_ios.Unit.descriptor(id: fixture.kilograms.id)).isEmpty)
        #expect(try reset.fetch(FetchDescriptor<MealComponent>()).first?.displayName == "Vegetable stew")
        #expect(try reset.fetch(Recipie.descriptor(id: fixture.recipe.id)).first?.ingredients.count == 2)
    }

    enum InvalidOverride: CaseIterable {
        case missingItem, missingUnit, staleIngredient, duplicateIngredient
        case readymealItem, miscellaneousItem, invalidUnitType, zeroUnitBase, infiniteUnitBase
        case zeroQuantity, negativeQuantity, nanQuantity, infiniteQuantity, negativeInfiniteQuantity
    }

    private func invalidComponent(_ invalid: InvalidOverride, fixture: Fixture) -> MealComponentDraft {
        var component = modifiedComponent(fixture)
        switch invalid {
        case .missingItem: component.ingredientOverrides[0].itemID = UUID()
        case .missingUnit: component.ingredientOverrides[0].unitID = UUID()
        case .staleIngredient: component.ingredientOverrides[0].id = UUID()
        case .duplicateIngredient: component.ingredientOverrides.append(component.ingredientOverrides[0])
        case .readymealItem: component.ingredientOverrides[0].itemID = fixture.readymeal.id
        case .miscellaneousItem: component.ingredientOverrides[0].itemID = fixture.miscellaneous.id
        case .invalidUnitType: component.ingredientOverrides[0].unitID = fixture.invalidTypeUnit.id
        case .zeroUnitBase: component.ingredientOverrides[0].unitID = fixture.zeroBaseUnit.id
        case .infiniteUnitBase: component.ingredientOverrides[0].unitID = fixture.infiniteBaseUnit.id
        case .zeroQuantity: component.ingredientOverrides[0].quantity = 0
        case .negativeQuantity: component.ingredientOverrides[0].quantity = -1
        case .nanQuantity: component.ingredientOverrides[0].quantity = .nan
        case .infiniteQuantity: component.ingredientOverrides[0].quantity = .infinity
        case .negativeInfiniteQuantity: component.ingredientOverrides[0].quantity = -.infinity
        }
        return component
    }

    private func modifiedComponent(_ fixture: Fixture) -> MealComponentDraft {
        var component = MealComponentDraft(source: .recipe(fixture.recipe.id))
        component.updateIngredient(RecipieIngredientDraft(
            id: fixture.firstIngredient.id, itemID: fixture.substitute.id,
            unitID: fixture.kilograms.id, quantity: 0.2
        ), in: fixture.recipe)
        return component
    }

    private func expectOriginalList(_ fixture: Fixture, in context: ModelContext) throws {
        let entries = try context.fetch(FetchDescriptor<ShoppingListEntry>())
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.id == fixture.oldEntry.id)
        #expect(entry.name == "Keep this list")
        #expect(entry.quantity == 7)
        #expect(entry.sortOrder == 4)
        #expect(entry.isChecked)
        #expect(entry.item?.id == fixture.original.id)
        #expect(entry.category?.id == fixture.original.category.id)
        #expect(entry.unit?.id == fixture.grams.id)
    }

    private func makeFixture() throws -> Fixture {
        let context = try makeTestContext(autosaveEnabled: false)
        let produce = meal_planner_ios.Category(name: "Produce", order: 0)
        let substitutes = meal_planner_ios.Category(name: "Substitutes", order: 1)
        let grams = meal_planner_ios.Unit(name: "grams", type: .weight, magnitudes: [])
        let kilograms = meal_planner_ios.Unit(name: "kilograms", type: .weight, base: 1_000, magnitudes: [])
        let millilitres = meal_planner_ios.Unit(name: "millilitres", type: .volume, magnitudes: [])
        let litres = meal_planner_ios.Unit(name: "litres", type: .volume, base: 1_000, magnitudes: [])
        let invalidTypeUnit = meal_planner_ios.Unit(name: "Invalid type", type: .weight, magnitudes: [])
        invalidTypeUnit.type = -1
        let zeroBaseUnit = meal_planner_ios.Unit(name: "Zero base", type: .weight, base: 0, magnitudes: [])
        let infiniteBaseUnit = meal_planner_ios.Unit(
            name: "Infinite base", type: .weight, base: .infinity, magnitudes: []
        )
        let original = Item(name: "Carrot", category: produce, kind: .ingredient)
        let substitute = Item(name: "Parsnip", category: substitutes, kind: .ingredient)
        let readymeal = Item(name: "Prepared stew", category: produce, kind: .readymeal,
                             readymealData: .default)
        let miscellaneous = Item(name: "Napkins", category: produce, kind: .misc)
        let first = RecipieIngredient(item: original, unit: grams, quantity: 100)
        let second = RecipieIngredient(item: original, unit: grams, quantity: 50)
        let recipe = Recipie(name: "Vegetable stew", serves: 4, ingredients: [first, second])
        let oldEntry = ShoppingListEntry(
            name: "Keep this list", quantity: 7, sortOrder: 4, isChecked: true,
            item: original, category: produce, unit: grams
        )
        context.insert(produce)
        context.insert(substitutes)
        for unit in [grams, kilograms, millilitres, litres, invalidTypeUnit, zeroBaseUnit, infiniteBaseUnit] {
            context.insert(unit)
        }
        for item in [original, substitute, readymeal, miscellaneous] { context.insert(item) }
        context.insert(AppSettings(preferredVolume: millilitres, preferredWeight: grams))
        context.insert(recipe)
        context.insert(oldEntry)
        try context.save()
        return Fixture(
            context: context, original: original, substitute: substitute, readymeal: readymeal,
            miscellaneous: miscellaneous, grams: grams, kilograms: kilograms,
            millilitres: millilitres, litres: litres, invalidTypeUnit: invalidTypeUnit,
            zeroBaseUnit: zeroBaseUnit, infiniteBaseUnit: infiniteBaseUnit,
            recipe: recipe, firstIngredient: first, secondIngredient: second, oldEntry: oldEntry
        )
    }

    private struct Fixture {
        let context: ModelContext
        let original: Item
        let substitute: Item
        let readymeal: Item
        let miscellaneous: Item
        let grams: meal_planner_ios.Unit
        let kilograms: meal_planner_ios.Unit
        let millilitres: meal_planner_ios.Unit
        let litres: meal_planner_ios.Unit
        let invalidTypeUnit: meal_planner_ios.Unit
        let zeroBaseUnit: meal_planner_ios.Unit
        let infiniteBaseUnit: meal_planner_ios.Unit
        let recipe: Recipie
        let firstIngredient: RecipieIngredient
        let secondIngredient: RecipieIngredient
        let oldEntry: ShoppingListEntry
    }
}
