import XCTest
@testable import PaperReaderCore

final class InlineSuggestionScrollPolicyTests: XCTestCase {
    func testShortAnswerDoesNotNeedNestedScroll() {
        XCTAssertFalse(InlineSuggestionScrollPolicy.needsNestedScroll("A short explanation."))
    }

    func testLongAnswerUsesNestedScroll() {
        let answer = Array(repeating: "This is a detailed explanation of the selected argument.", count: 8)
            .joined(separator: " ")

        XCTAssertTrue(InlineSuggestionScrollPolicy.needsNestedScroll(answer))
    }

    func testAnswerMaxHeightScalesWithPopoverButStaysBounded() {
        XCTAssertEqual(InlineSuggestionScrollPolicy.answerMaxHeight(panelHeight: 120), 72)
        XCTAssertEqual(InlineSuggestionScrollPolicy.answerMaxHeight(panelHeight: 230), 110)
        XCTAssertEqual(InlineSuggestionScrollPolicy.answerMaxHeight(panelHeight: 500), 140)
    }
}
