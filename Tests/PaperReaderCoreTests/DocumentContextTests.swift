import XCTest
@testable import PaperReaderCore

final class DocumentContextTests: XCTestCase {
    func testWholePaperContextIncludesEmbeddedTextOCRAndComments() {
        let session = DocumentSession.sampleForContextTests()
        let context = DocumentContextBuilder(session: session).wholePaperContext(maxCharacters: 10_000)

        XCTAssertTrue(context.prompt.contains("Title: Context Paper"))
        XCTAssertTrue(context.prompt.contains("Page 1 embedded: embedded methods section"))
        XCTAssertTrue(context.prompt.contains("Page 2 OCR: scanned result table"))
        XCTAssertTrue(context.prompt.contains("Outside-page comment"))
    }

    func testSelectedTextContextIncludesSelectionAndPageMetadata() {
        let session = DocumentSession.sampleForContextTests()
        let context = DocumentContextBuilder(session: session).selectedTextContext(
            selectedText: "selected theorem",
            pageIndex: 0
        )

        XCTAssertTrue(context.prompt.contains("Selected text on page 1"))
        XCTAssertTrue(context.prompt.contains("selected theorem"))
        XCTAssertEqual(context.citations, [SourceCitation(pageIndex: 0, label: "selected text")])
    }

    func testSelectedMathContextIncludesVisualCropGuidanceAndAttachment() {
        let session = DocumentSession.sampleForContextTests()
        let attachment = AIImageAttachment(
            label: "selected equation crop",
            mimeType: "image/png",
            base64Data: "abc123"
        )
        let context = DocumentContextBuilder(session: session).selectedTextContext(
            selectedText: "R_1(t) = A exp(-m t) + B",
            pageIndex: 0,
            visualAttachment: attachment
        )

        XCTAssertTrue(context.prompt.contains("Visual crop attached"))
        XCTAssertTrue(context.prompt.contains("superscripts, subscripts"))
        XCTAssertEqual(context.imageAttachments, [attachment])
    }

    func testRegionContextIncludesFigureMetadataNearbyTextAndImageDigest() {
        let session = DocumentSession.sampleForContextTests()
        let region = session.regionSelections[0]
        let context = DocumentContextBuilder(session: session).regionContext(region)

        XCTAssertTrue(context.prompt.contains("Selected figure on page 1"))
        XCTAssertTrue(context.prompt.contains("Figure 1"))
        XCTAssertTrue(context.prompt.contains("nearby caption"))
        XCTAssertTrue(context.prompt.contains("sha256:figure"))
    }
}

private extension DocumentSession {
    static func sampleForContextTests() -> DocumentSession {
        DocumentSession(
            pdfURL: URL(fileURLWithPath: "/tmp/context.pdf"),
            title: "Context Paper",
            pages: [
                PageModel(index: 0, size: PageSize(width: 612, height: 792), embeddedText: "embedded methods section"),
                PageModel(index: 1, size: PageSize(width: 612, height: 792), embeddedText: nil)
            ],
            comments: [
                CommentThread(
                    pageIndex: 0,
                    anchor: .outsidePage(MarginAnchor(edge: .trailing, offset: 80, y: 0.5)),
                    messages: [
                        CommentMessage(author: "reader", body: "Outside-page comment")
                    ]
                )
            ],
            regionSelections: [
                RegionSelection(
                    pageIndex: 0,
                    kind: .figure,
                    bounds: NormalizedRect(x: 0.2, y: 0.3, width: 0.4, height: 0.3),
                    label: "Figure 1",
                    nearbyText: "nearby caption",
                    imageDigest: "sha256:figure"
                )
            ],
            ocrBlocks: [
                OCRBlock(
                    pageIndex: 1,
                    bounds: NormalizedRect(x: 0.1, y: 0.2, width: 0.7, height: 0.1),
                    text: "scanned result table",
                    confidence: 0.9,
                    source: .appleVision
                )
            ]
        )
    }
}
