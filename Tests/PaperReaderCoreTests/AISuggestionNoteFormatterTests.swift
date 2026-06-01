import XCTest
@testable import PaperReaderCore

final class AISuggestionNoteFormatterTests: XCTestCase {
    func testMarginNoteUsesExplanatoryProseInsteadOfQuestionAnswerLabels() {
        let body = AISuggestionNoteFormatter.marginNote(
            contextTitle: "Selected text on page 2",
            suggestions: [
                AISuggestionExplanation(
                    prompt: "What does beta mean?",
                    explanation: "Answer: Beta is the coupling parameter that controls the interaction strength."
                ),
                AISuggestionExplanation(
                    prompt: "Where is this defined?",
                    explanation: "It is introduced immediately before Equation 3 and reused in the scaling argument."
                )
            ]
        )

        XCTAssertFalse(body.contains("Question:"))
        XCTAssertFalse(body.contains("Answer:"))
        XCTAssertFalse(body.contains("What does beta mean?"))
        XCTAssertFalse(body.contains("Selected text on page 2"))
        XCTAssertFalse(body.contains("From Selected text"))
        XCTAssertTrue(body.contains("- Beta is the coupling parameter"))
        XCTAssertTrue(body.contains("- It is introduced immediately before Equation 3"))
    }

    func testSingleInlineCommentStartsDirectlyWithExplanation() {
        let body = AISuggestionNoteFormatter.marginNote(
            contextTitle: "Selected text on page 4",
            suggestions: [
                AISuggestionExplanation(
                    prompt: "",
                    explanation: "This sentence defines the fitted exponent used in the next plot."
                )
            ]
        )

        XCTAssertEqual(body, "This sentence defines the fitted exponent used in the next plot.")
    }

    func testTemporaryNoteExplanationUsesAnswerOnly() {
        let explanation = AISuggestionNoteFormatter.explanation(
            for: AISuggestionExplanation(
                prompt: "Explain this paragraph",
                explanation: "Answer: This paragraph states the approximation and why it is valid in the low-energy limit."
            )
        )

        XCTAssertEqual(
            explanation,
            "This paragraph states the approximation and why it is valid in the low-energy limit."
        )
    }

    func testLegacyQuestionAnswerCommentIsDisplayedAsExplanatoryProse() {
        let legacyBody = """
        AI reading note. Context: Text on page 1.

        1. Question: What does "coupling" refer to in this context? Answer: Coupling is a parameter; as it increases, the dependent variable rises.

        ---

        2. Question: What does Figure 1 illustrate? Answer: Figure 1 shows a synthetic curve that increases as coupling grows.
        """

        let body = AISuggestionNoteFormatter.commentBodyForDisplay(legacyBody)

        XCTAssertFalse(body.contains("Question:"))
        XCTAssertFalse(body.contains("Answer:"))
        XCTAssertFalse(body.contains("What does Figure 1 illustrate?"))
        XCTAssertFalse(body.contains("From Text on page 1."))
        XCTAssertTrue(body.contains("Coupling is a parameter"))
        XCTAssertTrue(body.contains("Figure 1 shows a synthetic curve"))
    }

    func testLegacyBoldQuestionCommentDropsTheQuestionHeading() {
        let legacyBody = """
        **What is the main claim of the paper?**

        The main claim is that a synthetic curve increases with coupling.
        """

        XCTAssertEqual(
            AISuggestionNoteFormatter.commentBodyForDisplay(legacyBody),
            "The main claim is that a synthetic curve increases with coupling."
        )
    }
}
