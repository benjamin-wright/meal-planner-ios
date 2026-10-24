import CoreGraphics
import Foundation
import ImageIO
import PDFKit

/// Transient import data. The source PDF and its security-scoped URL are never retained.
struct RecipiePDFPage: Sendable {
    let pageNumber: Int
    let text: String
    let thumbnailData: Data
}

enum RecipiePDFImportError: LocalizedError, Equatable {
    case unreadablePDF
    case lockedPDF
    case emptyPDF
    case unreadablePage(pageNumber: Int)
    case noPagesSelected
    case tooManyPages
    case noText(pageNumber: Int)
    case textTooLong

    var errorDescription: String? {
        switch self {
        case .unreadablePDF:
            return "The PDF could not be opened. Make sure it has downloaded in Files, or choose another PDF."
        case .lockedPDF:
            return "This PDF is password-protected. Choose an unlocked copy to import the recipe."
        case .emptyPDF:
            return "This PDF has no pages. Choose a PDF containing a recipe."
        case .unreadablePage(let pageNumber):
            return "Page \(pageNumber) of this PDF could not be read. Choose another copy of the PDF."
        case .noPagesSelected:
            return "Keep at least one PDF page to extract the recipe."
        case .tooManyPages:
            return "Keep up to \(RecipieImportPipeline.maximumPages) PDF pages. Remove any pages that are not part of the recipe."
        case .noText(let pageNumber):
            return "Page \(pageNumber) has no extractable text. Remove that page or choose a PDF with selectable text. Scanned PDFs are not supported yet."
        case .textTooLong:
            return "The selected PDF pages exceed the \(RecipieImportPipeline.maximumTextCharacters.formatted())-character limit. Remove pages to shorten the recipe."
        }
    }
}

enum RecipiePDFImport {
    private static let maximumThumbnailDimension = 480

    /// File provider access, PDF parsing, and rendering all run away from the UI actor.
    @concurrent
    static func load(from url: URL) async throws -> [RecipiePDFPage] {
        try Task.checkCancellation()
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }

