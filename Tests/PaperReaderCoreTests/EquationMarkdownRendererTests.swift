import XCTest
@testable import PaperReaderCore

final class EquationMarkdownRendererTests: XCTestCase {
    func testDetectsCommonLatexEquationDelimiters() {
        XCTAssertTrue(EquationMarkdownRenderer.containsEquationMarkup("The gap is $\\Delta E = E_1 - E_0$."))
        XCTAssertTrue(EquationMarkdownRenderer.containsEquationMarkup("Use \\(x_i^2\\) in the fit."))
        XCTAssertTrue(EquationMarkdownRenderer.containsEquationMarkup("Display:\n$$S = \\int d^4x\\, \\mathcal{L}$$"))
        XCTAssertTrue(EquationMarkdownRenderer.containsEquationMarkup("\\[G(t) \\sim e^{-mt}\\]"))
    }

    func testIgnoresPlainDollarAmountsWithoutClosingMath() {
        XCTAssertFalse(EquationMarkdownRenderer.containsEquationMarkup("The fee is $5 for one paper."))
        XCTAssertFalse(EquationMarkdownRenderer.containsEquationMarkup("No equations here."))
    }

    func testHTMLDocumentEscapesUserTextAndIncludesMathJaxConfig() {
        let html = EquationMarkdownRenderer.htmlDocument(for: "Result <script>x</script>: $E=mc^2$")

        XCTAssertTrue(html.contains("&lt;script&gt;x&lt;/script&gt;"))
        XCTAssertFalse(html.contains("<script>x</script>"))
        XCTAssertTrue(html.contains("MathJax"))
        XCTAssertTrue(html.contains("tex-mml-chtml.js"))
        XCTAssertTrue(html.contains("\\(E=mc^2\\)"))
    }

    func testHTMLDocumentLinksEquationReferences() {
        let html = EquationMarkdownRenderer.htmlDocument(
            for: "See Eq. (31) for the normalization.",
            equationLinks: [
                EquationMarkdownLink(
                    text: "Eq. (31)",
                    url: "aireader-equation://jump?page=0&text=(31)"
                )
            ]
        )

        XCTAssertTrue(html.contains(#"<a class="equation-link" href="aireader-equation://jump?page=0&amp;text=(31)">Eq. (31)</a>"#))
    }
}
