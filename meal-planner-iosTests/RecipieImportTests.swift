import Foundation
import FoundationModels
import SwiftData
import Testing
import UIKit
@testable import meal_planner_ios

struct RecipieImportTests {
    @MainActor
    @Test func importedIngredientReviewPreservesPickerSelection() {
        let router = FlowRouter()
        var ingredient = ImportedRecipieIngredient(sourceText: "2 onions", name: "onions", quantityText: "2")
        var saved: ImportedRecipieIngredient?

        router.showImportedRecipieIngredient(ingredient) { saved = $0 }
        #expect(router.path == [.importedRecipieIngredient])
        #expect(router.importedRecipieIngredient?.id == ingredient.id)

        router.showItemPicker(selectedID: UUID()) { ingredient.itemID = $0 }
        router.path.append(.newItem)
        let itemID = UUID()
        router.selectItem(itemID)
        #expect(ingredient.itemID == itemID)
        #expect(router.path == [.importedRecipieIngredient, .itemPicker, .newItem])

        router.showUnitPicker(selectedID: UUID()) { ingredient.unitID = $0 }
        let unitID = UUID()
        router.selectUnit(unitID)
        router.saveImportedRecipieIngredient(ingredient)
        #expect(saved?.itemID == itemID)
        #expect(saved?.unitID == unitID)
        #expect(saved?.sourceText == "2 onions")
    }

    @Test func quantitiesAcceptFractionsButRejectGuesses() {
        #expect(RecipieImportMapper.parseQuantity("1½") == 1.5)
        #expect(RecipieImportMapper.parseQuantity("1 1/2") == 1.5)
        #expect(RecipieImportMapper.parseQuantity(" ¾ ") == 0.75)
        #expect(RecipieImportMapper.parseQuantity("2.5") == 2.5)
        for value in ["to taste", "1–2", "1-2", "1/0", "0", "-1", "nan", "inf", "1 2", "1/2/3"] {
            #expect(RecipieImportMapper.parseQuantity(value) == nil)
        }
    }

    @MainActor
    @Test func attachedUnitIsSeparatedFromImportedQuantity() {
        let grams = meal_planner_ios.Unit(name: "grams", type: .weight, magnitudes: [
            Magnitude(abbreviation: "g", singular: "gram", plural: "grams", multiplier: 1)
        ])
        let source = "80g flour"

        let mapped = RecipieImportMapper.ingredient(
            ExtractedRecipieIngredient(sourceText: source, name: "flour", quantity: "80g", unit: "g"),
            items: [], units: [grams]
        )
        #expect(mapped.quantityText == "80")
        #expect(mapped.unitID == grams.id)
        #expect(mapped.quantity(units: [grams]) == 80)
        #expect(mapped.sourceText == source)

        let namedUnit = RecipieImportMapper.ingredient(
            ExtractedRecipieIngredient(sourceText: source, name: "flour", quantity: "80g", unit: "grams"),
            items: [], units: [grams]
        )
        #expect(namedUnit.quantityText == "80")
        #expect(namedUnit.unitID == grams.id)

        let omittedUnit = RecipieImportMapper.ingredient(
            ExtractedRecipieIngredient(sourceText: source, name: "flour", quantity: "80g", unit: nil),
            items: [], units: [grams]
        )
        #expect(omittedUnit.quantityText == "80")
        #expect(omittedUnit.unitID == grams.id)

        let ambiguous = RecipieImportMapper.ingredient(
            ExtractedRecipieIngredient(sourceText: source, name: "flour", quantity: "80g", unit: nil),
            items: [], units: [grams, meal_planner_ios.Unit(name: "other grams", type: .weight, magnitudes: grams.magnitudes)]
        )
        #expect(ambiguous.quantityText == "80g")
        #expect(ambiguous.unitID == nil)

        let mismatch = RecipieImportMapper.ingredient(
            ExtractedRecipieIngredient(sourceText: source, name: "flour", quantity: "80g", unit: "kg"),
            items: [], units: [grams]
        )
        #expect(mismatch.quantityText == "80g")
        #expect(mismatch.quantity(units: [grams]) == nil)
    }

    @MainActor
    @Test func mappingUsesCatalogueMagnitudesAndPreservesUnmatchedLines() {
        let category = Category(name: "dairy", order: 0)
        let milk = Item(name: "Milk", category: category, kind: .ingredient)
        let litres = volumeUnit()
        let mapped = RecipieImportMapper.ingredient(
            ExtractedRecipieIngredient(sourceText: "500 ml milk, warmed", name: " milk ", quantity: "500", unit: "ml"),
            items: [milk], units: [litres]
        )
        #expect(mapped.itemID == milk.id)
        #expect(mapped.unitID == litres.id)
        #expect(mapped.quantity(units: [litres]) == 0.5)
        #expect(mapped.sourceText == "500 ml milk, warmed")
        #expect(mapped.isResolved(items: [milk], units: [litres]))

        let unknown = RecipieImportMapper.ingredient(
            ExtractedRecipieIngredient(sourceText: "salt to taste", name: "salt", quantity: nil, unit: nil),
            items: [milk], units: [litres]
        )
        #expect(unknown.itemID == nil)
        #expect(unknown.unitID == nil)
        #expect(unknown.quantityText.isEmpty)
        #expect(unknown.sourceText == "salt to taste")
    }

