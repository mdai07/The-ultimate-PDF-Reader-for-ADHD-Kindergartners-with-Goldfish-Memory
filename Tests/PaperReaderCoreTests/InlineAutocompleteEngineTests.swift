import XCTest
@testable import PaperReaderCore

final class InlineAutocompleteEngineTests: XCTestCase {
    func testAutocompleteContinuesTheTypedPhraseForPartialMultiWordInput() {
        let engine = InlineAutocompleteEngine()
        let suggestions = engine.candidates(
            typed: "main coupl",
            preferredQuestions: [
                "What is the main claim about coupling?",
                "Where is this defined?"
            ]
        )

        XCTAssertEqual(suggestions.first, "main coupling claim?")
        XCTAssertTrue(suggestions.allSatisfy { $0.lowercased().hasPrefix("main coupl") })
    }

    func testAutocompleteCombinesTypedTokensAcrossAvailableQuestions() {
        let engine = InlineAutocompleteEngine()
        let suggestions = engine.candidates(
            typed: "main coupl",
            preferredQuestions: [
                "What does \"coupling\" refer to?",
                "What is the main claim of the paper?"
            ]
        )

        XCTAssertEqual(suggestions.first, "main coupling claim?")
        XCTAssertTrue(suggestions.allSatisfy { $0.lowercased().hasPrefix("main coupl") })
    }

    func testAutocompleteUsesDirectQuestionPrefixWhenTypedTextMatchesBeginning() {
        let engine = InlineAutocompleteEngine()
        let suggestions = engine.candidates(
            typed: "where",
            preferredQuestions: ["Where is this defined?"]
        )

        XCTAssertEqual(suggestions.first, "Where is this defined?")
    }

    func testEmptyInputDoesNotSuggest() {
        let engine = InlineAutocompleteEngine()
        XCTAssertTrue(engine.candidates(typed: "", preferredQuestions: ["Where is this defined?"]).isEmpty)
    }
}
