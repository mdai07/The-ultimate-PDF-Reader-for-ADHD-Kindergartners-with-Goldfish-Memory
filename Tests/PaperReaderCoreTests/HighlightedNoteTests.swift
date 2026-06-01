import XCTest
@testable import PaperReaderCore

final class HighlightedNoteTests: XCTestCase {
    func testLinkedHighlightNoteUsesHighlightAnchorAndColor() {
        let bounds = NormalizedRect(x: 0.2, y: 0.3, width: 0.4, height: 0.05)

        let note = CommentThread.linkedHighlightNote(
            pageIndex: 2,
            bounds: bounds,
            colorHex: "#3B82F6",
            author: "reader"
        )

        XCTAssertEqual(note.pageIndex, 2)
        XCTAssertEqual(note.anchor, .inPage(bounds))
        XCTAssertEqual(note.colorHex, "#3B82F6")
        XCTAssertEqual(note.messages.map(\.author), ["reader"])
        XCTAssertEqual(note.messages.map(\.body), ["New note"])
    }

    func testSourceMarkerForCommentUsesCommentColorAndAnchorPage() {
        let bounds = NormalizedRect(x: 0.18, y: 0.42, width: 0.36, height: 0.06)
        let comment = CommentThread(
            pageIndex: 1,
            anchor: .inPage(bounds),
            colorHex: "#B7C824"
        )

        let marker = Annotation.sourceMarker(
            for: comment,
            bounds: bounds,
            kind: .highlight,
            contents: "Selected equation"
        )

        XCTAssertEqual(marker.pageIndex, 1)
        XCTAssertEqual(marker.kind, .highlight)
        XCTAssertEqual(marker.bounds, bounds)
        XCTAssertEqual(marker.contents, "Selected equation")
        XCTAssertEqual(marker.colorHex, "#B7C824")
    }
}
