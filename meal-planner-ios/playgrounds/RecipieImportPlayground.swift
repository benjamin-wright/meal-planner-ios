#if DEBUG
import Foundation
import Playgrounds
import UIKit

// Only the image inputs belong here. Tune the app's shared services and schemas.
#Playground("Recipe images to ingredients and steps") {
    let imagePaths = [
        "E13AC9D2-CD25-4FBE-BBE0-76A1520FD80B_1_201_a.heic",
        "8A850FEE-A263-4732-9679-54B5EA1E6475.heic"
    ]
    guard imagePaths.count <= RecipieImportPipeline.maximumPages else { throw RecipieImportError.tooManyPages }
    let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let originalData = try imagePaths.map { try Data(contentsOf: directory.appendingPathComponent($0)) }
    let originalImages = originalData.compactMap { UIImage(data: $0) }
    let preparedData = try originalData.map { try RecipieImportImage.prepare($0) }
    let preparedImages = preparedData.compactMap { UIImage(data: $0) }
    let started = ContinuousClock.now
    let text = try await RecipieImportPipeline.recognize(pages: preparedData)
    print(text)
    let recipe = try await RecipiePlaygroundSupport.withoutAutomaticModelFeedback {
        try await FoundationRecipieExtractor().extract(from: text, preservingGenerationErrors: true)
    }
    let elapsed = started.duration(to: .now)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let recipeJSON = String(decoding: try encoder.encode(recipe), as: UTF8.self)
    print(recipeJSON)
    print("OCR and extraction: \(elapsed)")
    // Keep these as named values for expandable canvas image previews.
    _ = originalImages
    _ = preparedImages
}
#endif
