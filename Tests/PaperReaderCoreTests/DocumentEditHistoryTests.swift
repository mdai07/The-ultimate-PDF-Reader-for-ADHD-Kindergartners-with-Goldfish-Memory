import XCTest
@testable import PaperReaderCore

final class DocumentEditHistoryTests: XCTestCase {
    func testUndoRedoRestoresDocumentSessionSnapshots() {
        let original = DocumentSession(pdfURL: URL(fileURLWithPath: "/tmp/paper.pdf"), title: "paper")
        var edited = original
        edited.annotations.append(Annotation(
            pageIndex: 0,
            kind: .highlight,
            bounds: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.04)
        ))

        var history = DocumentEditHistory()
        history.record(before: original, after: edited)

        XCTAssertEqual(history.undo(current: edited), original)
        XCTAssertEqual(history.redo(current: original), edited)
    }

    func testNewEditClearsRedoStack() {
        let original = DocumentSession(pdfURL: URL(fileURLWithPath: "/tmp/paper.pdf"), title: "paper")
        var firstEdit = original
        firstEdit.comments.append(CommentThread(pageIndex: 0, anchor: .pageOnly))
        var secondEdit = original
        secondEdit.annotations.append(Annotation(
            pageIndex: 0,
            kind: .note,
            bounds: NormalizedRect(x: 0.2, y: 0.3, width: 0.05, height: 0.05)
        ))

        var history = DocumentEditHistory()
        history.record(before: original, after: firstEdit)
        XCTAssertEqual(history.undo(current: firstEdit), original)

        history.record(before: original, after: secondEdit)

        XCTAssertNil(history.redo(current: secondEdit))
    }

    func testNoopEditsAreNotRecorded() {
        let session = DocumentSession(pdfURL: URL(fileURLWithPath: "/tmp/paper.pdf"), title: "paper")
        var history = DocumentEditHistory()

        history.record(before: session, after: session)

        XCTAssertNil(history.undo(current: session))
    }
}
