import XCTest
@testable import PaperReaderCore

final class EquationReferenceResolverTests: XCTestCase {
    func testResolvesExplicitEquationReferenceAgainstEmbeddedPageText() {
        let session = DocumentSession(
            pdfURL: URL(fileURLWithPath: "/tmp/paper.pdf"),
            title: "Paper",
            pages: [
                PageModel(index: 0, size: PageSize(width: 612, height: 792), embeddedText: "The correlator is stable in the final fit. (31)"),
                PageModel(index: 1, size: PageSize(width: 612, height: 792), embeddedText: "A later equation appears here. (35)")
            ]
        )

        let references = EquationReferenceResolver.references(
            in: "This follows from Eq. (31), while Eq. (99) is not in this fixture.",
            session: session
        )

        XCTAssertEqual(references.count, 1)
        XCTAssertEqual(references.first?.matchedText, "Eq. (31)")
        XCTAssertEqual(references.first?.citation.pageIndex, 0)
        XCTAssertEqual(references.first?.citation.highlightText, "(31)")
    }

    func testEquationRangeLinksToFirstResolvableEquation() {
        let session = DocumentSession(
            pdfURL: URL(fileURLWithPath: "/tmp/paper.pdf"),
            title: "Paper",
            pages: [
                PageModel(index: 0, size: PageSize(width: 612, height: 792), embeddedText: "The first matching expression is numbered (31)."),
                PageModel(index: 1, size: PageSize(width: 612, height: 792), embeddedText: "The last expression is numbered (35).")
            ]
        )

        let references = EquationReferenceResolver.references(
            in: "The normalization is summarized by Eqs. (31)-(35).",
            session: session
        )

        XCTAssertEqual(references.count, 1)
        XCTAssertEqual(references.first?.matchedText, "Eqs. (31)-(35)")
        XCTAssertEqual(references.first?.citation.pageIndex, 0)
        XCTAssertEqual(references.first?.citation.highlightText, "(31)")
    }

    func testResolvesEquationReferenceAgainstOCRBlockBounds() {
        let bounds = NormalizedRect(x: 0.2, y: 0.4, width: 0.3, height: 0.06)
        let session = DocumentSession(
            pdfURL: URL(fileURLWithPath: "/tmp/scanned.pdf"),
            title: "Scanned",
            pages: [
                PageModel(index: 0, size: PageSize(width: 612, height: 792), embeddedText: nil)
            ],
            ocrBlocks: [
                OCRBlock(
                    pageIndex: 0,
                    bounds: bounds,
                    text: "The appendix expression is tagged (A1).",
                    confidence: 0.94,
                    source: .appleVision
                )
            ]
        )

        let references = EquationReferenceResolver.references(
            in: "Equation (A1) defines the scanned relation.",
            session: session
        )

        XCTAssertEqual(references.count, 1)
        XCTAssertEqual(references.first?.citation.bounds, bounds)
        XCTAssertEqual(references.first?.citation.highlightText, "(A1)")
    }

    func testResolvesDottedAppendixEquationReference() {
        let session = DocumentSession(
            pdfURL: URL(fileURLWithPath: "/tmp/appendix.pdf"),
            title: "Appendix",
            pages: [
                PageModel(index: 3, size: PageSize(width: 612, height: 792), embeddedText: "The appendix matching relation is numbered (A.1).")
            ]
        )

        let references = EquationReferenceResolver.references(
            in: "The derivation uses Eq. (A.1).",
            session: session
        )

        XCTAssertEqual(references.count, 1)
        XCTAssertEqual(references.first?.matchedText, "Eq. (A.1)")
        XCTAssertEqual(references.first?.citation.pageIndex, 3)
        XCTAssertEqual(references.first?.citation.highlightText, "(A.1)")
    }

    func testDirectEquationIdentifierResolutionUsesSameSearchRules() {
        let session = DocumentSession(
            pdfURL: URL(fileURLWithPath: "/tmp/paper.pdf"),
            title: "Paper",
            pages: [
                PageModel(index: 1, size: PageSize(width: 612, height: 792), embeddedText: "The compact equation tag is (42).")
            ]
        )

        let citation = EquationReferenceResolver.citation(forEquationIdentifier: "42", in: session)

        XCTAssertEqual(citation?.pageIndex, 1)
        XCTAssertEqual(citation?.label, "Eq. (42)")
        XCTAssertEqual(citation?.highlightText, "(42)")
    }
}
