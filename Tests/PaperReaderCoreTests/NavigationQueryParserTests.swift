import XCTest
@testable import PaperReaderCore

final class NavigationQueryParserTests: XCTestCase {
    func testBareNumberNavigatesToOneBasedPage() {
        XCTAssertEqual(NavigationQueryParser.parse("12"), .page(12))
        XCTAssertEqual(NavigationQueryParser.parse("  3  "), .page(3))
    }

    func testPagePrefixesNavigateToPage() {
        XCTAssertEqual(NavigationQueryParser.parse("page 7"), .page(7))
        XCTAssertEqual(NavigationQueryParser.parse("p. 9"), .page(9))
    }

    func testEquationPrefixesNavigateToEquation() {
        XCTAssertEqual(NavigationQueryParser.parse("eq 31"), .equation("31"))
        XCTAssertEqual(NavigationQueryParser.parse("Equation (A.1)"), .equation("A.1"))
    }

    func testFigureAndTablePrefixesNavigateToLabeledObjects() {
        XCTAssertEqual(NavigationQueryParser.parse("fig 2"), .figure("2"))
        XCTAssertEqual(NavigationQueryParser.parse("Figure 3b"), .figure("3b"))
        XCTAssertEqual(NavigationQueryParser.parse("table 1"), .table("1"))
        XCTAssertEqual(NavigationQueryParser.parse("tab. II"), .table("II"))
    }

    func testInvalidQueryReturnsNil() {
        XCTAssertNil(NavigationQueryParser.parse(""))
        XCTAssertNil(NavigationQueryParser.parse("main result"))
        XCTAssertNil(NavigationQueryParser.parse("page zero"))
    }
}
