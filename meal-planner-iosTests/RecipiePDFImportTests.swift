import Foundation
import ImageIO
import PDFKit
import Testing
import UIKit
@testable import meal_planner_ios

struct RecipiePDFImportTests {
    @MainActor
    @Test func readsEmbeddedTextInPageAndLineOrderWithBoundedPreviews() throws {
        let data = fixturePDF([
            "Carrot soup\nIngredients\n200 g carrots\n500 ml milk",
            "Method\n1. Chop the carrots.\n2. Simmer for 20 minutes."
        ])
        let pages = try RecipiePDFImport.read(data: data)
        #expect(pages.map(\.pageNumber) == [1, 2])
        let text = try RecipiePDFImport.text(from: pages)
        let expectedOrder = ["Carrot soup", "Ingredients", "200 g carrots", "500 ml milk",
                             "Page 2", "Method", "1. Chop the carrots.", "2. Simmer for 20 minutes."]
        var remainder = text[...]
        for line in expectedOrder {
            let range = try #require(remainder.range(of: line))
            remainder = remainder[range.upperBound...]
        }
        for page in pages {
            let source = try #require(CGImageSourceCreateWithData(page.thumbnailData as CFData, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            #expect(image.width > 0 && image.width <= 480)
            #expect(image.height > 0 && image.height <= 480)
        }
    }

