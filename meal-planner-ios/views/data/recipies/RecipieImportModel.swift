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
    private(set) var progress: LocalizedStringResource?
    var error: String?
    var result: ExtractedRecipie?
    private var operation: Task<Void, Never>?
    private var operationID: UUID?
    private let recognizer: any RecipieTextRecognizing
    private let extractor: any RecipieExtracting

    var isBusy: Bool { progress != nil }

    init(recognizer: any RecipieTextRecognizing = VisionRecipieTextRecognizer(),
         extractor: any RecipieExtracting = FoundationRecipieExtractor()) {
        self.recognizer = recognizer
        self.extractor = extractor
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
    func extract() -> Task<Void, Never>? {
        guard !pages.isEmpty, !isBusy else { return nil }
        let id = UUID()
        operationID = id
        progress = "Reading photos…"
        error = nil
        let sourcePages = pages
        operation = Task {
            defer { finish(id) }
            do {
                let text = try await RecipieImportPipeline.recognize(pages: sourcePages.map(\.data), recognizer: recognizer) { page in
                    if operationID == id { progress = "Reading photo \(page) of \(sourcePages.count)…" }
                }
                try Task.checkCancellation()
                guard operationID == id else { return }
                progress = "Extracting recipe…"
                let extracted = try await extractor.extract(from: text)
                try Task.checkCancellation()
                guard operationID == id else { return }
                result = extracted
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
