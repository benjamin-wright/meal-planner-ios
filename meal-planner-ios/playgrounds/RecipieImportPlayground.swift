#if DEBUG
import Foundation
import FoundationModels
import Playgrounds
import UIKit
import Vision

// Open Editor > Canvas, choose an iOS simulator, and run either playground.
// These experiments call the same services as RecipieImportView without saving a recipe.

#Playground("Recipe extraction from text") {
    // Edit the saved OCR snapshot to iterate on extraction without rerunning image processing.
    let snapshotURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("RecipieImportOCR.txt")
    let text = try String(contentsOf: snapshotURL, encoding: .utf8)
    let instructions = FoundationRecipieExtractor.defaultInstructions
    let promptPrefix = FoundationRecipieExtractor.defaultPromptPrefix
    let options = GenerationOptions(temperature: 0)
    // Other options: sampling: .greedy, maximumResponseTokens: 1_000.

    let availability = SystemLanguageModel.default.availability
    print("Model availability: \(availability)")
    print("Instructions:\n\(instructions)")
    print("Prompt:\n\(promptPrefix + text)")
    if availability == .available {
        let extractor = FoundationRecipieExtractor(
            instructions: instructions, promptPrefix: promptPrefix, options: options
        )
        let started = ContinuousClock.now
        do {
            let recipe = try await extractor.extract(from: text, preservingGenerationErrors: true)
            print("Extraction time: \(started.duration(to: .now))")
            dump(recipe)
        } catch {
            print("Extraction failed after \(started.duration(to: .now))")
            print("Model error: \(String(reflecting: error))")
        }
    }
}

#Playground("Recipe image preparation and OCR") {
    // Resolve the test photos beside this source file when running on a simulator.
    // Ingredients first, then instructions. Clear imagePaths to use the generated fixture.
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let imagePaths = [
        directory.appendingPathComponent("E13AC9D2-CD25-4FBE-BBE0-76A1520FD80B_1_201_a.heic").path,
        directory.appendingPathComponent("8A850FEE-A263-4732-9679-54B5EA1E6475.heic").path
    ]
    let maximumPixelSize = 2_400
    let compressionQuality = 0.9
    var ocrOptions = VisionRecipieTextRecognizer.defaultTextRecognitionOptions
    ocrOptions.automaticallyDetectLanguage = true
    // Try ocrOptions.useLanguageCorrection, .customWords, or .recognitionLanguages.
    let extractRecipe = false // Enable to run the full photo-to-recipe pipeline.
    let extractor = FoundationRecipieExtractor()

    guard imagePaths.count <= RecipieImportModel.maximumPages else {
        throw RecipieImportError.tooManyPages
    }
    let recognizer = VisionRecipieTextRecognizer(textRecognitionOptions: ocrOptions)
    let pageCount = max(1, imagePaths.count)
    var pageTexts: [String] = []
    for index in 0..<pageCount {
        try Task.checkCancellation()
        let data = imagePaths.isEmpty
            ? try RecipieImportPlaygroundFixture.image()
            : try Data(contentsOf: URL(fileURLWithPath: imagePaths[index]))
        let originalImage = UIImage(data: data)
        let prepared = try RecipieImportImage.prepare(
            data, maximumPixelSize: maximumPixelSize, compressionQuality: compressionQuality
        )
        let preparedImage = UIImage(data: prepared)
        // Expand these image variables in the canvas to inspect the preparation result.
        print("Photo \(index + 1): \(String(describing: originalImage?.size)) → \(String(describing: preparedImage?.size))")
        print("Image bytes: \(data.count) → \(prepared.count)")
        let started = ContinuousClock.now
        let text = try await recognizer.text(from: prepared)
        print("OCR time: \(started.duration(to: .now))")
        guard !text.isEmpty else { throw RecipieImportError.noText(index + 1) }
        pageTexts.append("Page \(index + 1)\n\(text)")
    }
    let text = pageTexts.joined(separator: "\n\n")
    print("OCR text (copy into RecipieImportOCR.txt to refresh the text playground):\n\(text)")

    if extractRecipe {
        let availability = SystemLanguageModel.default.availability
        print("Model availability: \(availability)")
        if availability == .available {
            let started = ContinuousClock.now
            do {
                let recipe = try await extractor.extract(from: text, preservingGenerationErrors: true)
                print("Extraction time: \(started.duration(to: .now))")
                dump(recipe)
            } catch {
                print("Extraction failed after \(started.duration(to: .now))")
                print("Model error: \(String(reflecting: error))")
            }
        }
    }
}

private enum RecipieImportPlaygroundFixture {
    static let text = """
        Carrot soup
        Serves 2
        Cooking time: 20 minutes
        Ingredients:
        200 g carrots
        500 ml milk
        Method:
        1. Chop the carrots
        into small pieces so they cook evenly.
        2. Simmer the carrots in the milk
        for 20 minutes, stirring occasionally.
        """

    @MainActor
    static func image() throws -> Data {
        let size = CGSize(width: 1_200, height: 1_000)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            (text as NSString).draw(in: CGRect(x: 60, y: 60, width: 1_080, height: 880), withAttributes: [
                .font: UIFont.systemFont(ofSize: 38), .foregroundColor: UIColor.black
            ])
        }
        guard let data = image.pngData() else { throw RecipieImportError.unreadableImage }
        return data
    }
}
#endif
