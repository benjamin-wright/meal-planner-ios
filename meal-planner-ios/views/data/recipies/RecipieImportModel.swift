import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

struct RecipieImportPage: Identifiable {
    let id = UUID()
    let data: Data
    let thumbnail: UIImage
}

@MainActor
@Observable
final class RecipieImportModel {
    static let maximumPages = RecipieImportPipeline.maximumPages
    var pages: [RecipieImportPage] = []
    var pdfPages: [RecipiePDFPage] = []
    private(set) var pdfFileName: String?
    private(set) var progress: LocalizedStringResource?
    var error: String?
    var result: ExtractedRecipie?
    private var operation: Task<Void, Never>?
    private var operationID: UUID?
    private let recognizer: any RecipieTextRecognizing
    private let extractor: any RecipieExtracting
    private let ingredientSelector: any RecipieIngredientSelecting

    var isBusy: Bool { progress != nil }

    init(recognizer: any RecipieTextRecognizing = VisionRecipieTextRecognizer(),
         extractor: any RecipieExtracting = FoundationRecipieExtractor(),
         ingredientSelector: any RecipieIngredientSelecting = FoundationRecipieIngredientSelector()) {
        self.recognizer = recognizer
        self.extractor = extractor
        self.ingredientSelector = ingredientSelector
    }

    func load(_ selection: [PhotosPickerItem]) {
        guard !selection.isEmpty, !isBusy else { return }
        start(progress: "Loading photos…") {
            guard self.pages.count + selection.count <= Self.maximumPages else { throw RecipieImportError.tooManyPages }
            var prepared: [RecipieImportPage] = []
            for photo in selection {
                try Task.checkCancellation()
                guard let image = try await photo.loadTransferable(type: Data.self) else { throw RecipieImportError.unreadableImage }
                // Release each full-sized asset before loading the next one.
                prepared.append(contentsOf: try await self.prepare([image]))
            }
            return prepared
        }
    }

    func addScans(_ images: [Data]) {
        guard !images.isEmpty, !isBusy else { return }
        start(progress: "Loading photos…") { try await self.prepare(images) }
    }

    @discardableResult
    func loadPDF(from url: URL) -> Task<Void, Never>? {
        guard !isBusy else { return nil }
        let id = UUID()
        operationID = id
        progress = "Loading PDF…"
        error = nil
        result = nil
        operation = Task {
            defer { finish(id) }
            do {
                let loadedPages = try await RecipiePDFImport.load(from: url)
                try Task.checkCancellation()
                guard operationID == id else { return }
                pdfPages = loadedPages
                pdfFileName = url.lastPathComponent
            } catch is CancellationError { } catch {
                if operationID == id { self.error = error.localizedDescription }
            }
        }
        return operation
    }

    private func prepare(_ images: [Data]) async throws -> [RecipieImportPage] {
        guard pages.count + images.count <= Self.maximumPages else { throw RecipieImportError.tooManyPages }
        var prepared: [RecipieImportPage] = []
        for image in images {
            try Task.checkCancellation()
            let data = try await Task.detached(priority: .userInitiated) {
                try RecipieImportImage.prepare(image)
            }.value
            try Task.checkCancellation()
            let thumbnail = UIImage(cgImage: try RecipieImportImage.thumbnail(data))
            prepared.append(RecipieImportPage(data: data, thumbnail: thumbnail))
        }
        return prepared
    }

    private func start(progress: LocalizedStringResource, load: @escaping @MainActor () async throws -> [RecipieImportPage]) {
        let id = UUID()
        operationID = id
        self.progress = progress
        error = nil
        operation = Task {
            defer { finish(id) }
            do {
                let added = try await load()
                try Task.checkCancellation()
                guard operationID == id else { return }
                pages.append(contentsOf: added)
            } catch is CancellationError { } catch {
                if operationID == id { self.error = error.localizedDescription }
            }
        }
    }

    @discardableResult
    func extract(catalogue: [RecipieIngredientCatalogEntry] = []) -> Task<Void, Never>? {
        guard !pages.isEmpty, !isBusy else { return nil }
        let sourcePages = pages
        return startExtraction(catalogue: catalogue, progress: "Reading photos…") {
            try await RecipieImportPipeline.recognize(pages: sourcePages.map(\.data), recognizer: self.recognizer) { page in
                if !Task.isCancelled {
                    self.progress = "Reading photo \(page) of \(sourcePages.count)…"
                }
            }
        }
    }

    @discardableResult
    func extractPDF(catalogue: [RecipieIngredientCatalogEntry] = []) -> Task<Void, Never>? {
        guard !pdfPages.isEmpty, !isBusy else { return nil }
        let sourcePages = pdfPages
        return startExtraction(catalogue: catalogue, progress: "Reading PDF…") {
            try RecipiePDFImport.text(from: sourcePages)
        }
    }

    private func startExtraction(catalogue: [RecipieIngredientCatalogEntry],
                                 progress: LocalizedStringResource,
                                 readText: @escaping @MainActor () async throws -> String) -> Task<Void, Never>? {
        let id = UUID()
        operationID = id
        self.progress = progress
        error = nil
        result = nil
        operation = Task {
            defer { finish(id) }
            do {
                let text = try await readText()
                try Task.checkCancellation()
                guard operationID == id else { return }
                self.progress = "Extracting recipe…"
                let extracted = try await extractor.extract(from: text)
                try Task.checkCancellation()
                guard operationID == id else { return }
                let matched = try await RecipieIngredientMatching.matching(
                    extracted, catalogue: catalogue, selector: ingredientSelector
                ) { current, total in
                    if operationID == id { self.progress = "Matching ingredient \(current) of \(total)…" }
                }
                try Task.checkCancellation()
                guard operationID == id else { return }
                result = matched
            } catch is CancellationError { } catch {
                if operationID == id { self.error = error.localizedDescription }
            }
        }
        return operation
    }

    func cancel() {
        operationID = nil
        operation?.cancel()
        operation = nil
        progress = nil
    }

    private func finish(_ id: UUID) {
        guard operationID == id else { return }
        operation = nil
        operationID = nil
        progress = nil
    }
}
