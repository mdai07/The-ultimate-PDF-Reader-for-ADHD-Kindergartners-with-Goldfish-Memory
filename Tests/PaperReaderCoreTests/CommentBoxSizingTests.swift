import XCTest
@testable import PaperReaderCore

final class CommentBoxSizingTests: XCTestCase {
    func testCommentDisplayHeightRoundTripsAndLegacyDefaultsToNil() throws {
        let thread = CommentThread(
            pageIndex: 0,
            anchor: .pageOnly,
            messages: [CommentMessage(author: "reader", body: "Long explanation")],
            displayHeight: 132,
            displayYOffset: 0.18
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CommentThread.self, from: encoder.encode(thread))

        XCTAssertEqual(decoded.displayHeight, 132)
        XCTAssertEqual(decoded.displayYOffset, 0.18)

        let legacyJSON = """
        {
          "id": "00000000-0000-0000-0000-000000000020",
          "pageIndex": 0,
          "anchor": { "pageOnly": {} },
          "messages": []
        }
        """
        let legacy = try decoder.decode(CommentThread.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(legacy.displayHeight)
        XCTAssertNil(legacy.displayYOffset)
    }

    func testCommentBoxSizingClampsDraggedHeight() {
        XCTAssertEqual(CommentBoxSizing.clampedHeight(20), CommentBoxSizing.minimumHeight)
        XCTAssertEqual(CommentBoxSizing.clampedHeight(900), CommentBoxSizing.maximumHeight)
        XCTAssertEqual(CommentBoxSizing.clampedHeight(148), 148)
    }

    func testCommentBoxSizingAppliesResizeDragInBothDirections() {
        XCTAssertEqual(CommentBoxSizing.resizedHeight(from: 120, dragTranslation: 80), 200)
        XCTAssertEqual(CommentBoxSizing.resizedHeight(from: 120, dragTranslation: -80), CommentBoxSizing.minimumHeight)
        XCTAssertEqual(CommentBoxSizing.resizedHeight(from: 320, dragTranslation: 80), CommentBoxSizing.maximumHeight)
    }

    func testCommentBoxSizingReservesDedicatedResizeHandleSpace() {
        XCTAssertEqual(CommentBoxSizing.resizeHandleHeight, 24)
        XCTAssertEqual(CommentBoxSizing.scrollViewportHeight(for: 120), 96)
        XCTAssertEqual(
            CommentBoxSizing.scrollViewportHeight(for: CommentBoxSizing.minimumHeight),
            54
        )
        XCTAssertEqual(CommentBoxSizing.totalHeightForMeasuredContent(176), 200)
    }

    func testCommentDragYOffsetConvertsPixelTranslationToNormalizedOffset() {
        XCTAssertEqual(
            CommentBoxSizing.displayYOffset(startOffset: 0.10, dragTranslation: 80, railHeight: 400),
            0.30,
            accuracy: 0.001
        )
        XCTAssertEqual(
            CommentBoxSizing.displayYOffset(startOffset: -0.10, dragTranslation: -80, railHeight: 400),
            -0.30,
            accuracy: 0.001
        )
        XCTAssertEqual(
            CommentBoxSizing.displayYOffset(startOffset: 0.95, dragTranslation: 80, railHeight: 400),
            1.0,
            accuracy: 0.001
        )
    }
}
