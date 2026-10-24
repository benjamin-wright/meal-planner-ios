import Foundation
import Testing
import UIKit
@testable import meal_planner_ios

struct RecipiePDFImportModelTests {
    @MainActor
    @Test func pdfExtractionBypassesOCRAndUsesSelectedPagesForIngredientMatching() async throws {
        let recognizer = PDFRecordingRecognizer()
        let extractor = PDFRecordingExtractor()
        let cheddar = RecipieIngredientCatalogEntry(itemID: UUID(), name: "cheddar cheese")
        let selector = PDFRecordingIngredientSelector(selection: cheddar.itemID)
        let model = RecipieImportModel(recognizer: recognizer, extractor: extractor, ingredientSelector: selector)
        model.pdfPages = [pdfPage(2, "Ingredients\n50 grams of cheddar"), pdfPage(4, "Method\nMelt the cheese.")]

        let operation = try #require(model.extractPDF(catalogue: [cheddar]))
        #expect(model.result == nil)
        #expect(model.isBusy)
        await operation.value

        #expect(await recognizer.callCount == 0)
        #expect(await extractor.inputs == ["Page 2\nIngredients\n50 grams of cheddar\n\nPage 4\nMethod\nMelt the cheese."])
        #expect(await selector.callCount == 1)
        #expect(await selector.sourceText == "50 grams of cheddar")
        #expect(model.result?.matchedItemIDs[0] == cheddar.itemID)
        #expect(model.result?.name == "Cheese sauce")
        #expect(model.result?.steps == ["Melt the cheese."])
        #expect(model.error == nil)
        #expect(!model.isBusy)
    }

    @MainActor
    @Test(arguments: InvalidPDFSelection.allCases)
    func invalidSelectedPDFPagesStopBeforeExtraction(selection: InvalidPDFSelection) async throws {
        let recognizer = PDFRecordingRecognizer()
        let extractor = PDFRecordingExtractor()
        let selector = PDFRecordingIngredientSelector()
        let model = RecipieImportModel(recognizer: recognizer, extractor: extractor, ingredientSelector: selector)
        model.pdfPages = selection.pages
        model.result = pdfRecipe()

        let operation = try #require(model.extractPDF())
        #expect(model.result == nil)
        await operation.value

        #expect(await recognizer.callCount == 0)
        #expect(await extractor.inputs.isEmpty)
        #expect(await selector.callCount == 0)
        #expect(model.result == nil)
        #expect(model.error == selection.error.localizedDescription)
        #expect(model.pdfPages.map(\.pageNumber) == selection.pages.map(\.pageNumber))
        #expect(!model.isBusy)
    }

    @MainActor
    @Test func removingTextlessPageAllowsRetryWithoutRenumberingRemainingPages() async throws {
        let recognizer = PDFRecordingRecognizer()
        let extractor = PDFRecordingExtractor()
        let model = RecipieImportModel(recognizer: recognizer, extractor: extractor,
                                      ingredientSelector: PDFRecordingIngredientSelector())
        model.pdfPages = [pdfPage(1, "Ingredients"), pdfPage(2, "\n \t"), pdfPage(3, "Method")]

        let failedOperation = try #require(model.extractPDF())
        await failedOperation.value
        #expect(model.error == RecipiePDFImportError.noText(pageNumber: 2).localizedDescription)
        #expect(await extractor.inputs.isEmpty)

        model.pdfPages.remove(at: 1)
        let retry = try #require(model.extractPDF())
        #expect(model.error == nil)
        await retry.value

        #expect(await extractor.inputs == ["Page 1\nIngredients\n\nPage 3\nMethod"])
        #expect(await recognizer.callCount == 0)
        #expect(model.result?.name == "Cheese sauce")
        #expect(model.error == nil)
        #expect(!model.isBusy)
    }

    @MainActor
    @Test func cancellingPDFImportDiscardsLateExtractionResult() async throws {
        let recognizer = PDFRecordingRecognizer()
        let extractor = PDFSuspendedExtractor()
        let selector = PDFRecordingIngredientSelector()
        let model = RecipieImportModel(recognizer: recognizer, extractor: extractor, ingredientSelector: selector)
        model.pdfPages = [pdfPage(1, "Ingredients\n50 grams of cheddar")]

        let operation = try #require(model.extractPDF())
        await extractor.waitUntilStarted()
        model.cancel()
        #expect(!model.isBusy)
        await extractor.complete()
        await operation.value

        #expect(model.result == nil)
        #expect(model.error == nil)
        #expect(!model.isBusy)
        #expect(model.pdfPages.map(\.pageNumber) == [1])
        #expect(await recognizer.callCount == 0)
        #expect(await selector.callCount == 0)
    }