    @MainActor
    @Test func ambiguousMatchesRequireReview() {
        let category = Category(name: "dairy", order: 0)
        let milk = Item(name: "milk", category: category, kind: .ingredient)
        let duplicate = Item(name: "MILK", category: category, kind: .ingredient)
        let mapped = RecipieImportMapper.ingredient(
            ExtractedRecipieIngredient(sourceText: "1 litre milk", name: "milk", quantity: "1", unit: "litre"),
            items: [milk, duplicate], units: [volumeUnit(), volumeUnit()]
        )
        #expect(mapped.itemID == nil)
        #expect(mapped.unitID == nil)
    }

    @MainActor
    @Test func applyingImportKeepsMissingFieldsAndReplacesPresentLists() {
        var draft = RecipieDraft(.lunch, .starter)
        draft.name = "Original recipe"
        draft.serves = 5
        draft.time = 40
        draft.steps = ["Old step"]
        let extracted = ExtractedRecipie(isRecipe: true, name: "New recipe", summary: nil, serves: nil,
                                        cookingMinutes: nil, ingredients: [], steps: ["First step", "Second step"])
        RecipieImportMapper.apply(extracted, to: &draft, items: [], units: [])
        #expect(draft.name == "New recipe")
        #expect(draft.serves == 5)
        #expect(draft.time == 40)
        #expect(draft.mealType == .lunch)
        #expect(draft.course == .starter)
        #expect(draft.steps == ["First step", "Second step"])
        #expect(draft.importedIngredients == nil)
    }

    @MainActor
    @Test func importedRecipeUsesItemSavedByPickerAndPreservesSourceText() throws {
        let context = try makeContext()
        let category = Category(name: "dairy", order: 0)
        let unit = volumeUnit()
        context.insert(category)
        context.insert(unit)
        try context.save()
        let itemStore = ItemStore(context: context)
        var itemDraft = try itemStore.newDraft()
        itemDraft.name = "milk"
        itemDraft.dietary.dairy = true
        try itemStore.save(itemDraft, id: nil)
        let item = try #require(context.fetch(FetchDescriptor<Item>()).first)
        var draft = RecipieDraft()
        draft.name = "Milk soup"
        var ingredient = ImportedRecipieIngredient(sourceText: "½ litre milk, warmed", name: "milk", quantityText: "½")
        ingredient.unitID = unit.id
        ingredient.itemID = item.id
        draft.importedIngredients = [ingredient]
        #expect(try ModelContext(context.container).fetch(FetchDescriptor<Item>()).count == 1)
        try RecipieStore(context: context).save(draft, id: nil)

        let verification = ModelContext(context.container)
        let recipe = try #require(verification.fetch(FetchDescriptor<Recipie>()).first)
        #expect(recipe.ingredients.count == 1)
        #expect(recipe.ingredients.first?.quantity == 0.5)
        #expect(recipe.ingredients.first?.sourceText == "½ litre milk, warmed")
        #expect(recipe.ingredients.first?.item.dietary == [.dairy])
        #expect(try verification.fetch(FetchDescriptor<Item>()).count == 1)
        #expect(try RecipieStore(context: verification).draft(id: recipe.id).ingredients.first?.sourceText == ingredient.sourceText)
    }

    @MainActor
    @Test func failedImportKeepsNewItemButDoesNotChangeExistingRecipe() throws {
        let context = try makeContext()
        let category = Category(name: "dairy", order: 0)
        let unit = volumeUnit()
        let recipe = Recipie(name: "Original recipe", steps: ["Keep this step"])
        context.insert(category)
        context.insert(unit)
        context.insert(recipe)
        try context.save()
        let itemStore = ItemStore(context: context)
        var itemDraft = try itemStore.newDraft()
        itemDraft.name = "milk"
        try itemStore.save(itemDraft, id: nil)
        let item = try #require(context.fetch(FetchDescriptor<Item>()).first)
        var draft = RecipieDraft(recipie: recipe)
        draft.name = "Changed recipe"
        var valid = ImportedRecipieIngredient(sourceText: "1 litre milk", name: "milk", quantityText: "1")
        valid.itemID = item.id
        valid.unitID = unit.id
        let unresolved = ImportedRecipieIngredient(sourceText: "salt to taste", name: "salt", quantityText: "")
        draft.importedIngredients = [valid, unresolved]
        #expect(throws: RecipieStore.Error.self) { try RecipieStore(context: context).save(draft, id: recipe.id) }
        let verification = ModelContext(context.container)
        #expect(try verification.fetch(FetchDescriptor<Item>()).map(\.id) == [item.id])
        let persisted = try #require(verification.fetch(Recipie.descriptor(id: recipe.id)).first)
        #expect(persisted.name == "Original recipe")
        #expect(persisted.steps == ["Keep this step"])
    }

