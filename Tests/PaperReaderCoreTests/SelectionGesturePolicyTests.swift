import XCTest
@testable import PaperReaderCore

final class SelectionGesturePolicyTests: XCTestCase {
    func testNormalModeStartsRegionSelectionWhenDragBeginsOffText() {
        XCTAssertTrue(SelectionGesturePolicy.shouldBeginRectangleSelection(activeToolID: nil, startsOnText: false))
    }

    func testMagicWandStartsRegionSelectionWhenDragBeginsOffText() {
        XCTAssertTrue(SelectionGesturePolicy.shouldBeginRectangleSelection(activeToolID: "magicWand", startsOnText: false))
    }

    func testTextSelectionWinsWhenDragBeginsOnText() {
        XCTAssertFalse(SelectionGesturePolicy.shouldBeginRectangleSelection(activeToolID: nil, startsOnText: true))
        XCTAssertFalse(SelectionGesturePolicy.shouldBeginRectangleSelection(activeToolID: "magicWand", startsOnText: true))
    }

    func testOtherToolsDoNotStartSmartRegionSelection() {
        XCTAssertFalse(SelectionGesturePolicy.shouldBeginRectangleSelection(activeToolID: "highlight", startsOnText: false))
        XCTAssertFalse(SelectionGesturePolicy.shouldBeginRectangleSelection(activeToolID: "ink", startsOnText: false))
    }
}