    @MainActor
    @Test func loadingAnotherPDFReplacesTheDocumentAndClearsThePreviousResult() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstURL = directory.appendingPathComponent("first.pdf")
        let secondURL = directory.appendingPathComponent("second.pdf")
        try makePDF(["First recipe ingredients", "First recipe instructions"]).write(to: firstURL)
        try makePDF(["Second recipe ingredients"]).write(to: secondURL)
        let recognizer = PDFRecordingRecognizer()
        let extractor = PDFRecordingExtractor()
        let model = RecipieImportModel(recognizer: recognizer, extractor: extractor,
                                      ingredientSelector: PDFRecordingIngredientSelector())

        let firstLoad = try #require(model.loadPDF(from: firstURL))
        await firstLoad.value
        #expect(model.error == nil)
        #expect(model.pdfPages.count == 2)
        #expect(model.pdfFileName == "first.pdf")
        model.result = pdfRecipe()

        let secondLoad = try #require(model.loadPDF(from: secondURL))
        #expect(model.result == nil)
        await secondLoad.value

        #expect(model.error == nil)
        #expect(model.pdfFileName == "second.pdf")
        #expect(model.pdfPages.map(\.pageNumber) == [1])
        #expect(model.pdfPages.first?.text.contains("Second recipe ingredients") == true)
        #expect(model.pdfPages.first?.text.contains("First recipe") == false)
        #expect(model.pdfPages.first?.thumbnailData.isEmpty == false)
        #expect(await recognizer.callCount == 0)
        #expect(await extractor.inputs.isEmpty)
        #expect(!model.isBusy)
    }

    @MainActor
    private func makePDF(_ pageTexts: [String]) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 300, height: 400)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            for text in pageTexts {
                context.beginPage()
                (text as NSString).draw(in: bounds.insetBy(dx: 20, dy: 20), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 18), .foregroundColor: UIColor.black
                ])
            }
        }
    }
}

enum InvalidPDFSelection: CaseIterable {
    case textlessPage, tooManyPages, tooMuchText

    var pages: [RecipiePDFPage] {
        switch self {
        case .textlessPage:
            [pdfPage(1, "Ingredients"), pdfPage(7, " \n\t "), pdfPage(9, "Method")]
        case .tooManyPages:
            (1...7).map { pdfPage($0, "Recipe text") }
        case .tooMuchText:
            [pdfPage(1, String(repeating: "a", count: 6_001))]
        }
    }

    var error: RecipiePDFImportError {
        switch self {
        case .textlessPage: .noText(pageNumber: 7)
        case .tooManyPages: .tooManyPages
        case .tooMuchText: .textTooLong
        }
    }
}

private func pdfPage(_ number: Int, _ text: String) -> RecipiePDFPage {
    RecipiePDFPage(pageNumber: number, text: text, thumbnailData: Data())
}

private func pdfRecipe() -> ExtractedRecipie {
    ExtractedRecipie(isRecipe: true, name: "Cheese sauce", summary: nil, serves: 2,
                    cookingMinutes: 5,
                    ingredients: [ExtractedRecipieIngredient(sourceText: "50 grams of cheddar", name: "cheddar",
                                                            quantity: 50, unit: "grams")],
                    steps: ["Melt the cheese."])
}

private actor PDFRecordingRecognizer: RecipieTextRecognizing {
    private(set) var callCount = 0

    func text(from imageData: Data) async throws -> String {
        callCount += 1
        return "Unexpected OCR text"
    }
}

private actor PDFRecordingExtractor: RecipieExtracting {
    private(set) var inputs: [String] = []

    func extract(from text: String) async throws -> ExtractedRecipie {
        inputs.append(text)
        return pdfRecipe()
    }
}

private actor PDFRecordingIngredientSelector: RecipieIngredientSelecting {
    private(set) var callCount = 0
    private(set) var sourceText: String?
    let selection: UUID?

    init(selection: UUID? = nil) { self.selection = selection }

    func select(for ingredient: ExtractedRecipieIngredient, recipeName: String?,
                from candidates: [RecipieIngredientCandidate]) async throws -> UUID? {
        callCount += 1
        sourceText = ingredient.sourceText
        return selection
    }
}

private actor PDFSuspendedExtractor: RecipieExtracting {
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
        continuation?.resume(returning: pdfRecipe())
        continuation = nil
    }
}