    @MainActor
    @Test func visionReadsARecipePhoto() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1000))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 1000))
            let text = "CARROT SOUP\nServes 2\nIngredients\n200 g carrots\n500 ml milk\nSteps\n1. Chop the carrots.\n2. Simmer with milk for 20 minutes."
            (text as NSString).draw(in: CGRect(x: 80, y: 80, width: 1040, height: 840), withAttributes: [
                .font: UIFont.systemFont(ofSize: 44), .foregroundColor: UIColor.black
            ])
        }
        let data = try #require(image.pngData())
        let prepared = try RecipieImportImage.prepare(data)
        let text = try await VisionRecipieTextRecognizer().text(from: prepared)
        #expect(text.localizedCaseInsensitiveContains("carrot soup"))
        #expect(text.contains("500"))
        #expect(text.localizedCaseInsensitiveContains("milk"))
    }

    @MainActor
    @Test func extractionPreservesPageOrderAndPublishesOnlyCompletedResult() async throws {
        let extractor = RecordingExtractor()
        let model = RecipieImportModel(recognizer: FixtureRecognizer(), extractor: extractor)
        model.pages = [page("ingredients"), page("instructions")]
        let operation = try #require(model.extract())
        #expect(model.result == nil)
        await operation.value
        #expect(await extractor.input == "Page 1\ningredients\n\nPage 2\ninstructions")
        #expect(model.result?.name == "Fixture recipe")
        #expect(model.error == nil)
        #expect(!model.isBusy)
    }

    @MainActor
    @Test func unreadablePageDoesNotProduceAPartialImport() async throws {
        let extractor = RecordingExtractor()
        let model = RecipieImportModel(recognizer: FixtureRecognizer(), extractor: extractor)
        model.pages = [page("ingredients"), page("")]
        let operation = try #require(model.extract())
        await operation.value
        #expect(await extractor.input == nil)
        #expect(model.result == nil)
        #expect(model.error != nil)
        #expect(model.pages.count == 2)
        #expect(!model.isBusy)
    }

    @MainActor
    @Test func cancellingImportIgnoresLateExtractionResults() async throws {
        let extractor = SuspendedExtractor()
        let model = RecipieImportModel(recognizer: FixtureRecognizer(), extractor: extractor)
        model.pages = [page("ingredients")]
        let operation = try #require(model.extract())
        await extractor.waitUntilStarted()
        model.cancel()
        await extractor.complete()
        await operation.value
        #expect(model.result == nil)
        #expect(model.error == nil)
        #expect(!model.isBusy)
        #expect(model.pages.count == 1)
    }

    @MainActor
    private func page(_ text: String) -> RecipieImportPage {
        RecipieImportPage(data: Data(text.utf8), thumbnail: UIImage())
    }

    @Test(.enabled(if: SystemLanguageModel.default.availability == .available,
                   "Requires Apple Intelligence on the simulator host"))
    func foundationModelsExtractsRecipeText() async throws {
        let result = try await FoundationRecipieExtractor().extract(from: """
            Carrot soup
            Serves 2
            Cooking time: 20 minutes
            Ingredients:
            200 g carrots
            500 ml milk
            Method:
            1. Chop the carrots.
            2. Simmer the carrots in the milk for 20 minutes.
            """
        )
        #expect(result.isRecipe)
        #expect(result.serves == 2)
        #expect(result.ingredients.count == 2)
        #expect(!result.steps.isEmpty)
    }

    private func volumeUnit() -> meal_planner_ios.Unit {
        Unit(name: "litres", type: .volume, magnitudes: [
            Magnitude(abbreviation: "ml", singular: "millilitre", plural: "millilitres", multiplier: 0.001),
            Magnitude(abbreviation: "l", singular: "litre", plural: "litres", multiplier: 1)
        ])
    }

    @MainActor
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: Category.self, Unit.self, Item.self, RecipieIngredient.self, Recipie.self,
                                          configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }
}

private struct FixtureRecognizer: RecipieTextRecognizing {
    func text(from imageData: Data) async throws -> String { String(decoding: imageData, as: UTF8.self) }
}

private actor RecordingExtractor: RecipieExtracting {
    private(set) var input: String?
    func extract(from text: String) async throws -> ExtractedRecipie {
        input = text
        return fixtureRecipe()
    }
}

private actor SuspendedExtractor: RecipieExtracting {
    private var continuation: CheckedContinuation<ExtractedRecipie, Never>?
    private var started: CheckedContinuation<Void, Never>?

    func extract(from text: String) async throws -> ExtractedRecipie {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        if continuation != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func complete() {
        continuation?.resume(returning: fixtureRecipe())
        continuation = nil
    }
}

private func fixtureRecipe() -> ExtractedRecipie {
    ExtractedRecipie(isRecipe: true, name: "Fixture recipe", summary: nil, serves: 2,
                    cookingMinutes: 20, ingredients: [], steps: ["Cook the ingredients."])
}
