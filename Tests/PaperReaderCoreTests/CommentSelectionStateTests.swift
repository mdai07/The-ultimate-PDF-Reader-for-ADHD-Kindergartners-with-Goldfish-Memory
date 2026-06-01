import XCTest
@testable import PaperReaderCore

final class CommentSelectionStateTests: XCTestCase {
    func testSelectedCommentCanBeResolvedForDeletion() {
        let selectedID = UUID()
        var state = CommentSelectionState()

        state.select(selectedID)

        XCTAssertEqual(state.commentIDForDeletion(existingCommentIDs: [selectedID]), selectedID)
    }

    func testDeletingMissingSelectionClearsIt() {
        let selectedID = UUID()
        var state = CommentSelectionState()

        state.select(selectedID)

        XCTAssertNil(state.commentIDForDeletion(existingCommentIDs: []))
        XCTAssertNil(state.selectedCommentID)
    }
}
