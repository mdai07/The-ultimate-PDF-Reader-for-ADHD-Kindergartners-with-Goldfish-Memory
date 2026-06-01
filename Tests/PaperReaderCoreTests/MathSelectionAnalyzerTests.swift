import XCTest
@testable import PaperReaderCore

final class MathSelectionAnalyzerTests: XCTestCase {
    func testDetectsAsciiSubscriptsSuperscriptsAndEquationOperators() {
        XCTAssertTrue(MathSelectionAnalyzer.shouldAttachImage(selectedText: "R_1(t) = A exp(-m t) + B"))
        XCTAssertTrue(MathSelectionAnalyzer.shouldAttachImage(selectedText: "m_i^2 + p_j^2"))
    }

    func testDetectsUnicodeSuperscriptsSubscriptsAndGreekSymbols() {
        XCTAssertTrue(MathSelectionAnalyzer.shouldAttachImage(selectedText: "α₂ = β³ / γ"))
    }

    func testDoesNotAttachImageForOrdinaryProse() {
        XCTAssertFalse(MathSelectionAnalyzer.shouldAttachImage(selectedText: "the diagnostic stays stable across tests"))
    }
}
