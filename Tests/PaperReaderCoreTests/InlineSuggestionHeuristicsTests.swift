import XCTest
@testable import PaperReaderCore

final class InlineSuggestionHeuristicsTests: XCTestCase {
    func testShortTextExplanationsNameTheSelectedPhraseWithoutQuestions() {
        let suggestions = InlineSuggestionHeuristics.suggestions(
            forText: "renormalized coupling",
            paperMemory: "The paper studies finite-volume running couplings.",
            pageLabel: "page 3"
        )

        XCTAssertEqual(suggestions.count, 3)
        XCTAssertTrue(suggestions.allSatisfy { $0.question.isEmpty })
        XCTAssertTrue(suggestions.contains { $0.answer.contains("renormalized coupling") })
        XCTAssertFalse(suggestions.map(\.answer).joined(separator: " ").contains("?"))
    }

    func testDifferentSelectionsProduceDifferentExplanations() {
        let coupling = InlineSuggestionHeuristics.suggestions(
            forText: "renormalized coupling",
            paperMemory: "The paper studies finite-volume running couplings."
        )
        let exponent = InlineSuggestionHeuristics.suggestions(
            forText: "critical exponent gamma",
            paperMemory: "The paper extracts scaling exponents from lattice data."
        )

        XCTAssertNotEqual(coupling.map(\.answer), exponent.map(\.answer))
        XCTAssertTrue(coupling.first?.answer.contains("renormalized coupling") == true)
        XCTAssertTrue(exponent.first?.answer.contains("critical exponent gamma") == true)
    }

    func testLongPassageSuggestionsUseSalientTerms() {
        let passage = """
        The finite-size scaling analysis compares the mass gap across several lattice volumes and uses \
        the collapse of the data to constrain the infrared fixed point.
        """

        let suggestions = InlineSuggestionHeuristics.suggestions(
            forText: passage,
            paperMemory: "The paper's main result is an infrared fixed point estimate."
        )

        let firstExplanation = suggestions[0].answer
        XCTAssertTrue(
            firstExplanation.contains("finite-size scaling")
                || firstExplanation.contains("mass gap")
                || firstExplanation.contains("infrared fixed point")
        )
        XCTAssertTrue(suggestions.map(\.answer).joined(separator: " ").contains("selected passage"))
    }

    func testRegionSuggestionsUseRegionKindAndNearbyText() {
        let suggestions = InlineSuggestionHeuristics.suggestions(
            forRegionKind: "figure",
            detail: "Figure 2: running coupling versus lattice size near the infrared fixed point.",
            paperMemory: "The paper uses figures to support the running-coupling result."
        )

        XCTAssertTrue(suggestions.first?.question.isEmpty == true)
        XCTAssertTrue(suggestions.first?.answer.contains("figure") == true)
        XCTAssertTrue(suggestions.first?.answer.contains("running coupling") == true)
        XCTAssertTrue(suggestions.map(\.answer).joined(separator: " ").contains("running coupling"))
    }

    func testFigureTextSelectionPrioritizesWhatTheFigureShows() {
        let selectedText = """
        Figure 2: Response curve. The plot shows running coupling versus lattice size near the infrared fixed point.
        """

        let suggestions = InlineSuggestionHeuristics.suggestions(
            forText: selectedText,
            paperMemory: "The main paper context discusses running couplings."
        )

        XCTAssertEqual(suggestions.count, 3)
        XCTAssertTrue(suggestions.allSatisfy { $0.question.isEmpty })
        XCTAssertTrue(suggestions[0].answer.localizedCaseInsensitiveContains("Figure 2"))
        XCTAssertTrue(suggestions[0].answer.localizedCaseInsensitiveContains("show"))
        for suggestion in suggestions {
            let combined = suggestion.answer.lowercased()
            XCTAssertTrue(
                combined.contains("figure 2")
                    || combined.contains("response curve")
                    || combined.contains("running coupling")
                    || combined.contains("lattice size")
            )
        }
    }

    func testTableTextSelectionPrioritizesSelectedTableContent() {
        let selectedText = "Table 1: Fit summary. Columns list mass gap, chi squared, and confidence intervals."

        let suggestions = InlineSuggestionHeuristics.suggestions(forText: selectedText)

        XCTAssertTrue(suggestions.allSatisfy { $0.question.isEmpty })
        XCTAssertTrue(suggestions[0].answer.localizedCaseInsensitiveContains("fit summary"))
        for suggestion in suggestions {
            let combined = suggestion.answer.lowercased()
            XCTAssertTrue(
                combined.contains("table 1")
                    || combined.contains("fit summary")
                    || combined.contains("mass gap")
                    || combined.contains("confidence intervals")
            )
        }
    }
}
