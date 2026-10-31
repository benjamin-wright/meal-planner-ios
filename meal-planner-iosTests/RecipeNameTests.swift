import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct RecipeNameTests {
    @Test(arguments: ["tomato soup", "Tomato soup", "TOMATO SOUP"],
          ["tomato soup", "Tomato soup", "TOMATO SOUP"])
    func duplicateNamesIgnoreCaseAndSurroundingWhitespace(name: String, existingName: String) {
        var draft = RecipieDraft()
        draft.name = " \n\(name)\t "

        #expect(draft.validate(existingNames: ["\t\(existingName)\n"]) == [.duplicateName])
    }

    @Test(arguments: ["Tomato stew", "Tomato soups", "Tomato  soup"])
    func distinctNamesRemainValid(name: String) {
        var draft = RecipieDraft()
        draft.name = name

        #expect(draft.validate(existingNames: ["tomato soup"]).isEmpty)
    }

    @Test(arguments: [false, true], [false, true])
    func duplicateSavesDoNotInsertOrModifyRecipes(editing: Bool, importing: Bool) throws {
        let context = try makeTestContext(autosaveEnabled: false)
        let existing = Recipie(name: " \nTOMATO soup\t ", summary: "Existing recipe")
        let edited = Recipie(name: "Vegetable stew", summary: "Original summary", steps: ["Simmer."])
        context.insert(existing)
        context.insert(edited)
        try context.save()

        var draft = RecipieDraft()
        draft.name = "\tTomato Soup\n"
        draft.summary = "Replacement summary"
        draft.steps = ["Roast."]
        if importing { draft.importedIngredients = [] }

        #expect {
            try RecipieStore(context: context).save(draft, id: editing ? edited.id : nil)
        } throws: { error in
            guard case RecipieStore.Error.invalidDraft(let errors) = error else { return false }
            return errors == [.duplicateName]
        }

        #expect(!context.hasChanges)
        let persisted = try ModelContext(context.container).fetch(FetchDescriptor<Recipie>())
        #expect(persisted.count == 2)
        let unchanged = try #require(persisted.first { $0.id == edited.id })
        #expect(unchanged.name == "Vegetable stew")
        #expect(unchanged.summary == "Original summary")
        #expect(unchanged.steps == ["Simmer."])
        #expect(persisted.first { $0.id == existing.id }?.summary == "Existing recipe")
    }

    @Test(arguments: [false, true])
    func editingOwnNameNormalizesCaseWithoutTreatingItAsADuplicate(importing: Bool) throws {
        let context = try makeTestContext(autosaveEnabled: false)
        let recipe = Recipie(name: "Tomato soup")
        context.insert(recipe)
        try context.save()

        var draft = RecipieDraft(recipie: recipe)
        draft.name = " \tTomato Soup\n"
        if importing { draft.importedIngredients = [] }
        let savedID = try RecipieStore(context: context).save(draft, id: recipe.id)

        let persisted = try ModelContext(context.container).fetch(FetchDescriptor<Recipie>())
        #expect(savedID == recipe.id)
        #expect(persisted.count == 1)
        #expect(persisted.first?.name == "tomato soup")
    }

    @Test(arguments: [false, true])
    func newRecipesSaveLowercaseNamesWithoutLowercasingOtherText(importing: Bool) throws {
        let context = try makeTestContext(autosaveEnabled: false)
        var draft = RecipieDraft()
        draft.name = " \tTomato SOUP\n"
        draft.summary = "Serve with Bread."
        draft.steps = ["Simmer, then serve."]
        if importing { draft.importedIngredients = [] }

        let savedID = try RecipieStore(context: context).save(draft, id: nil)

        let recipe = try #require(ModelContext(context.container).fetch(Recipie.descriptor(id: savedID)).first)
        #expect(recipe.name == "tomato soup")
        #expect(recipe.summary == "Serve with Bread.")
        #expect(recipe.steps == ["Simmer, then serve."])
    }
}
