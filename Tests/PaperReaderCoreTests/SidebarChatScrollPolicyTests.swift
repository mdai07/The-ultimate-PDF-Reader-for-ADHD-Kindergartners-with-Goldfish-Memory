import XCTest
@testable import PaperReaderCore

final class SidebarChatScrollPolicyTests: XCTestCase {
    func testShortChatMessageDoesNotNeedNestedScroll() {
        XCTAssertFalse(SidebarChatScrollPolicy.needsNestedScroll("This paragraph fits comfortably in a chat bubble."))
    }

    func testLongChatMessageUsesNestedScroll() {
        let message = Array(repeating: "This assistant answer explains a related derivation and cites the selected paper context.", count: 18)
            .joined(separator: " ")

        XCTAssertTrue(SidebarChatScrollPolicy.needsNestedScroll(message))
    }

    func testMultilineChatMessageUsesNestedScroll() {
        let message = (1...18).map { "Line \($0): a separate step in the derivation." }
            .joined(separator: "\n")

        XCTAssertTrue(SidebarChatScrollPolicy.needsNestedScroll(message))
    }

    func testChatBubbleMaxHeightScalesWithViewportButStaysBounded() {
        XCTAssertEqual(SidebarChatScrollPolicy.bubbleMaxHeight(viewportHeight: 240), 150)
        XCTAssertEqual(SidebarChatScrollPolicy.bubbleMaxHeight(viewportHeight: 520), 260)
        XCTAssertEqual(SidebarChatScrollPolicy.bubbleMaxHeight(viewportHeight: 900), 320)
    }
}
