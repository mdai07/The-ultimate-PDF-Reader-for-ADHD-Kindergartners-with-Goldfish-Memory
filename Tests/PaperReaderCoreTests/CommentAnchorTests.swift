import XCTest
@testable import PaperReaderCore

final class CommentAnchorTests: XCTestCase {
    func testCommentAnchorSupportsPagePointAndPageOnlyRoundTrip() throws {
        let session = DocumentSession(
            pdfURL: URL(fileURLWithPath: "/tmp/paper.pdf"),
            title: "paper",
            comments: [
                CommentThread(
                    pageIndex: 2,
                    anchor: .pagePoint(NormalizedPoint(x: 0.35, y: 0.62)),
                    messages: [CommentMessage(author: "test", body: "Anchored point")]
                ),
                CommentThread(
                    pageIndex: 3,
                    anchor: .pageOnly,
                    messages: [CommentMessage(author: "test", body: "General page note")]
                )
            ]
        )

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(DocumentSession.self, from: data)

        XCTAssertEqual(decoded.comments[0].anchor, .pagePoint(NormalizedPoint(x: 0.35, y: 0.62)))
        XCTAssertEqual(decoded.comments[1].anchor, .pageOnly)
    }

    func testExistingInPageAndOutsidePageAnchorsStillRoundTrip() throws {
        let comments = [
            CommentThread(
                pageIndex: 0,
                anchor: .inPage(NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.04)),
                messages: [CommentMessage(author: "test", body: "Selected text note")]
            ),
            CommentThread(
                pageIndex: 0,
                anchor: .outsidePage(MarginAnchor(edge: .trailing, offset: 88, y: 0.4)),
                messages: [CommentMessage(author: "test", body: "Margin note")]
            )
        ]

        let session = DocumentSession(
            pdfURL: URL(fileURLWithPath: "/tmp/paper.pdf"),
            title: "paper",
            comments: comments
        )

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(DocumentSession.self, from: data)

        XCTAssertEqual(decoded.comments.map(\.anchor), comments.map(\.anchor))
    }

    func testCommentColorDefaultsToGrayWhenMissingFromLegacySidecar() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000010",
          "pageIndex": 0,
          "anchor": { "pageOnly": {} },
          "messages": []
        }
        """

        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(CommentThread.self, from: data)

        XCTAssertEqual(decoded.colorHex, CommentThread.defaultColorHex)
    }

    func testCommentColorRoundTrips() throws {
        let thread = CommentThread(
            pageIndex: 0,
            anchor: .inPage(NormalizedRect(x: 0.2, y: 0.3, width: 0.2, height: 0.05)),
            messages: [CommentMessage(author: "test", body: "Colored")],
            colorHex: "#B7C824"
        )

        let data = try JSONEncoder().encode(thread)
        let decoded = try JSONDecoder().decode(CommentThread.self, from: data)

        XCTAssertEqual(decoded.colorHex, "#B7C824")
    }
}
