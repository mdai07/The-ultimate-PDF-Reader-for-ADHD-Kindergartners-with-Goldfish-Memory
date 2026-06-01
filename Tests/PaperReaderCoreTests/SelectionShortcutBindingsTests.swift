import XCTest
@testable import PaperReaderCore

final class SelectionShortcutBindingsTests: XCTestCase {
    func testDefaultBindingsUseQMH() {
        let bindings = SelectionShortcutBindings()

        XCTAssertEqual(bindings.key(for: .inlineSuggestions), "q")
        XCTAssertEqual(bindings.key(for: .marginComment), "m")
        XCTAssertEqual(bindings.key(for: .highlight), "h")
        XCTAssertEqual(bindings.action(for: "Q"), .inlineSuggestions)
        XCTAssertEqual(bindings.action(for: "m"), .marginComment)
        XCTAssertEqual(bindings.action(for: "h"), .highlight)
    }

    func testUpdatingShortcutNormalizesToFirstLowercaseCharacter() {
        let bindings = SelectionShortcutBindings()
            .updating(.inlineSuggestions, key: "  S ")
            .updating(.marginComment, key: "Note")

        XCTAssertEqual(bindings.key(for: .inlineSuggestions), "s")
        XCTAssertEqual(bindings.key(for: .marginComment), "n")
        XCTAssertEqual(bindings.action(for: "S"), .inlineSuggestions)
        XCTAssertEqual(bindings.action(for: "n"), .marginComment)
    }

    func testBlankShortcutFallsBackToActionDefault() {
        let bindings = SelectionShortcutBindings()
            .updating(.highlight, key: "")

        XCTAssertEqual(bindings.key(for: .highlight), "h")
    }
}