        let coordinator = NSFileCoordinator()
        let cancellation = FileCoordinationCancellation(coordinator: coordinator)
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            var result: Result<[RecipiePDFPage], Error>?
            var coordinationError: NSError?
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { readableURL in
                result = Result {
                    try Task.checkCancellation()
                    let data: Data
                    do {
                        data = try Data(contentsOf: readableURL, options: .mappedIfSafe)
                    } catch {
                        throw RecipiePDFImportError.unreadablePDF
                    }
                    return try read(data: data)
                }
            }
            try Task.checkCancellation()
            guard coordinationError == nil, let result else {
                throw RecipiePDFImportError.unreadablePDF
            }
            return try result.get()
        } onCancel: {
            cancellation.cancel()
        }
    }

    /// Read every page so unwanted pages can be removed before applying import limits.
    static func read(data: Data) throws -> [RecipiePDFPage] {
        try Task.checkCancellation()
        return try autoreleasepool {
            guard let document = PDFDocument(data: data) else {
                throw RecipiePDFImportError.unreadablePDF
            }
            guard !document.isLocked else { throw RecipiePDFImportError.lockedPDF }
            guard document.pageCount > 0 else { throw RecipiePDFImportError.emptyPDF }

            var pages: [RecipiePDFPage] = []
            for index in 0..<document.pageCount {
                try Task.checkCancellation()
                let page = try autoreleasepool {
                    guard let page = document.page(at: index) else {
                        throw RecipiePDFImportError.unreadablePage(pageNumber: index + 1)
                    }
                    return RecipiePDFPage(
                        pageNumber: index + 1,
                        text: embeddedText(from: page),
                        thumbnailData: try thumbnail(for: page, pageNumber: index + 1)
                    )
                }
                pages.append(page)
            }
            try Task.checkCancellation()
            return pages
        }
    }

    /// Validation is deliberately separate from loading: empty or extra pages stay visible.
    static func text(from pages: [RecipiePDFPage]) throws -> String {
        guard !pages.isEmpty else { throw RecipiePDFImportError.noPagesSelected }
        guard pages.count <= RecipieImportPipeline.maximumPages else {
            throw RecipiePDFImportError.tooManyPages
        }
        let sections = try pages.map { page in
            let text = page.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw RecipiePDFImportError.noText(pageNumber: page.pageNumber) }
            return "Page \(page.pageNumber)\n\(text)"
        }
        let text = sections.joined(separator: "\n\n")
        guard text.count <= RecipieImportPipeline.maximumTextCharacters else {
            throw RecipiePDFImportError.textTooLong
        }
        return text
    }

    struct TextFragment {
        let text: String
        let bounds: CGRect
    }

    private static func embeddedText(from page: PDFPage) -> String {
        let text = page.string ?? ""
        guard page.numberOfCharacters > 0,
              let selection = page.selection(for: NSRange(location: 0, length: page.numberOfCharacters)) else {
            return text.replacingOccurrences(of: "\u{FFFC}", with: "")
        }
        let fragments = selection.selectionsByLine().map {
            TextFragment(text: $0.string ?? "", bounds: $0.bounds(for: page))
        }
        return normalizedText(text, fragments: fragments)
    }

    /// PDFKit can insert newlines between styled runs on one visual line. Match whole
    /// selection strings instead of character indices: PDFKit's glyph bounds and string
    /// offsets can disagree around its inserted newlines and Unicode characters.
    static func normalizedText(_ source: String, fragments: [TextFragment]) -> String {
        let text = source.replacingOccurrences(of: "\u{FFFC}", with: "")
        var cursor = text.startIndex
        var previous: CGRect?
        var result = ""
        for fragment in fragments {
            let fragmentText = fragment.text.replacingOccurrences(of: "\u{FFFC}", with: "")
            guard !fragmentText.isEmpty else { continue }
            guard let range = text.range(of: fragmentText, options: .literal, range: cursor..<text.endIndex) else {
                return text
            }
            let gap = text[cursor..<range.lowerBound]
            // If selections omit or reorder any text, preserve the complete original.
            guard gap.allSatisfy(\.isWhitespace) else { return text }
            if let previous, gap.contains(where: \.isNewline),
               continuesSameLine(from: previous, to: fragment.bounds) {
                result += gap.filter { !$0.isNewline }
            } else {
                result += gap
            }
            result += fragmentText
            cursor = range.upperBound
            previous = fragment.bounds
        }
        let suffix = text[cursor...]
        guard suffix.allSatisfy(\.isWhitespace) else { return text }
        return result + suffix
    }

    private static func continuesSameLine(from left: CGRect, to right: CGRect) -> Bool {
        guard !left.isEmpty, !right.isEmpty,
              [left.minX, left.minY, left.maxX, left.maxY,
               right.minX, right.minY, right.maxX, right.maxY].allSatisfy(\.isFinite) else { return false }
        // Touching runs with the same vertical extent give direct layout evidence.
        // Wider gaps, different lines, superscripts, and columns remain untouched.
        let tolerance: CGFloat = 0.5
        return abs(left.minY - right.minY) <= tolerance
            && abs(left.maxY - right.maxY) <= tolerance
            && abs(right.minX - left.maxX) <= tolerance
    }

    private static func thumbnail(for page: PDFPage, pageNumber: Int) throws -> Data {
        guard let pageRef = page.pageRef else {
            throw RecipiePDFImportError.unreadablePage(pageNumber: pageNumber)
        }
        let bounds = pageRef.getBoxRect(.cropBox)
        let rotated = pageRef.rotationAngle % 180 != 0
        let size = rotated ? CGSize(width: bounds.height, height: bounds.width) : bounds.size
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
            throw RecipiePDFImportError.unreadablePage(pageNumber: pageNumber)
        }
        let scale = CGFloat(maximumThumbnailDimension) / max(size.width, size.height)
        let width = max(1, Int((size.width * scale).rounded(.down)))
        let height = max(1, Int((size.height * scale).rounded(.down)))
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw RecipiePDFImportError.unreadablePage(pageNumber: pageNumber)
        }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(rect)
        context.concatenate(pageRef.getDrawingTransform(.cropBox, rect: rect, rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(pageRef)

        let data = NSMutableData()
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            throw RecipiePDFImportError.unreadablePage(pageNumber: pageNumber)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw RecipiePDFImportError.unreadablePage(pageNumber: pageNumber)
        }
        return data as Data
    }
}

/// NSFileCoordinator is confined to the reading task. Its cancel method is explicitly
/// safe to call from any thread, so only that operation crosses into the cancel handler.
private struct FileCoordinationCancellation: @unchecked Sendable {
    let coordinator: NSFileCoordinator

    func cancel() {
        coordinator.cancel()
    }
}