    @MainActor
    @Test func loadsAllPagesBeforeApplyingTheSelectedPageLimit() throws {
        let pages = try RecipiePDFImport.read(data: fixturePDF((1...7).map { "Recipe page \($0)" }))
        #expect(pages.count == 7)
        #expect(throws: RecipiePDFImportError.tooManyPages) {
            try RecipiePDFImport.text(from: pages)
        }
        let text = try RecipiePDFImport.text(from: Array(pages.dropFirst()))
        #expect(text.hasPrefix("Page 2\nRecipe page 2"))
        #expect(text.hasSuffix("Page 7\nRecipe page 7"))
        #expect(!text.contains("Recipe page 1"))
    }

    @MainActor
    @Test func keepsIngredientNamesWithBoldAmountRuns() throws {
        let rows = [
            ("Onion", "1 large, chopped"),
            ("Garlic cloves", "2, crushed"),
            ("Carrots", "2 medium, sliced"),
            ("Tinned chopped tomatoes", "400 g"),
            ("Tomato purée", "2 tablespoons"),
            ("Cannellini or butter beans, drained", "1 × 400 g tin"),
            ("Chicken stock", "300 ml"),
            ("Dried thyme or mixed herbs", "1 teaspoon"),
            ("Bay leaf", "1"),
            ("Salt", "to taste")
        ]
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { renderer in
            renderer.beginPage()
            for (index, row) in rows.enumerated() {
                let text = row.0 + " – " + row.1
                let attributed = NSMutableAttributedString(string: text, attributes: [
                    .font: UIFont.systemFont(ofSize: 16), .foregroundColor: UIColor.black
                ])
                attributed.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 16),
                                        range: (text as NSString).range(of: row.1))
                attributed.draw(at: CGPoint(x: 40, y: 40 + index * 30))
            }
        }
        let pages = try RecipiePDFImport.read(data: data)
        let text = RecipieImportMapper.key(try RecipiePDFImport.text(from: pages))
        var remaining = text[...]
        for row in rows {
            let expected = RecipieImportMapper.key(row.0 + " – " + row.1)
            let range = try #require(remaining.range(of: expected))
            remaining = remaining[range.upperBound...]
        }
    }

    @MainActor
    @Test func scannedPagesStayVisibleAndBlockExtractionUntilRemoved() throws {
        let pages = try RecipiePDFImport.read(data: fixturePDF(["Soup ingredients", nil, "Soup method"]))
        #expect(pages.count == 3)
        #expect(pages[1].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(!pages[1].thumbnailData.isEmpty)
        #expect(throws: RecipiePDFImportError.noText(pageNumber: 2)) {
            try RecipiePDFImport.text(from: pages)
        }
        let text = try RecipiePDFImport.text(from: [pages[0], pages[2]])
        #expect(text == "Page 1\nSoup ingredients\n\nPage 3\nSoup method")
    }

    @Test func rejectsAnEmptySelectionAndWhitespaceOnlyPages() {
        #expect(throws: RecipiePDFImportError.noPagesSelected) {
            try RecipiePDFImport.text(from: [])
        }
        #expect(throws: RecipiePDFImportError.noText(pageNumber: 8)) {
            try RecipiePDFImport.text(from: [page(8, " \n\t\r\u{00a0}")])
        }
    }

    @Test func enforcesTheCharacterBoundaryIncludingPageMarkers() throws {
        let markers = "Page 2\n\n\nPage 4\n"
        let bodyLength = RecipieImportPipeline.maximumTextCharacters - markers.count - 1
        let body = String(repeating: "a", count: bodyLength)
        let pages = [page(2, "x"), page(4, body)]
        #expect(try RecipiePDFImport.text(from: pages).count == 6_000)
        #expect(throws: RecipiePDFImportError.textTooLong) {
            try RecipiePDFImport.text(from: [page(2, "x"), page(4, body + "a")])
        }
    }

    @Test func rejectsUnreadableDataAndZeroPagePDFs() throws {
        #expect(throws: RecipiePDFImportError.unreadablePDF) {
            try RecipiePDFImport.read(data: Data("This is not a PDF".utf8))
        }
        do {
            _ = try RecipiePDFImport.read(data: emptyPDF())
            Issue.record("A zero-page PDF unexpectedly opened")
        } catch {
            // PDFKit may reject a zero-page document before exposing its page count.
            let pdfError = error as? RecipiePDFImportError
            #expect(pdfError == .emptyPDF || pdfError == .unreadablePDF)
        }
    }

    @MainActor
    @Test func rejectsLockedPDFs() throws {
        let document = try #require(PDFDocument(data: fixturePDF(["Soup recipe"])))
        let protected = try #require(document.dataRepresentation(options: [
            PDFDocumentWriteOption.ownerPasswordOption: "owner-password",
            PDFDocumentWriteOption.userPasswordOption: "reader-password"
        ]))
        #expect(throws: RecipiePDFImportError.lockedPDF) {
            try RecipiePDFImport.read(data: protected)
        }
    }

    @MainActor
    @Test func rotatedPagesProducePortraitOrLandscapePreviewsAsAppropriate() throws {
        let document = try #require(PDFDocument(data: fixturePDF(["Landscape recipe"])))
        let pdfPage = try #require(document.page(at: 0))
        pdfPage.rotation = 90
        let pages = try RecipiePDFImport.read(data: #require(document.dataRepresentation()))
        let source = try #require(CGImageSourceCreateWithData(pages[0].thumbnailData as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width > image.height)
        #expect(pages[0].text.contains("Landscape recipe"))
    }

    @MainActor
    @Test func loadsAFileWithoutChangingOrRetainingItsContents() async throws {
        let data = fixturePDF(["Soup recipe"])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).pdf")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let pages = try await RecipiePDFImport.load(from: url)
        #expect(pages.count == 1)
        #expect(pages[0].text.contains("Soup recipe"))
        #expect(try Data(contentsOf: url) == data)
        // Returned page data remains useful once the caller removes its source file.
        try FileManager.default.removeItem(at: url)
        #expect(try RecipiePDFImport.text(from: pages) == "Page 1\nSoup recipe")
    }

    @Test func cancelledReadsStopBeforeOpeningTheFile() async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await RecipiePDFImport.load(from: URL(fileURLWithPath: "/missing-recipe.pdf"))
        }
        do {
            _ = try await task.value
            Issue.record("A cancelled PDF read unexpectedly completed")
        } catch {
            #expect(error is CancellationError)
        }
    }

    @Test func joinsStyledRunsOnlyWhenTheirVisualEdgesTouch() {
        let source = "Mint pe\ns\nto\n1. Blend leaves.\n2. Stir in oil."
        let fragments = [
            fragment("Mint pe", x: 10, y: 100, width: 60),
            fragment("s", x: 70, y: 100, width: 8),
            fragment("to", x: 78, y: 100, width: 18),
            fragment("1. Blend leaves.", x: 10, y: 75, width: 100),
            fragment("2. Stir in oil.", x: 10, y: 50, width: 90)
        ]
        #expect(RecipiePDFImport.normalizedText(source, fragments: fragments)
                == "Mint pesto\n1. Blend leaves.\n2. Stir in oil.")
    }

    @Test func preservesRealLineBreaksColumnsAndSeparatedWords() {
        let source = "First column\nSecond column\nChop\nonions"
        let fragments = [
            fragment("First column", x: 10, y: 100, width: 80),
            fragment("Second column", x: 150, y: 100, width: 80),
            fragment("Chop", x: 10, y: 75, width: 30),
            fragment("onions", x: 44, y: 75, width: 35)
        ]
        #expect(RecipiePDFImport.normalizedText(source, fragments: fragments) == source)
    }

    @Test func matchesUnicodeFragmentsWithoutShiftingCharacterPositions() {
        let source = "🥣 Cafe\u{301} pe\ns\nto"
        let fragments = [
            fragment("🥣 Cafe\u{301} pe", x: 10, y: 100, width: 80),
            fragment("s", x: 90, y: 100, width: 8),
            fragment("to", x: 98, y: 100, width: 18)
        ]
        #expect(RecipiePDFImport.normalizedText(source, fragments: fragments) == "🥣 Cafe\u{301} pesto")
    }

    @Test func keepsTheOriginalTextWhenSelectionsOmitOrReorderContent() {
        let source = "Mint pe\ns\nto\nKeep this instruction."
        let incomplete = [
            fragment("Mint pe", x: 10, y: 100, width: 60),
            fragment("s", x: 70, y: 100, width: 8),
            fragment("to", x: 78, y: 100, width: 18)
        ]
        #expect(RecipiePDFImport.normalizedText(source, fragments: incomplete) == source)
        #expect(RecipiePDFImport.normalizedText(source, fragments: Array(incomplete.reversed())) == source)
    }

    @Test func imagePlaceholdersDoNotCountAsExtractableText() {
        let text = RecipiePDFImport.normalizedText("\u{FFFC}\n\u{FFFC}", fragments: [
            fragment("\u{FFFC}", x: 10, y: 100, width: 60)
        ])
        #expect(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(throws: RecipiePDFImportError.noText(pageNumber: 1)) {
            try RecipiePDFImport.text(from: [page(1, text)])
        }
    }

    private func fragment(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat) -> RecipiePDFImport.TextFragment {
        RecipiePDFImport.TextFragment(text: text, bounds: CGRect(x: x, y: y, width: width, height: 14))
    }

    private func page(_ number: Int, _ text: String) -> RecipiePDFPage {
        RecipiePDFPage(pageNumber: number, text: text, thumbnailData: Data())
    }

    /// Nil draws a raster image containing words, with no embedded text to extract.
    @MainActor
    private func fixturePDF(_ pageTexts: [String?]) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { renderer in
            for text in pageTexts {
                renderer.beginPage()
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 18), .foregroundColor: UIColor.black
                ]
                if let text {
                    (text as NSString).draw(in: bounds.insetBy(dx: 40, dy: 40), withAttributes: attributes)
                } else {
                    let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 100)).image { _ in
                        ("Scanned recipe ingredients" as NSString).draw(at: CGPoint(x: 10, y: 10),
                                                                       withAttributes: attributes)
                    }
                    image.draw(in: CGRect(x: 40, y: 40, width: 400, height: 100))
                }
            }
        }
    }

    private func emptyPDF() -> Data {
        var pdf = "%PDF-1.7\n"
        let catalogOffset = pdf.utf8.count
        pdf += "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"
        let pagesOffset = pdf.utf8.count
        pdf += "2 0 obj\n<< /Type /Pages /Kids [] /Count 0 >>\nendobj\n"
        let xrefOffset = pdf.utf8.count
        pdf += "xref\n0 3\n0000000000 65535 f \n"
        pdf += String(format: "%010d 00000 n \n", catalogOffset)
        pdf += String(format: "%010d 00000 n \n", pagesOffset)
        pdf += "trailer\n<< /Size 3 /Root 1 0 R >>\nstartxref\n\(xrefOffset)\n%%EOF\n"
        return Data(pdf.utf8)
    }
}
