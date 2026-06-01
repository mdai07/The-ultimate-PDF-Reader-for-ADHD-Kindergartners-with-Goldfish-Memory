import XCTest
@testable import PaperReaderCore

final class PreciseHighlightResolverTests: XCTestCase {
    func testQuestionForWordsAfterQuotedAnchorCreatesExactFollowingTextCitation() {
        let session = DocumentSession(
            pdfURL: URL(fileURLWithPath: "/tmp/paper.pdf"),
            title: "Dense Comment Test",
            pages: [
                PageModel(index: 0, size: PageSize(width: 612, height: 792), embeddedText: "Page one text."),
                PageModel(
                    index: 1,
                    size: PageSize(width: 612, height: 792),
                    embeddedText: """
                    2. Section 2
                    Main-result sentence for page 2: the diagnostic stays stable across tests.
                    This lower-page point comment verifies connector behavior.
                    """
                )
            ]
        )

        let citations = PreciseHighlightResolver.refinedCitations(
            question: #"What are the words after "Main-result sentence for page 2:"?"#,
            answer: "The words are: the diagnostic stays stable across tests.",
            session: session,
            baseCitations: [
                SourceCitation(pageIndex: 0, label: "embedded text"),
                SourceCitation(pageIndex: 1, label: "embedded text")
            ]
        )

        XCTAssertEqual(citations.first?.pageIndex, 1)
        XCTAssertEqual(citations.first?.label, "text after anchor")
        XCTAssertEqual(citations.first?.highlightText, "the diagnostic stays stable across tests.")
        XCTAssertFalse(citations.contains { $0.pageIndex == 0 && $0.highlightText == nil })
    }

    func testQuotedAnswerPhraseCanCreateExactTextCitation() {
        let session = DocumentSession(
            pdfURL: URL(fileURLWithPath: "/tmp/paper.pdf"),
            title: "Mass Gap Paper",
            pages: [
                PageModel(
                    index: 0,
                    size: PageSize(width: 612, height: 792),
                    embeddedText: "The finite-size scaling analysis compares the mass gap across lattice volumes."
                )
            ]
        )

        let citations = PreciseHighlightResolver.refinedCitations(
            question: "Where is the key observable?",
            answer: #"The key observable is "mass gap"."#,
            session: session,
            baseCitations: [SourceCitation(pageIndex: 0, label: "embedded text")]
        )

        XCTAssertEqual(citations.first?.pageIndex, 0)
        XCTAssertEqual(citations.first?.highlightText, "mass gap")
    }
}
