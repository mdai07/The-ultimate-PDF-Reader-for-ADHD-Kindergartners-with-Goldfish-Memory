import XCTest
@testable import PaperReaderCore

final class LinkedPaperPDFResolverTests: XCTestCase {
    func testArxivAbstractURLResolvesToPDFURL() throws {
        let url = try XCTUnwrap(URL(string: "https://arxiv.org/abs/2401.01234v2"))

        XCTAssertEqual(
            LinkedPaperPDFResolver.directPDFURL(for: url)?.absoluteString,
            "https://arxiv.org/pdf/2401.01234v2.pdf"
        )
    }

    func testOldStyleArxivAbstractURLResolvesToPDFURL() throws {
        let url = try XCTUnwrap(URL(string: "https://arxiv.org/abs/hep-th/9901001"))

        XCTAssertEqual(
            LinkedPaperPDFResolver.directPDFURL(for: url)?.absoluteString,
            "https://arxiv.org/pdf/hep-th/9901001.pdf"
        )
    }

    func testDirectPDFURLIsRecognizedAndArxivPDFGetsPDFExtension() throws {
        let direct = try XCTUnwrap(URL(string: "https://example.org/paper.pdf"))
        let arxiv = try XCTUnwrap(URL(string: "https://arxiv.org/pdf/2401.01234"))

        XCTAssertEqual(LinkedPaperPDFResolver.directPDFURL(for: direct), direct)
        XCTAssertEqual(
            LinkedPaperPDFResolver.directPDFURL(for: arxiv)?.absoluteString,
            "https://arxiv.org/pdf/2401.01234.pdf"
        )
    }

    func testHTMLCitationPDFURLResolvesRelativeToPage() throws {
        let pageURL = try XCTUnwrap(URL(string: "https://journal.example.org/articles/abc"))
        let html = #"<html><head><meta name="citation_pdf_url" content="/articles/abc.pdf"></head></html>"#

        XCTAssertEqual(
            LinkedPaperPDFResolver.pdfURL(inHTML: html, pageURL: pageURL)?.absoluteString,
            "https://journal.example.org/articles/abc.pdf"
        )
    }

    func testDestinationURLUsesOriginalPaperDirectoryAndSafeFilename() throws {
        let source = URL(fileURLWithPath: "/tmp/current paper/main.pdf")
        let pdf = try XCTUnwrap(URL(string: "https://arxiv.org/pdf/2401.01234v2.pdf?download=1"))

        let destination = LinkedPaperPDFResolver.destinationURL(forPDFURL: pdf, sourcePaperURL: source)

        XCTAssertEqual(destination.deletingLastPathComponent().path, "/tmp/current paper")
        XCTAssertEqual(destination.lastPathComponent, "2401.01234v2.pdf")
    }
}
