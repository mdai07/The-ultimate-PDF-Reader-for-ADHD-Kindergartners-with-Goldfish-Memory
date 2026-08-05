import XCTest
@testable import PaperReaderCore

final class ChatCitationSummaryTests: XCTestCase {
    func testEmptyCitationsHaveNoSummary() {
        XCTAssertNil(ChatCitationSummary.text(for: []))
    }

    func testSingleCitationUsesReadableSourceLabel() {
        let citations = [SourceCitation(pageIndex: 2, label: "selected text")]

        XCTAssertEqual(ChatCitationSummary.text(for: citations), "Source: p. 3")
    }

    func testWholePaperCitationsAreDeduplicatedAndCapped() {
        let citations = [
            SourceCitation(pageIndex: 0, label: "embedded text"),
            SourceCitation(pageIndex: 0, label: "ocr text"),
            SourceCitation(pageIndex: 1, label: "embedded text"),
            SourceCitation(pageIndex: 2, label: "embedded text"),
            SourceCitation(pageIndex: 3, label: "embedded text"),
            SourceCitation(pageIndex: 4, label: "embedded text")
        ]

        XCTAssertEqual(
            ChatCitationSummary.text(for: citations),
            "Sources: pp. 1, 2, 3 + 2 more"
        )
    }
}
