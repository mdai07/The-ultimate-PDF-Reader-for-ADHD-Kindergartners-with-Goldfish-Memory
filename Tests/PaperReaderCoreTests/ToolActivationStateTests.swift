import XCTest
@testable import PaperReaderCore

final class ToolActivationStateTests: XCTestCase {
    func testSingleClickArmsToolForOneUse() {
        var state = ToolActivationState<String>()

        state.activate("highlight", gesture: .singleClick)

        XCTAssertEqual(state.activeTool, "highlight")
        XCTAssertEqual(state.mode, .singleUse)
        XCTAssertTrue(state.consume("highlight"))
        XCTAssertNil(state.activeTool)
        XCTAssertNil(state.mode)
    }

    func testDoubleClickLocksToolAcrossUses() {
        var state = ToolActivationState<String>()

        state.activate("ink", gesture: .doubleClick)

        XCTAssertEqual(state.activeTool, "ink")
        XCTAssertEqual(state.mode, .locked)
        XCTAssertTrue(state.consume("ink"))
        XCTAssertEqual(state.activeTool, "ink")
        XCTAssertEqual(state.mode, .locked)
    }

    func testSingleClickingLockedToolClearsIt() {
        var state = ToolActivationState<String>()
        state.activate("magic", gesture: .doubleClick)

        state.activate("magic", gesture: .singleClick)

        XCTAssertNil(state.activeTool)
        XCTAssertNil(state.mode)
    }

    func testActivatingAnotherToolReplacesCurrentTool() {
        var state = ToolActivationState<String>()
        state.activate("magic", gesture: .doubleClick)

        state.activate("note", gesture: .singleClick)

        XCTAssertEqual(state.activeTool, "note")
        XCTAssertEqual(state.mode, .singleUse)
    }
}
