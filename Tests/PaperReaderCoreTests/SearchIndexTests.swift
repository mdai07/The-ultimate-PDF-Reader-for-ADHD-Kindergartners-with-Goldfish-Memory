import XCTest
@testable import PaperReaderCore

final class SearchIndexTests: XCTestCase {
    func testSearchCombinesEmbeddedPDFTextAndOCRBlocks() {
        let session = DocumentSession(
            pdfURL: URL(fileURLWithPath: "/tmp/paper.pdf"),
            title: "Search Paper",
            pages: [
                PageModel(index: 0, size: PageSize(width: 612, height: 792), embeddedText: "The variational energy decreases."),
                PageModel(index: 1, size: PageSize(width: 612, height: 792), embeddedText: nil)
            ],
            ocrBlocks: [
                OCRBlock(
                    pageIndex: 1,
                    bounds: NormalizedRect(x: 0.1, y: 0.2, width: 0.7, height: 0.1),
                    text: "Scanned appendix includes Hamiltonian truncation details.",
                    confidence: 0.88,
                    source: .appleVision
                )
            ]
        )

        let index = SearchIndex(session: session)
        let embeddedResults = index.search("variational")
        let ocrResults = index.search("Hamiltonian")

        XCTAssertEqual(embeddedResults.map(\.pageIndex), [0])
        XCTAssertEqual(embeddedResults.first?.source, .embeddedText)
        XCTAssertEqual(ocrResults.map(\.pageIndex), [1])
        XCTAssertEqual(ocrResults.first?.source, .ocr)
    }
}
