import XCTest
@testable import PaperReaderCore

final class PaperOutlineInferenceTests: XCTestCase {
    func testRecognizesExplicitAppendixHeadings() {
        XCTAssertEqual(PaperOutlineInference.sectionTitle(from: "APPENDIX A"), "Appendix A")
        XCTAssertEqual(PaperOutlineInference.sectionTitle(from: "Appendix A. Derivation of the estimator"), "Appendix A. Derivation of the estimator")
        XCTAssertEqual(PaperOutlineInference.sectionTitle(from: "Appendix B: Additional plots"), "Appendix B: Additional plots")
    }

    func testRecognizesLetteredAppendixSectionHeadings() {
        XCTAssertEqual(PaperOutlineInference.sectionTitle(from: "A. Robustness checks"), "A. Robustness checks")
        XCTAssertEqual(PaperOutlineInference.sectionTitle(from: "B Supplementary Tables"), "B Supplementary Tables")
    }

    func testDoesNotTreatSingleLetterSentencesAsAppendixHeadings() {
        XCTAssertNil(PaperOutlineInference.sectionTitle(from: "A."))
        XCTAssertNil(PaperOutlineInference.sectionTitle(from: "A. this is a sentence fragment"))
    }

    func testRejectsNavigationLabelsThatAreNotSectionHeadings() {
        XCTAssertNil(PaperOutlineInference.sectionTitle(from: "Go Down"))
        XCTAssertNil(PaperOutlineInference.sectionTitle(from: "Forward"))
        XCTAssertNil(PaperOutlineInference.sectionTitle(from: "Document, 1"))
    }

    func testRecognizesSectionPrefixedHeadings() {
        XCTAssertEqual(PaperOutlineInference.sectionTitle(from: "Section 2: Main Results"), "Section 2: Main Results")
        XCTAssertEqual(
            PaperOutlineInference.sectionTitle(from: "Section 1: Dense margin comment layout."),
            "Section 1: Dense margin comment layout"
        )
        XCTAssertEqual(PaperOutlineInference.sectionTitle(from: "Sec. 3. Discussion"), "Sec. 3. Discussion")
    }

    func testFigureAndTableLabelsKeepOnlyNumbers() {
        XCTAssertEqual(PaperOutlineInference.figureOrTableLabel(from: "Figure 1: Response curve."), "Figure 1")
        XCTAssertEqual(PaperOutlineInference.figureOrTableLabel(from: "Fig. 2a. Scaling collapse near the fixed point."), "Figure 2a")
        XCTAssertEqual(PaperOutlineInference.figureOrTableLabel(from: "TABLE S1 - Fit windows."), "Table S1")
        XCTAssertNil(PaperOutlineInference.figureOrTableLabel(from: "The method is compared in Table 1."))
    }

    func testFindsSectionHeadingInsideFlattenedPDFTextRun() {
        let text = """
        AIReader Dense Comment Test - Page 1 1. Section 1: Dense margin comment layout This paragraph has a saved highlight. Figure 1: Response curve.
        """

        XCTAssertEqual(
            PaperOutlineInference.sectionTitles(in: text),
            ["Section 1: Dense margin comment layout"]
        )
    }

    func testFindsSectionPrefixedHeadingInsideFlattenedPDFTextRun() {
        let text = """
        AIReader Dense Comment Test - Page 1 Section 1: Dense margin comment layout. This paragraph has a saved highlight. Figure 1: Response curve.
        """

        XCTAssertEqual(
            PaperOutlineInference.sectionTitles(in: text),
            ["Section 1: Dense margin comment layout"]
        )
    }
}
