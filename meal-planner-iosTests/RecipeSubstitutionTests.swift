import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct RecipeSubstitutionTests {
    @Test func overridesAreSparseAndKeyedByIngredientRatherThanItem() throws {
        let fixture = try Fixture()
        var draft = MealComponentDraft(source: .recipe(fixture.recipe.id))
        let original = RecipieIngredientDraft(ingredient: fixture.firstIngredient)
        #expect(draft.ingredientOverrides.isEmpty)
        let originals = fixture.recipe.ingredients.map(RecipieIngredientDraft.init(ingredient:))
        #expect(draft.ingredients(for: fixture.recipe) == originals)
        draft.updateIngredient(original, in: fixture.recipe)
        #expect(draft.ingredientOverrides.isEmpty)

        var changed = RecipieIngredientDraft(
            id: original.id, itemID: fixture.substitute.id, unitID: fixture.kilograms.id, quantity: 0.2
        )
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
        let fixture = try Fixture()
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
        let fixture = try Fixture()
        let context = fixture.context
        let modified = modifiedComponent(fixture)
        let untouched = MealComponentDraft(source: .recipe(fixture.recipe.id), course: .side)
        var draft = mealDraft("Two versions", components: [modified, untouched])
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
        let fixture = try Fixture()
        let context = fixture.context
        let mealStore = MealStore(context: context)
        let templateDraft = mealDraft("Substituted template", components: [modifiedComponent(fixture)])
        let templateID = try mealStore.save(templateDraft, id: nil)
        let template = try #require(context.fetch(Meal.descriptor(id: templateID)).first)
        let component = try #require(template.components.first)
        let expected = templateDraft.components[0].ingredientOverrides
        let modelCopy = MealComponent(copying: component)
        #expect(modelCopy.id != component.id)
        #expect(modelCopy.ingredientOverrides == expected)
        modelCopy.ingredientOverrides = nil
        #expect(component.ingredientOverrides == expected)
        let draftCopies = [MealComponentDraft(copying: templateDraft.components[0]),
                           MealComponentDraft(copying: component)]
        for copy in draftCopies {
            #expect(copy.id != component.id)
            #expect(copy.ingredientOverrides == expected)
        }

        let firstDraft = PlannedMealDraft(meal: template)
        let secondDraft = PlannedMealDraft(meal: template)
        #expect(firstDraft.components[0].id != component.id)
        #expect(firstDraft.components[0].id != secondDraft.components[0].id)
        #expect(firstDraft.components[0].ingredientOverrides == expected)
        let plannedStore = PlannedMealStore(context: context)
        try plannedStore.save(firstDraft, id: nil, mealType: .lunch, day: nil)
        try plannedStore.save(secondDraft, id: nil, mealType: .lunch, day: nil)
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
        let fixture = try Fixture()
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

    @Test(arguments: EditorEntry.allCases)
    func nestedIngredientEditingPreservesThePlannedComponentCallback(entry: EditorEntry) throws {
        let fixture = try Fixture()
        let router = FlowRouter()
        let originalPath: [FlowRouter.Route] = [.editPlannedMeal(UUID())]
        router.path = originalPath
        var savedComponents: [MealComponentDraft] = []
        let dishPicker = entry == .dishPicker
            ? router.showDishPicker { savedComponents.append($0) }
            : nil
        var component = MealComponentDraft(source: .recipe(fixture.recipe.id))
        let componentEditor = router.showMealComponent(component, isEditing: true, allowsRecipeEditing: true) {
            if let dishPicker {
                router.complete(dishPicker, with: $0)
            } else {
                savedComponents.append($0)
            }
        }
        let componentEditorPath = router.path
        #expect(componentEditor.initialValue == component)
        let ingredient = RecipieIngredientDraft(ingredient: fixture.firstIngredient)
        var ingredientSaves = 0
        let ingredientEditor = router.showRecipieIngredient(ingredient, isEditing: true) { updated in
            ingredientSaves += 1
            component.updateIngredient(updated, in: fixture.recipe)
        }
        #expect(ingredientEditor.initialValue == ingredient)

        var updatedIngredient = ingredient
        let itemPicker = router.showItemPicker(selectedID: ingredient.itemID, kindFilter: .ingredient) {
            updatedIngredient.itemID = $0
        }
        #expect(router.complete(itemPicker, with: fixture.substitute.id))
        updatedIngredient.quantity = 200
        #expect(router.complete(ingredientEditor, with: updatedIngredient))
        #expect(router.path == componentEditorPath)
        #expect(ingredientSaves == 1)
        #expect(savedComponents.isEmpty)
        #expect(component.ingredientOverrides == [RecipeIngredientOverride(ingredient: updatedIngredient)])

        #expect(router.complete(componentEditor, with: component))
        #expect(savedComponents == [component])
        #expect(router.path == originalPath)
        #expect(!router.complete(componentEditor, with: component))
        #expect(savedComponents.count == 1)
        #expect(fixture.firstIngredient.item.id == fixture.original.id)
        #expect(fixture.firstIngredient.quantity == 100)
        #expect(!fixture.context.hasChanges)
    }

    @Test func nestedItemPickersKeepIndependentSelectionsAndRestrictions() {
        let router = FlowRouter()
        let initialItemID = UUID()
        let ingredientID = UUID()
        let ordinaryItemID = UUID()
        var ingredientSelections: [UUID] = []
        var ordinarySelections: [UUID] = []
        router.path = [.newPlannedMisc]
        let ingredientPicker = router.showItemPicker(selectedID: initialItemID, kindFilter: .ingredient) {
            ingredientSelections.append($0)
        }
        let ingredientPickerPath = router.path
        let ordinaryPicker = router.showItemPicker(selectedID: ordinaryItemID) { ordinarySelections.append($0) }
        #expect(ingredientPicker.initialValue == initialItemID)
        #expect(ordinaryPicker.initialValue == ordinaryItemID)
        #expect(router.path.last == .itemPicker(ordinaryPicker, kindFilter: nil))
        #expect(router.complete(ordinaryPicker, with: ordinaryItemID))
        #expect(router.path == ingredientPickerPath)
        #expect(router.path.last == .itemPicker(ingredientPicker, kindFilter: .ingredient))
        #expect(ingredientSelections.isEmpty)
        #expect(ordinarySelections == [ordinaryItemID])
        #expect(router.complete(ingredientPicker, with: ingredientID))
        #expect(ingredientSelections == [ingredientID])
        #expect(router.path == [.newPlannedMisc])
    }

    @Test func shoppingUsesEffectiveIngredientsScaledPerOccurrenceWithoutEditingTheCatalogue() throws {
        let fixture = try Fixture()
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
        let fixture = try Fixture()
        let context = fixture.context
        let packet = meal_planner_ios.Unit(name: "packet", type: .count, magnitudes: [])
        let count = meal_planner_ios.Unit(name: "count", type: .count, magnitudes: [])
        context.insert(packet)
        context.insert(count)
        try context.save()
        let components = [(fixture.litres, 0.5), (packet, 2.0), (count, 3.0)].map { unit, quantity in
            modifiedComponent(fixture, unit: unit, quantity: quantity)
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

    // Exhaustive ingredient rules are covered by DomainFoundationTests. These
    // cases exercise missing references, model decoding and pre-save validation.
    @Test(arguments: [InvalidOverride.missingItem, .invalidUnitType, .nanQuantity])
    func invalidOverridesCannotInsertOrMutateSavedOrPlannedMeals(invalid: InvalidOverride) throws {
        let fixture = try Fixture()
        let context = fixture.context
        let bad = try invalidComponent(invalid, fixture: fixture)
        let mealStore = MealStore(context: context)
        let plannedStore = PlannedMealStore(context: context)
        let initial = mealDraft("Original meal", components: [modifiedComponent(fixture)])
        let mealID = try mealStore.save(initial, id: nil)
        let meal = try #require(context.fetch(Meal.descriptor(id: mealID)).first)
        try plannedStore.save(PlannedMealDraft(meal: meal), id: nil, mealType: .lunch, day: nil)
        let planned = try #require(context.fetch(FetchDescriptor<PlannedMeal>()).first)
        let originalPlan = try plannedStore.draft(id: planned.id)
        let newMeal = mealDraft("Rejected meal", components: [modifiedComponent(fixture), bad], type: .dinner)
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
        for verification in [context, ModelContext(context.container)] {
            #expect(try verification.fetch(FetchDescriptor<Meal>()).count == 1)
            #expect(try verification.fetch(FetchDescriptor<PlannedMeal>()).count == 1)
            #expect(try verification.fetch(FetchDescriptor<MealComponent>()).count == 2)
            let savedMeal = try MealStore(context: verification).draft(id: mealID)
            #expect(savedMeal.name == initial.name)
            #expect(savedMeal.mealType == initial.mealType)
            #expect(savedMeal.components == initial.components)
            let savedPlan = try #require(verification.fetch(PlannedMeal.descriptor(id: planned.id)).first)
            #expect(savedPlan.servings == 2)
            #expect(savedPlan.mealTypeEnum == .lunch)
            #expect(savedPlan.dayEnum == nil)
            let savedPlanDraft = try PlannedMealStore(context: verification).draft(id: planned.id)
            #expect(savedPlanDraft.components == originalPlan.components)
            #expect(savedPlanDraft.servings == originalPlan.servings)
        }
    }

    @Test(arguments: [MealComponentKind.ingredient, .readymeal])
    func nonRecipeComponentsRejectOverrides(kind: MealComponentKind) throws {
        let fixture = try Fixture()
        var component: MealComponentDraft
        if kind == .ingredient {
            component = MealComponentDraft(source: .ingredient(fixture.original.id),
                                           quantity: 1, unitID: fixture.grams.id)
        } else {
            let readymeal = Item(name: "Prepared stew", category: fixture.original.category,
                                 kind: .readymeal, readymealData: .default)
            fixture.context.insert(readymeal)
            try fixture.context.save()
            component = MealComponentDraft(source: .readymeal(readymeal.id))
        }
        component.ingredientOverrides = modifiedComponent(fixture).ingredientOverrides
        #expect(!component.hasValidPortion)
        let meal = mealDraft("Invalid substitution", components: [component])
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

    @Test(arguments: [
        (invalid: InvalidOverride.missingItem, state: OverrideState.saved),
        (invalid: InvalidOverride.invalidUnitType, state: OverrideState.saved),
        (invalid: InvalidOverride.zeroQuantity, state: OverrideState.saved),
        (invalid: InvalidOverride.nanQuantity, state: OverrideState.pending),
    ])
    func invalidShoppingOverridesPreserveTheListAndPendingEdits(
        invalid: InvalidOverride, state: OverrideState
    ) throws {
        let fixture = try Fixture()
        let context = fixture.context
        let bad = try invalidComponent(invalid, fixture: fixture)
        let plan = PlannedMeal(mealType: .lunch, components: [MealComponent(recipe: fixture.recipe)])
        context.insert(plan)
        if state == .saved { plan.components[0].ingredientOverrides = bad.ingredientOverrides }
        try context.save()
        if state == .pending {
            plan.components[0].ingredientOverrides = bad.ingredientOverrides
            fixture.original.name = "Pending catalogue edit"
        }
        let verification = state == .pending ? context : ModelContext(context.container)
        verification.autosaveEnabled = false
        #expect(throws: ShoppingListStore.Error.self) {
            try ShoppingListStore(context: verification).regenerate()
        }
        #expect(verification.hasChanges == (state == .pending))
        if state == .pending {
            #expect(fixture.original.name == "Pending catalogue edit")
        }
        try expectOriginalList(fixture, in: verification)
        try expectOriginalList(fixture, in: ModelContext(context.container))
    }

    @Test func deletingRecipeIngredientsPreservesOtherSubstitutionsAndUsableMeals() throws {
        let fixture = try Fixture()
        let context = fixture.context
        var modified = modifiedComponent(fixture)
        let remaining = RecipieIngredientDraft(
            id: fixture.secondIngredient.id, itemID: fixture.substitute.id,
            unitID: fixture.kilograms.id, quantity: 0.4
        )
        modified.updateIngredient(remaining, in: fixture.recipe)
        let onlyDeleted = modifiedComponent(fixture)

        let otherIngredient = RecipieIngredient(item: fixture.original, unit: fixture.grams, quantity: 10)
        let otherRecipe = Recipie(name: "Other recipe", ingredients: [otherIngredient])
        context.insert(otherRecipe)
        var other = MealComponentDraft(source: .recipe(otherRecipe.id))
        other.updateIngredient(RecipieIngredientDraft(
            id: otherIngredient.id, itemID: fixture.substitute.id,
            unitID: fixture.grams.id, quantity: 20
        ), in: otherRecipe)
        let mealID = try MealStore(context: context).save(
            mealDraft("Substituted meal", components: [modified, onlyDeleted, other]), id: nil
        )
        let plannedStore = PlannedMealStore(context: context)
        try plannedStore.save(PlannedMealDraft(components: [modified, onlyDeleted].map {
            MealComponentDraft(copying: $0)
        }), id: nil, mealType: .lunch, day: nil)
        let planID = try #require(context.fetch(FetchDescriptor<PlannedMeal>()).first).id
        let deletedID = fixture.firstIngredient.id
        var recipeDraft = RecipieDraft(recipie: fixture.recipe)
        recipeDraft.ingredients.removeAll { $0.id == deletedID }
        try RecipieStore(context: context).save(recipeDraft, id: fixture.recipe.id)

        for verification in [context, ModelContext(context.container)] {
            let meal = try #require(verification.fetch(Meal.descriptor(id: mealID)).first)
            let plan = try #require(verification.fetch(PlannedMeal.descriptor(id: planID)).first)
            for components in [meal.orderedComponents, plan.orderedComponents] {
                #expect(components[0].ingredientOverrides == [RecipeIngredientOverride(ingredient: remaining)])
                #expect(components[1].ingredientOverrides == nil)
                #expect(components[0].displayName == "Vegetable stew*")
                #expect(components[1].displayName == "Vegetable stew")
            }
            #expect(meal.orderedComponents[2].ingredientOverrides == other.ingredientOverrides)
            #expect(try verification.fetch(FetchDescriptor<RecipieIngredient>()).allSatisfy { $0.id != deletedID })
        }

        let verification = ModelContext(context.container)
        let mealStore = MealStore(context: verification)
        try mealStore.save(mealStore.draft(id: mealID), id: mealID)
        let verifiedPlanStore = PlannedMealStore(context: verification)
        try verifiedPlanStore.save(verifiedPlanStore.draft(id: planID),
                                   id: planID, mealType: .lunch, day: nil)
        try ShoppingListStore(context: verification).regenerate()
        let entries = try ModelContext(context.container).fetch(FetchDescriptor<ShoppingListEntry>())
        #expect(entries.count == 2)
        #expect(entries.first { $0.item?.id == fixture.substitute.id }?.quantity == 200)
        #expect(entries.first { $0.item?.id == fixture.original.id }?.quantity == 25)
        #expect(entries.allSatisfy { $0.unit?.id == fixture.grams.id })
    }

    @Test func replacingRecipeIngredientsByImportClearsObsoleteSubstitutionDependencies() throws {
        let fixture = try Fixture()
        let context = fixture.context
        let mealID = try MealStore(context: context).save(
            mealDraft("Substituted meal", components: [modifiedComponent(fixture)]), id: nil
        )
        let meal = try #require(context.fetch(Meal.descriptor(id: mealID)).first)
        try PlannedMealStore(context: context).save(PlannedMealDraft(meal: meal),
                                                   id: nil, mealType: .lunch, day: nil)
        var draft = RecipieDraft(recipie: fixture.recipe)
        let imported = ImportedRecipieIngredient(
            sourceText: "80 g carrot", name: "Carrot", quantityText: "80",
            itemID: fixture.original.id, unitID: fixture.grams.id
        )
        draft.importedIngredients = [imported]
        try RecipieStore(context: context).save(draft, id: fixture.recipe.id)

        let verification = ModelContext(context.container)
        let recipe = try #require(verification.fetch(Recipie.descriptor(id: fixture.recipe.id)).first)
        #expect(recipe.ingredients.map(\.id) == [imported.id])
        let components = try verification.fetch(FetchDescriptor<MealComponent>())
        #expect(components.count == 2)
        #expect(components.allSatisfy { $0.ingredientOverrides == nil })
        #expect(components.allSatisfy { $0.displayName == "Vegetable stew" })
        let mealStore = MealStore(context: verification)
        try mealStore.save(mealStore.draft(id: mealID), id: mealID)
        let plan = try #require(verification.fetch(FetchDescriptor<PlannedMeal>()).first)
        let plannedStore = PlannedMealStore(context: verification)
        try plannedStore.save(plannedStore.draft(id: plan.id), id: plan.id, mealType: .lunch, day: nil)
        try ItemStore(context: verification).delete(ids: [fixture.substitute.id])
        try UnitStore(context: verification).delete(ids: [fixture.kilograms.id])
        try ShoppingListStore(context: verification).regenerate()
        let entries = try ModelContext(context.container).fetch(FetchDescriptor<ShoppingListEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.item?.id == fixture.original.id)
        #expect(entries.first?.quantity == 40)
        #expect(entries.first?.unit?.id == fixture.grams.id)
    }

    @Test func outOfBandIngredientDeletionIsStillRejected() throws {
        let fixture = try Fixture()
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

    @Test(arguments: MealOwner.allCases)
    func substitutionDependenciesProtectItemsAndUnitsUntilReset(owner: MealOwner) throws {
        let fixture = try Fixture()
        let context = fixture.context
        let unusedItem = Item(name: "Unused ingredient", category: fixture.original.category, kind: .ingredient)
        let unusedUnit = meal_planner_ios.Unit(name: "Unused count", type: .count, magnitudes: [])
        context.insert(unusedItem)
        context.insert(unusedUnit)
        let component = MealComponent(recipe: fixture.recipe)
        component.ingredientOverrides = modifiedComponent(fixture).ingredientOverrides
        owner.insert(component, named: "Substituted meal", in: context)
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
        try expectItems([unusedItem.id], in: verification)
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

    @Test(arguments: MealOwner.allCases, OverrideState.allCases)
    func substitutionCategoriesRejectBatchDeletionBeforeMutation(owner: MealOwner, state: OverrideState) throws {
        let fixture = try Fixture()
        let context = fixture.context
        let substituteCategory = fixture.substitute.category
        let originalCategory = fixture.original.category
        let unusedCategory = meal_planner_ios.Category(name: "Unused category", order: 0)
        let retainedCategory = meal_planner_ios.Category(name: "Retained category", order: 3)
        let unusedItem = Item(name: "Unused item", category: unusedCategory, kind: .ingredient)
        originalCategory.order = 1
        substituteCategory.order = 2
        context.insert(unusedCategory)
        context.insert(retainedCategory)
        context.insert(unusedItem)
        let component = MealComponent(recipe: fixture.recipe)
        let overrides = modifiedComponent(fixture).ingredientOverrides
        if state == .saved { component.ingredientOverrides = overrides }
        owner.insert(component, named: "Substitution category dependency", in: context)
        try context.save()
        if state == .pending { component.ingredientOverrides = overrides }
        #expect(fixture.substitute.mealComponents.isEmpty)
        #expect(fixture.recipe.ingredients.allSatisfy { $0.item.id != fixture.substitute.id })
        let categories = try context.fetch(meal_planner_ios.Category.orderedDescriptor)
        let originalCategories = (ids: categories.map(\.id), orders: categories.map(\.order))
        #expect(originalCategories.ids == [
            unusedCategory.id, originalCategory.id, substituteCategory.id, retainedCategory.id
        ])
        #expect(originalCategories.orders == [0, 1, 2, 3])
        let selectedIDs = [unusedCategory.id, substituteCategory.id]
        #expect {
            try CategoryStore(context: context).delete(ids: selectedIDs)
        } throws: { error in
            guard let error = error as? CategoryStore.Error,
                  case .itemUsedInSubstitution(let category, let item) = error else { return false }
            return category == substituteCategory.name && item == fixture.substitute.name
        }
        #expect(context.hasChanges == (state == .pending))
        #expect(component.ingredientOverrides == overrides)
        let verification = ModelContext(context.container)
        for snapshotContext in [context, verification] {
            try expectCategories(originalCategories, in: snapshotContext)
            try expectItems([unusedItem.id, fixture.substitute.id], in: snapshotContext)
        }
        #expect(try verification.fetch(FetchDescriptor<MealComponent>()).first?.ingredientOverrides
                == (state == .pending ? nil : overrides))

        component.ingredientOverrides = nil
        try context.save()
        try CategoryStore(context: context).delete(ids: selectedIDs)
        let reset = ModelContext(context.container)
        try expectCategories((ids: [originalCategory.id, retainedCategory.id], orders: [0, 1]), in: reset)
        try expectItems([unusedItem.id, fixture.substitute.id], count: 0, in: reset)
        #expect(try reset.fetch(FetchDescriptor<MealComponent>()).first?.ingredientOverrides == nil)
        #expect(try reset.fetch(FetchDescriptor<MealComponent>()).first?.displayName == "Vegetable stew")
        #expect(try reset.fetch(Recipie.descriptor(id: fixture.recipe.id)).first?.ingredients.count == 2)
    }

    enum EditorEntry: CaseIterable { case plannedMeal, dishPicker }
    enum MealOwner: CaseIterable {
        case saved, planned
        func insert(_ component: MealComponent, named name: String, in context: ModelContext) {
            switch self {
            case .saved: context.insert(Meal(name: name, mealType: .lunch, components: [component]))
            case .planned: context.insert(PlannedMeal(mealType: .lunch, components: [component]))
            }
        }
    }
    enum OverrideState: CaseIterable { case saved, pending }

    enum InvalidOverride {
        case missingItem, invalidUnitType, zeroQuantity, nanQuantity
    }

    private func invalidComponent(_ invalid: InvalidOverride, fixture: Fixture) throws -> MealComponentDraft {
        var component = modifiedComponent(fixture)
        switch invalid {
        case .missingItem: component.ingredientOverrides[0].itemID = UUID()
        case .invalidUnitType:
            let unit = meal_planner_ios.Unit(name: "Invalid unit", type: .weight,
                                            base: 1, magnitudes: [])
            unit.type = -1
            fixture.context.insert(unit)
            try fixture.context.save()
            component.ingredientOverrides[0].unitID = unit.id
        case .zeroQuantity: component.ingredientOverrides[0].quantity = 0
        case .nanQuantity: component.ingredientOverrides[0].quantity = .nan
        }
        return component
    }

    private func modifiedComponent(
        _ fixture: Fixture, unit: meal_planner_ios.Unit? = nil, quantity: Double = 0.2
    ) -> MealComponentDraft {
        var component = MealComponentDraft(source: .recipe(fixture.recipe.id))
        component.updateIngredient(RecipieIngredientDraft(
            id: fixture.firstIngredient.id, itemID: fixture.substitute.id,
            unitID: (unit ?? fixture.kilograms).id, quantity: quantity
        ), in: fixture.recipe)
        return component
    }

    private func mealDraft(_ name: String, components: [MealComponentDraft], type: MealType = .lunch) -> MealDraft {
        var draft = MealDraft(mealType: type)
        draft.name = name
        draft.components = components
        return draft
    }

    private func expectCategories(_ snapshot: (ids: [UUID], orders: [Int]), in context: ModelContext,
                                  sourceLocation: SourceLocation = #_sourceLocation) throws {
        let categories = try context.fetch(meal_planner_ios.Category.orderedDescriptor)
        #expect(categories.map(\.id) == snapshot.ids, sourceLocation: sourceLocation)
        #expect(categories.map(\.order) == snapshot.orders, sourceLocation: sourceLocation)
    }

    private func expectItems(_ ids: [UUID], count: Int = 1, in context: ModelContext,
                             sourceLocation: SourceLocation = #_sourceLocation) throws {
        for id in ids {
            #expect(try context.fetch(Item.descriptor(id: id)).count == count, sourceLocation: sourceLocation)
        }
    }

    private func expectOriginalList(_ fixture: Fixture, in context: ModelContext,
                                    sourceLocation: SourceLocation = #_sourceLocation) throws {
        let entries = try context.fetch(FetchDescriptor<ShoppingListEntry>())
        #expect(entries.count == 1, sourceLocation: sourceLocation)
        let entry = try #require(entries.first, sourceLocation: sourceLocation)
        #expect(entry.id == fixture.oldEntry.id, sourceLocation: sourceLocation)
        #expect(entry.name == "Keep this list", sourceLocation: sourceLocation)
        #expect(entry.quantity == 7, sourceLocation: sourceLocation)
        #expect(entry.sortOrder == 4, sourceLocation: sourceLocation)
        #expect(entry.isChecked, sourceLocation: sourceLocation)
        #expect(entry.item?.id == fixture.original.id, sourceLocation: sourceLocation)
        #expect(entry.category?.id == fixture.original.category.id, sourceLocation: sourceLocation)
        #expect(entry.unit?.id == fixture.grams.id, sourceLocation: sourceLocation)
    }

    @MainActor private final class Fixture {
        let context: ModelContext
        let original = Item(name: "Carrot", category: .init(name: "Produce", order: 0), kind: .ingredient)
        let substitute = Item(name: "Parsnip", category: .init(name: "Substitutes", order: 1), kind: .ingredient)
        let grams = meal_planner_ios.Unit(name: "grams", type: .weight, magnitudes: [])
        let kilograms = meal_planner_ios.Unit(name: "kilograms", type: .weight, base: 1_000, magnitudes: [])
        let millilitres = meal_planner_ios.Unit(name: "millilitres", type: .volume, magnitudes: [])
        let litres = meal_planner_ios.Unit(name: "litres", type: .volume, base: 1_000, magnitudes: [])
        lazy var firstIngredient = RecipieIngredient(item: original, unit: grams, quantity: 100)
        lazy var secondIngredient = RecipieIngredient(item: original, unit: grams, quantity: 50)
        lazy var recipe = Recipie(name: "Vegetable stew", serves: 4, ingredients: [firstIngredient, secondIngredient])
        lazy var oldEntry = ShoppingListEntry(
            name: "Keep this list", quantity: 7, sortOrder: 4, isChecked: true,
            item: original, category: original.category, unit: grams
        )

        init() throws {
            context = try makeTestContext(autosaveEnabled: false)
            for category in [original.category, substitute.category] { context.insert(category) }
            for unit in [grams, kilograms, millilitres, litres] { context.insert(unit) }
            for item in [original, substitute] { context.insert(item) }
            context.insert(AppSettings(preferredVolume: millilitres, preferredWeight: grams))
            context.insert(recipe)
            context.insert(oldEntry)
            try context.save()
        }
    }
}
